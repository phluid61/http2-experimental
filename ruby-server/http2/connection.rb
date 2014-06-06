
require_relative '../hpack'
require_relative 'frame'
require_relative 'stream'
require_relative 'error'

class HAX
	def initialize io
		@io = io
	end
	def write _
		puts "+> #{_.inspect}"
		@io.write _
	end
	def read _
		x = @io.read _
		puts "+< #{x.inspect}"
		x
	end
	def inspect
		@io.inspect
	end
	def method_missing m, *a
		@io.__send__(m, *a)
	end
end

class HTTP2_Connection

	HTTP2_PREFACE = "PRI * HTTP/2.0\x0D\x0A\x0D\x0ASM\x0D\x0A\x0D\x0A"

	def initialize peer
		STDERR.puts "[#{Time.now}] new connection: #{peer.inspect}"
		#@peer = HAX.new(peer)
		@peer = peer
		@started = false
		@shutdown = false

		@message_handlers = []
		@pp_handlers = []

		# Peer's settings
		@peer_header_table_size = 4096
		@peer_enable_push = true
		@peer_max_concurrent_streams = nil
		@peer_initial_window_size = 65535
		@peer_accept_compression = false

		# My settings (acknowledged)
		@header_table_size = 4096
		@enable_push = true
		@max_concurrent_streams = nil
		@initial_window_size = 65535
		@accept_compression = false

		# My pending settings
		@pending_settings = {}
		@settings_in_flight = false

		# Communications
		@recv_queue = []

		# Actual HTTP stuff
		@hpack_in  = HPACK_Context.new
		@hpack_out = HPACK_Context.new
		@streams = {}
		@max_sid = 0
	end

	attr_reader :peer_enable_push, :peer_accept_compression
	attr_reader :header_table_size, :enable_push, :max_concurrent_streams, :accept_compression

	def header_table_size= s
		raise 'wait' if @settings_in_flight # FIXME
		# FIXME: validate
		if @header_table_size != s
			@pending_settings[:SETTINGS_HEADER_TABLE_SIZE] = s
			send_settings if @started
		end
	end
	def enable_push= p
		raise 'wait' if @settings_in_flight # FIXME
		p = !!p
		if @enable_push != p
			@pending_settings[:SETTINGS_ENABLE_PUSH] = (p ? 1 : 0)
			send_settings if @started
		end
	end
	def max_concurrent_streams= x
		raise 'wait' if @settings_in_flight # FIXME
		# FIXME: validate
		if @max_concurrent_streams != x
			@pending_settings[:MAX_CONCURRENT_STREAMS] = x
			send_settings if @started
		end
	end
	def initial_window_size= s
		# FIXME: barf if @started ?
		raise 'wait' if @settings_in_flight # FIXME
		# FIXME: validate
		if @initial_window_size != s
			@pending_settings[:INITIAL_WINDOW_SIZE] = s
			send_settings if @started
		end
	end
	def accept_compression= c
		raise 'wait' if @settings_in_flight # FIXME
		c = !!c
		if @accept_compression != c
			@pending_settings[:ACCEPT_COMPRESSION] = (c ? 1 : 0)
			send_settings if @started
		end
	end

	# Add an on_message handler.
	def on_message &handler
		@message_handlers << handler
	end
	# Handle a message (from the stream)
	def handle_message stream, headers, data
		@message_handlers.each do |h|
			h.call stream, headers, data
		end
	end

	# Add an on_pp handler.
	def on_pp &handler
		@pp_handlers << handler
	end
	# Handle a push promise (from the stream)
	def handle_pp stream, headers
		@pp_handlers.each do |h|
			h.call stream, headers
		end
	end

	def begin_headers stream_id, end_stream: false, &block
		if stream_id > @max_sid
			@max_sid = stream_id
			@streams[stream_id] = HTTP2_Stream.new(stream_id, self)
		end
		stream = @streams[stream_id]
		if stream
			@hpack_out.begin_bytes
			yield @hpack_out
			headers = @hpack_out.bytes
			# split raw bytes into chunks
			_chunk_length = 2**14 # FIXME: right length?
			chunks = []
			while headers.bytesize > _chunk_length
				chunks << headers.byteslice(0, _chunk_length)
				headers = headers.byteslice(_chunk_length..-1)
			end
			chunks << headers if headers.bytesize > 0
			# wrap each chunk in a frame
			frames = []
			frames << HTTP2_Frame_HEADERS.new(stream_id, chunks.shift)
			chunks.each do |chunk|
				frames << HTTP2_Frame_CONTINUATION.new(stream_id, chunk)
			end
			# set appropriate flags
			frames.first.end_stream! if end_stream
			frames.last.end_headers!
			# send frames
			frames.each do |f|
				@peer.write f.to_s
			end
		else
			raise "HEADERS on #{stream_id} (?? < #{@max_sid})"
		end
	end

	def send_data stream_id, payload, end_stream: true
		stream = @streams[stream_id]
		if stream
			# split raw bytes into chunks
			_chunk_length = 2**14 # FIXME: right length?
			chunks = []
			while payload.bytesize > _chunk_length
				chunks << payload.byteslice(0, _chunk_length)
			end
			chunks << payload if chunks.empty? || payload.bytesize > 0
			# wrap each chunk in a frame
			frames = []
			chunks.each do |chunk|
				frames << HTTP2_Frame_DATA.new(stream_id, chunk)
			end
			# set appropriate flags
			frames.last.end_stream! if end_stream
			# send frames
			frames.each do |f|
				@peer.write f.to_s
			end
		else
			raise "DATA on #{data.stream_id} (??)"
		end
	end

	def send_settings force: false
		raise 'wait' if @settings_in_flight # FIXME
		# Send initial settings
		if !@pending_settings.empty? || force
			@peer.write HTTP2_Frame_SETTINGS.new(@pending_settings).to_s
			STDERR.puts "[#{Time.now}] #{@peer.inspect}: settings..."
			@settings_in_flight = true
		end
	end

	def start
		send_settings force: true

		# Accept frames, and farm them out to appropriate whatsernames
		catch(:stop) do
			until @shutdown
#STDERR.puts 'reading...'
				frame = recv
#p [@shutdown, frame.type_symbol, frame]
				throw :stop if frame.nil? && @shutdown
				case frame.type_symbol
				when :SETTINGS
					# Settings frames are for me
					settings = HTTP2_Frame_SETTINGS.from frame
					# TODO: check the stream id == 0
#p settings
					if settings.ack?
						# TODO: check the length == 0
						if @settings_in_flight
							STDERR.puts "[#{Time.now}] #{@peer.inspect}: got ack"
							@pending_settings.each_pair do |k,v|
								case k
								when :SETTINGS_HEADER_TABLE_SIZE
									#@hpack_in.resize_table v
									@header_table_size = v
								when :SETTINGS_ENABLE_PUSH
									@enable_push = (v != 0)
								when :SETTINGS_MAX_CONCURRENT_STREAMS
									@max_concurrent_streams = v
								when :SETTINGS_INITIAL_WINDOW_SIZE
									@initial_window_size = v
								when :SETTINGS_ACCEPT_COMPRESSION
									@accept_compression = (v != 0)
								end
							end
							@pending_settings = {}
							@settings_in_flight = false
						else
							STDERR.puts "[#{Time.now}] #{@peer.inspect}: got unexpected ack"
						end
					else
						settings.each do |k, v|
							case k
							when :SETTINGS_HEADER_TABLE_SIZE
								#@hpack_out.resize_table v # FIXME: ??
								@peer_header_table_size = v
							when :SETTINGS_ENABLE_PUSH
								@peer_enable_push = (v != 0) #XXX not strictly correct
							when :SETTINGS_MAX_CONCURRENT_STREAMS
								@peer_max_concurrent_streams = v
							when :SETTINGS_INITIAL_WINDOW_SIZE
								@peer_initial_window_size = v
							when :SETTINGS_ACCEPT_COMPRESSION
								@peer_accept_compression = (v != 0) #XXX not strictly correct
							else
								goaway :PROTOCOL_ERROR, debug_data: "bad settings #{k}=#{v}"
								throw :stop
							end
						end
						@peer.write HTTP2_Frame_SETTINGS_ACK.new
					end
				when :HEADERS
					# Maybe establish new stream
					# Hand off to stream
					headers = HTTP2_Frame_HEADERS.from frame
#p headers
					if headers.stream_id > @max_sid
						@max_sid = headers.stream_id
						@streams[headers.stream_id] = HTTP2_Stream.new(headers.stream_id, self)
					end
					stream = @streams[headers.stream_id]
					if stream
						@hpack_in.begin_block
						@hpack_in.recv headers.fragment
						frames = [headers]
						hf = headers
						until hf.end_headers?
							f = recv {|g| (g.type_symbol == :CONTINUATION) or raise PROTOCOL_ERROR } #XXX
							raise PROTOCOL_ERROR unless f.stream_id == hf.stream_id #XXX
							hf = HTTP2_Frame_CONTINUATION.from(f)
							@hpack_in.recv hf.fragment
							frames << hf
						end
#p frames
						stream.recv_headers @hpack_in.block, *frames
					else
						goaway(:PROTOCOL_ERROR, debug_data: "HEADERS on #{headers.stream_id} (?? < #{@max_sid})")
						throw :stop
					end
				when :CONTINUATION
					# Should never come out of the blue
					goaway(:PROTOCOL_ERROR, debug_data: "unexpected CONTINUATION on #{frame.stream_id}")
					throw :stop
				when :DATA
					data = HTTP2_Frame_DATA.from frame
#p data
					stream = @streams[data.stream_id]
					if stream
						stream.recv_data data
					else
						goaway(:PROTOCOL_ERROR, debug_data: "DATA on #{data.stream_id} (??)")
						throw :stop
					end
				when :GOAWAY
					goaway = HTTP2_Frame_GOAWAY.from frame
#p goaway
					err = goaway.error_code
					err = (HTTP2_Error.symbol_for(err) rescue err)
					STDERR.print "[#{Time.now}] #{@peer.inspect}: GOAWAY [#{goaway.last_stream_id}] [#{err}] [#{goaway.debug_data.inspect}]\n"
					throw :stop
				when :PRIORITY
					priority = HTTP2_Frame_PRIORITY.from frame
#p priority
					stream = @streams[priority.stream_id]
					if stream
						stream.recv_priority priority
					else
						goaway(:PROTOCOL_ERROR, debug_data: "PRIORITY on #{priority.stream_id} (??)")
						throw :stop
					end
				when :WINDOW_UPDATE
					window_update = HTTP2_Frame_WINDOW_UPDATE.from frame
#p window_update
					stream = @streams[window_update.stream_id]
					if stream
						stream.recv_window_update window_update
					else
						# TODO: do this?
					end
				when :RST_STREAM
					rst_stream = HTTP2_Frame_RST_STREAM.from frame
#p rst_stream
					stream = @streams[rst_stream.stream_id]
					if stream
						stream.recv_rst_stream rst_stream
					else
						goaway(:PROTOCOL_ERROR, debug_data: "RST_STREAM on #{rst_stream.stream_id} (??)")
						throw :stop
					end
				when :PING
					ping = HTTP2_Frame_PING.from frame
#p ping
					if ping.pong?
						# ignore it (?)
					else
						@peer.write ping.pong!
					end
				when :ALTSVC
					altsvc = HTTP2_Frame_ALTSVC.from frame
#p altsvc
					stream = @streams[altsvc.stream_id]
					if stream
						stream.recv_altsvc altsvc
					else
						# TODO: do this?
					end
				when :PUSH_PROMISE
					push_promise = HTTP2_Frame_PUSH_PROMISE.from frame
#p push_promise
					stream = @streams[push_promise.stream_id]
					if stream
						@hpack_in.begin_block
						@hpack_in.recv push_promise.fragment
						frames = [push_promise]
						hf = push_promise
						until hf.end_headers?
							f = recv {|g| (g.type_symbol == :CONTINUATION) or raise PROTOCOL_ERROR } #XXX
							raise PROTOCOL_ERROR unless f.stream_id == hf.stream_id #XXX
							hf = HTTP2_Frame_CONTINUATION.from(f)
							@hpack_in.recv push_promise.fragment
							frames << hf
						end
						stream.recv_push_promise @hpack_in.block, *frames
					else
						goaway(:PROTOCOL_ERROR, debug_data: "PUSH_PROMISE on #{push_promise.stream_id} (??)")
						throw :stop
					end
				else
					goaway( :PROTOCOL_ERROR, debug_data: "invalid frame type #{frame.type.inspect}" )
					throw :stop
				end
			end
		end
		shutdown soft: true
	rescue IOError, Errno::ECONNRESET, Errno::ECONNABORTED => e
		if !@shutdown
			puts "$$ #{e.inspect}"
			puts e.backtrace.map{|b| "\t#{b}" }
		end
	rescue Exception => e
		puts "$$ #{e.inspect}"
		puts e.backtrace.map{|b| "\t#{b}" }
	end

	def goaway error_code, max_stream: nil, debug_data: nil
		max_stream ||= @max_sid
		f = HTTP2_Frame_GOAWAY.new error_code, last_stream_id: max_stream
		f.debug_data = debug_data if debug_data
		@peer.write f.to_s
		#shutdown
	end

	def shutdown soft: false
		if !@shutdown
			@shutdown = true
			unless soft
#			Thread.new do
#				sleep 3
				@peer.close rescue nil
#			end
			end
		end
	end

	def recv &filter
		buf = []
		until @recv_queue.empty?
			f = @recv_queue.shift
			if filter.nil? || yield(f)
				@recv_queue.unshift *buf
				return f
			end
			buf << f
		end
		@recv_queue.unshift *buf
		loop do
			f = HTTP2_Frame.recv_from @peer
			if filter.nil? || yield(f)
				return f
			end
			@recv_queue << f
		end
	end
end


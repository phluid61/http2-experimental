
require_relative 'frame'
require_relative 'stream'
require_relative 'error'

class HTTP2_Connection

	HTTP2_PREFACE = "PRI * HTTP/2.0\x0D\x0A\x0D\x0ASM\x0D\x0A\x0D\x0A"

	def self.handle peer
		self.new(peer).start
	end

	def initialize peer
		STDERR.puts "[#{Time.now}] new connection from #{peer.inspect}"
		@peer = peer
		@started = false

		# Peer's settings
		@peer_header_table_size = 4096
		@peer_enable_push = true
		@peer_max_concurrent_streams = nil
		@peer_initial_window_size = 65535
		@peer_accept_compression = false #XXX

		# My settings
		@header_table_size = 4096
		@enable_push = true
		@max_concurrent_streams = nil
		@initial_window_size = 65535
		@accept_compression = false #XXX

		# Communications
		@recv_queue = []

		# Actual HTTP stuff
		@streams = {}
		@max_sid = 0
	end

	attr_reader :peer_enable_push, :peer_accept_compression
	attr_reader :header_table_size, :enable_push, :max_concurrent_streams, :accept_compression

	def header_table_size= s
		# FIXME: validate
		@header_table_size = s
		#send_settings if @started
	end
	def enable_push= p
		@enable_push = !!p
		#send_settings if @started
	end
	def max_concurrent_streams= x
		# FIXME: validate
		@max_concurrent_streams = x
		#send_settings if @started
	end
	def initial_window_size= s
		# FIXME: validate
		@initial_window_size = s
		#send_settings if @started
	end
	def accept_compression= c
		@accept_compression = !!c
		#send_settings if @started
	end

	def start
		raise if @started
		@started = true

		# Receive standard header
		intro = @peer.read(24)
		if intro != HTTP2_PREFACE
			STDERR.puts "[#{Time.now}] #{@peer.inspect}: bad preface"
			goaway :PROTOCOL_ERROR, debug_data: intro
			return
		end
		STDERR.puts "[#{Time.now}] #{@peer.inspect}: good preface"

		# Send initial settings
		settings = {}
		settings[:SETTINGS_HEADER_TABLE_SIZE] = @header_table_size if @header_table_size != 4096
		settings[:ENABLE_PUSH] = 0 unless @enable_push
		settings[:MAX_CONCURRENT_STREAMS] = @max_concurrent_streams if @max_concurrent_streams
		settings[:INITIAL_WINDOW_SIZE] = @initial_window_size if @initial_window_size != 65535
		settings[:ACCEPT_COMPRESSION] = 1 if @accept_compression
		@peer.write HTTP2_Frame_SETTINGS.new(settings)
		STDERR.puts "[#{Time.now}] #{@peer.inspect}: settings..."

		# Wait for ACK
		recv {|g| g.type_symbol == :SETTINGS && (g.flags & HTTP2_Frame_SETTINGS::FLAG_ACK == HTTP2_Frame_SETTINGS::FLAG_ACK) }
		STDERR.puts "[#{Time.now}] #{@peer.inspect}: got ack"

		# Accept frames, and farm them out to appropriate whatsernames
		loop do
			frame = recv
			case frame.type_symbol
			when :SETTINGS
				# Settings frames are for me
				settings = HTTP2_Frame_SETTINGS.from frame
				settings.each do |k, v|
					case k
					when :SETTINGS_HEADER_TABLE_SIZE
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
						return
					end
				end
				@peer.write HTTP2_Frame_SETTINGS_ACK.new
			when :HEADERS
				# Maybe establish new stream
				# Hand off to stream
				headers = HTTP2_Frame_HEADERS.from frame
				if headers.stream_id > @max_sid
					@max_sid = headers.stream_id
					@streams[headers.stream_id] = HTTP2_Stream.new
				end
				stream = @streams[headers.stream_id]
				if stream
					frames = [headers]
					flag = HTTP2_Frame_HEADERS::FLAG_END_HEADERS
					f = headers
					until f.end_headers?
						f = recv {|g| (g.type_symbol == :CONTINUATION && (g.flags & flag == flag)) or raise PROTOCOL_ERROR } #XXX
						raise PROTOCOL_ERROR unless f.stream_id == headers.stream_id #XXX
						frames << HTTP2_Frame_CONTINUATION.from(f)
					end
					stream.recv_headers *frames
				else
					goaway(:PROTOCOL_ERROR, debug_data: "#{headers.stream_id}?? < #{@max_sid}")
				end
			when :CONTINUATION
				# Should never come out of the blue
				goaway(:PROTOCOL_ERROR, debug_data: "#{continuation.stream_id}??")
			when :DATA
				data = HTTP2_Frame_DATA.from frame
				stream = @streams[data.stream_id]
				if stream
					stream.recv_data data
				else
					goaway(:PROTOCOL_ERROR, debug_data: "#{data.stream_id}??")
				end
			when :GOAWAY
				goaway = HTTP2_Frame_GOAWAY.from frame
				err = goaway.error_code
				err = (HTTP2_Error.symbol_for(err) rescue err)
				STDERR.print "[#{@Time.now}] #{@peer.inspect}: GOAWAY [#{goaway.last_stream_id}] [#{err}]"
				# FIXME: be less violent!
				@peer.close
				return
			when :PRIORITY
				priority = HTTP2_Frame_PRIORITY.from frame
				stream = @streams[priority.stream_id]
				if stream
					stream.recv_priority priority
				else
					goaway(:PROTOCOL_ERROR, debug_data: "#{priority.stream_id}??")
				end
			when :WINDOW_UPDATE
				#window_update = HTTP2_Frame_WINDOW_UPDATE.from.frame
				# TODO: do this?
			when :RST_STREAM
				rst_stream = HTTP2_Frame_RST_STREAM.from frame
				stream = @streams[rst_stream.stream_id]
				if stream
					stream.recv_rst_stream rst_stream
				else
					goaway(:PROTOCOL_ERROR, debug_data: "#{rst_stream.stream_id}??")
				end
			when :PING
				ping = HTTP2_Frame_PING.from frame
				if ping.pong?
					# ignore it (?)
				else
					@peer.write ping.pong!
				end
			when :ALTSVC
				#altsvc = HTTP2_Frame_ALTSVC.from frame
				# TODO: do this?
			when :PUSH_PROMISE
				#push_promise = HTTP2_Frame_PUSH_PROMISE.from frame
				# Nope, don't accept these
				#goaway( :PROTOCOL_ERROR, debug_data: "peers can't push" )
			else
				goaway( :PROTOCOL_ERROR, debug_data: "invalid frame type #{frame.type.inspect}" )
			end
		end
	rescue Exception => e
		p e
		puts e.backtrace.map{|b| "\t#{b}" }
	end

	def goaway error_code, max_stream: nil, debug_data: nil
		max_stream ||= @max_sid
		f = HTTP2_Frame_GOAWAY.new error_code, last_stream_id: max_stream
		f.debug_data = debug_data if debug_data
		@peer.write f
		@peer.close
	end

	def recv &filter
		buf = []
		until @recv_queue.empty?
			f = @recv_queue.shift
			if filter.nil? || yield(f)
				@recv_queue.unshift *buf
				return f
			end
		end
		loop do
			f = HTTP2_Frame.recv_from @peer
			if filter.nil? || yield(f)
				return f
			end
			@recv_queue << f
		end
	end
end


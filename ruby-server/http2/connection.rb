
require_relative 'frame'
require_relative 'error'

class HTTP2_Connection

	HTTP2_PREFACE = "PRI * HTTP/2.0\x0D\x0A\x0D\x0ASM\x0D\x0A\x0D\x0A"

	def self.handle client
		self.new(client).start
	end

	def initialize client
		STDERR.puts "[#{Time.now}] new connection from #{client.inspect}"
		@client = client

		# Client's settings
		@header_table_size = 4096
		@enable_push = true
		@max_concurrent_streams = nil
		@initial_window_size = 65535
		# Non-standard settings
		@accept_data_encoding_gzip = 0

		# Communications
		@recv_queue = []
	end

	def start

		# Receive standard header
		intro = @client.read(24)
		if intro != HTTP2_PREFACE
			STDERR.puts "[#{Time.now}] #{@client.inspect}: bad preface"
			goaway :PROTOCOL_ERROR, debug_data: intro
			return
		end
		STDERR.puts "[#{Time.now}] #{@client.inspect}: good preface"

		# Send initial settings
		settings = {
			#:SETTINGS_HEADER_TABLE_SIZE => 4096,
			:ENABLE_PUSH => 0,
			:MAX_CONCURRENT_STREAMS => $MAX_CONCURRENT_STREAMS,
			#:INITIAL_WINDOW_SIZE => 65535,
		}
		@client.write HTTP2_Frame_SETTINGS.new(settings)
		STDERR.puts "[#{Time.now}] #{@client.inspect}: settings..."

		# Wait for ACK
		recv {|g| g.type_symbol == :SETTINGS && g.flags | HTTP2_Frame_SETTINGS::FLAG_ACK }
		STDERR.puts "[#{Time.now}] #{@client.inspect}: got ack"

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
						@header_table_size = v
					when :ENABLE_PUSH
						@enable_push = (v != 0) #XXX not strictly correct
					when :SETTINGS_MAX_CONCURRENT_STREAMS
						@max_concurrent_streams = v
					when :SETTINGS_INITIAL_WINDOW_SIZE
						@initial_window_size = v
					else
						goaway :PROTOCOL_ERROR, debug_data: "bad settings #{k}=#{v}"
						return
					end
				end
				@client.write HTTP2_Frame_SETTINGS_ACK.new
			when :HEADERS
				# Maybe establish new stream
				# Hand off to stream
			when :CONTINUATION
				# TODO: handle this!
			when :DATA
				# TODO: handle this!
			when :GOAWAY
				goaway = HTTP2_Frame_GOAWAY.from frame
				err = goaway.error_code
				err = (HTTP2_Error.symbol_for(err) rescue err)
				STDERR.print "[#{@Time.now}] #{@client.inspect}: GOAWAY [#{goaway.last_stream_id}] [#{err}]"
				# FIXME: be less violent!
				@client.close
				return
			when :PRIORITY
				# TODO: do this?
			when :WINDOW_UPDATE
				# TODO: do this?
			when :RST_STREAM
				rst_stream = HTTP2_Frame_RST_STREAM.from frame
				# TODO: handle this!
			when :PING
				ping = HTTP2_Frame_PING.from frame
				if ping.pong?
					# ignore it (?)
				else
					@client.write ping.pong!
				end
			when :ALTSVC
				# TODO: do this?
			when :PUSH_PROMISE
				# Nope, don't accept these
				#@client.write HTTP2_Frame_RST_STREAM.new frame.stream_id, :REFUSED_STREAM
				goaway( :PROTOCOL_ERROR, debug_data: "clients can't push" )
			else
				goaway( :PROTOCOL_ERROR, debug_data: "invalid frame type #{frame.type.inspect}" )
			end
		end
	rescue Exception => e
		p e
		puts e.backtrace.map{|b| "\t#{b}" }
	end

	def goaway error_code, max_stream: 0, debug_data: nil
		f = HTTP2_Frame_GOAWAY.new error_code, last_stream_id: max_stream
		f.debug_data = debug_data if debug_data
		@client.write f
		@client.close
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
			f = HTTP2_Frame.recv_from @client
			if filter.nil? || yield(f)
				return f
			end
			@recv_queue << f
		end
	end
end



require 'socket'

require_relative 'connection'

class HTTP2_Client

	def initialize host, port
		@host = host
		@port = port
		@header_table_size = 4096
	end

	def start
		raise if @socket
		@socket = TCPSocket.new @host, @port

		conn = HTTP2_Connection.new(@socket)
		conn.max_concurrent_streams = $MAX_CONCURRENT_STREAMS
		conn.enable_push = false
		conn.on_message do |stream, headers, data|
			# TODO!
			puts ">> #{stream}:"
			headers.each do |e|
				puts "    #{e}"
			end
			puts '', data.inspect, ''
		end
		conn.on_pp do |stream, headers|
			# TODO!
			puts "<< #{stream}:"
			headers.each do |e|
				puts "    #{e}"
			end
			puts ''
		end
		Thread.abort_on_exception = true
		t = conn.start_client
p t
sleep 1

		conn.begin_headers(2, end_stream: true) do |out|
			out.send ':method', 'GET'
			out.send ':scheme', 'http'
			out.send ':path', '/'
			out.send ':authority', 'www.example.com'
		end

		conn.begin_headers(4) do |out|
			out.flush_reference_set
			out.send ':method', 'POST'
			out.send ':scheme', 'http'
			out.send ':path', '/'
			out.send ':authority', 'www.example.com'
		end
		conn.send_data(4, 'foo', end_stream: true)

		# TODO: work out how to ping/pong

		conn.goaway :NO_ERROR, debug_data: 'This is the end... beautiful friend'

		sleep 5
p t
		t.join
	end

end

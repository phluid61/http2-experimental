
require 'socket'

require_relative 'client_connection'

class HTTP2_Client

	def initialize host, port
		@host = host
		@port = port
		@header_table_size = 4096
	end

	def start
		raise if @socket
		@socket = TCPSocket.new @host, @port

		conn = HTTP2_ClientConnection.new(@socket)
		conn.max_concurrent_streams = $MAX_CONCURRENT_STREAMS
		conn.enable_push = false
		conn.on_message do |stream, headers, data|
			# TODO!
			puts ">> #{stream}:"
			headers.each do |e|
				puts "    #{e}"
			end
			puts '', data.inspect, ''
			Thread.main.wakeup
		end
		t = conn.start

		puts "GET /"
		conn.begin_headers(2, end_stream: true) do |out|
			out.send ':method', 'GET'
			out.send ':scheme', 'http'
			out.send ':path', '/'
			out.send ':authority', 'www.example.com'
		end
		Thread.stop

		puts "POST /"
		conn.begin_headers(4) do |out|
			out.flush_reference_set
			out.send ':method', 'POST'
			out.send ':scheme', 'http'
			out.send ':path', '/'
			out.send ':authority', 'www.example.com'
		end
		conn.send_data(4, 'foo', end_stream: true)
		Thread.stop

		# TODO: work out how to ping/pong

		puts "Goodbye"
		conn.goaway :NO_ERROR, debug_data: 'This is the end... beautiful friend'
		sleep 0.1

		conn.shutdown
		t.join
	end

end


require 'socket'
require 'threadpuddle'

require_relative 'server_connection'

class HTTP2_Server

	def initialize port
		@port = port
		@header_table_size = 4096
	end

	def start
		raise if @tp
		@tp = ThreadPuddle.new 100

		srv = TCPServer.new @port
		STDERR.puts "[#{Time.now}] listening on #{@port}"
		loop {
			@tp.spawn(srv.accept) do |cl|
				conn = HTTP2_ServerConnection.new(cl)
				conn.max_concurrent_streams = $MAX_CONCURRENT_STREAMS
				conn.on_message do |stream, headers, data|
					# TODO!
					puts ">> #{stream}:"
					headers.each do |e|
						puts "    #{e}"
					end
					puts '', data.inspect

					m = headers.find{|e|e.name==':method'}
					if m && m.value == 'GET'
						conn.begin_headers(stream+1) do |out|
							out.flush_reference_set
							out.send ':status', '200'
							out.send 'content-type', 'text/plain'
						end
						conn.send_data(stream+1, 'Ok', end_stream: true)
					elsif m
						conn.begin_headers(stream+1) do |out|
							out.flush_reference_set
							out.send ':status', '501'
							out.send 'content-type', 'text/plain'
						end
						conn.send_data(stream+1, 'Not Implemented', end_stream: true)
					else
						conn.begin_headers(stream+1) do |out|
							out.flush_reference_set
							out.send ':status', '400'
							out.send 'content-type', 'text/plain'
						end
						conn.send_data(stream+1, 'Bad Request', end_stream: true)
					end

				end
				conn.on_pp do |stream, headers|
					# Nope, don't accept these
					conn.goaway( :PROTOCOL_ERROR, debug_data: "clients can't push" )
				end
				conn.start
			end
		}
	end

end

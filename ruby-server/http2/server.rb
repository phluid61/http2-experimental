
require 'socket'
require 'threadpuddle'

require_relative 'connection'

class HTTP2_Server

	def initialize port
		@port = port
		@header_table_size = 4096
		@enable_push
	end

	def start
		raise if @tp
		@tp = ThreadPuddle.new 100

		srv = TCPServer.new @port
		loop {
			@tp.spawn(srv.accept) do |cl|
				conn = HTTP2_Connection.new(cl)
				conn.max_concurrent_streams = $MAX_CONCURRENT_STREAMS
				conn.on_message do |stream, headers, data|
					# TODO!
					puts ">> #{stream}:"
					headers.each do |e|
						puts "    #{e}"
					end
					puts '', data.inspect
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

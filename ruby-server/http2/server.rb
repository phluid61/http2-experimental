
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
				conn.start
			end
		}
	end

end

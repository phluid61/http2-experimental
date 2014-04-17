
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
		loop do
			@tp.spawn(srv.accept) {|cl| HTTP2_Connection.handle cl }
		end
	end

end



require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_PING

	FLAG_ACK = 0x1

	def self.from f
		raise ArgumentError unless f.type_symbol == :PING
		raise PROTOCOL_ERROR unless f.stream_id == 0
		raise PROTOCOL_ERROR if f.length != 8
		g = self.new f.payload
		g.pong! if f.flags & FLAG_ACK == FLAG_ACK
		g
	end

	def self.pong data
		self.new(data).pong!
	end

	def initialize data
		self.data = data
		@frame = HTTP2_Frame.new :PING, payload: @data
	end

	def ping?
		@frame.flags & FLAG_ACK == 0
	end
	def pong?
		@frame.flags & FLAG_ACK == FLAG_ACK
	end

	def ping!
		@frame.flags = 0
		self
	end
	def pong!
		@frame.flags = FLAG_ACK
		self
	end

	attr_reader :data

	def data= d
		d = d.to_s
		raise ArgumentError if d.bytesize != 8
		@data = d
		@frame.payload = d if @frame
	end

	def to_s
		@frame.to_s
	end

end


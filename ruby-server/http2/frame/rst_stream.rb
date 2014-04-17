
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_RST_STREAM

	def self.from f
		raise ArgumentError unless f.type_symbol == :RST_STREAM
		raise PROTOCOL_ERROR if f.stream_id == 0
		raise PROTOCOL_ERROR if f.length != 4
		g = self.new f.payload
		g.pong! if f.flags & FLAG_ACK == FLAG_ACK
		g
	end

	def initialize stream_id, error_code
		self.error_code = error_code
		@frame = HTTP2_Frame.new :RST_STREAM, stream_id: stream_id, payload: __serialize
	end

	attr_reader :error_code

	def stream_id
		@frame.stream_id
	end

	def error_code= e
		@error_code = HTTP2_Error.code_for e
		@frame.payload = __serialize if @frame
	end

	def stream_id= sid
		@frame.stream_id = sid
	end

	def to_s
		@frame.to_s
	end

	def __serialize
		[@error_code].pack 'L<'
	end

end


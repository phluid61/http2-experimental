
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_GOAWAY

	def self.from f
		raise ArgumentError unless f.type_symbol == :GOAWAY
		raise PROTOCOL_ERROR unless f.stream_id == 0
		raise PROTOCOL_ERROR if f.length < 64
		sid, err, dd = f.payload.unpack 'CL>a*'
		self.new err, last_stream_id: sid, debug_data: dd
	end

	def initialize error_code, last_stream_id: 0, debug_data: ''
		debug_data = debug_data.to_s
		self.error_code = error_code
		self.last_stream_id = last_stream_id
		@frame = HTTP2_Frame.new :GOAWAY, payload: __serialize(debug_data)
		@debug_data = debug_data
	end

	attr_reader :error_code, :last_stream_id, :debug_data

	def error_code= e
		@error_code = HTTP2_Error.code_for e
		@frame.payload = __serialize @debug_data if @frame
	end

	def last_stream_id= sid
		raise ArgumentError if sid < 0 || sid > 2**31
		@last_stream_id = sid
		@frame.payload = __serialize @debug_data if @frame
	end

	def debug_data= dd
		dd = dd.to_s
		@frame.payload = __serialize dd
		@debug_data = dd
	end

	def << bytes
		@frame << bytes
		@debug_data << bytes
	end

	def to_s
		@frame.to_s
	end

	def __serialize dd
		[@last_stream_id, @error_code].pack('L>L>') + dd
	end

end


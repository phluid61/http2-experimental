
module HTTP2_Error
	NO_ERROR = 0
	PROTOCOL_ERROR = 1
	INTERNAL_ERROR = 2
	FLOW_CONTROL_ERROR = 3
	SETTINGS_TIMEOUT = 4
	STREAM_CLOSED = 5
	FRAME_SIZE_ERROR = 6
	REFUSED_STREAM = 7
	CANCEL = 8
	COMPRESSION_ERROR = 9
	CONNECT_ERROR = 10
	ENHANCE_YOUR_CALM = 11
	INADEQUATE_SECURITY = 12

	def self.code_for e
		case e
		when :NO_ERROR,             0;  0
		when :PROTOCOL_ERROR,       1;  1
		when :INTERNAL_ERROR,       2;  2
		when :FLOW_CONTROL_ERROR,   3;  3
		when :SETTINGS_TIMEOUT,     4;  4
		when :STREAM_CLOSED,        5;  5
		when :FRAME_SIZE_ERROR,     6;  6
		when :REFUSED_STREAM,       7;  7
		when :CANCEL,               8;  8
		when :COMPRESSION_ERROR,    9;  9
		when :CONNECT_ERROR,       10; 10
		when :ENHANCE_YOUR_CALM,   11; 11
		when :INADEQUATE_SECURITY, 12; 12
		else
			raise ArgumentError
		end
	end

	def self.symbol_for e
		case e
		when :NO_ERROR,             0; :NO_ERROR
		when :PROTOCOL_ERROR,       1; :PROTOCOL_ERROR
		when :INTERNAL_ERROR,       2; :INTERNAL_ERROR
		when :FLOW_CONTROL_ERROR,   3; :FLOW_CONTROL_ERROR
		when :SETTINGS_TIMEOUT,     4; :SETTINGS_TIMEOUT
		when :STREAM_CLOSED,        5; :STREAM_CLOSED
		when :FRAME_SIZE_ERROR,     6; :FRAME_SIZE_ERROR
		when :REFUSED_STREAM,       7; :REFUSED_STREAM
		when :CANCEL,               8; :CANCEL
		when :COMPRESSION_ERROR,    9; :COMPRESSION_ERROR
		when :CONNECT_ERROR,       10; :CONNECT_ERROR
		when :ENHANCE_YOUR_CALM,   11; :ENHANCE_YOUR_CALM
		when :INADEQUATE_SECURITY, 12; :INADEQUATE_SECURITY
		else
			raise ArgumentError
		end
	end

	def self.name_of e
		self.symbol_for(e).to_s
	end

end

class PROTOCOL_ERROR < RuntimeError
end

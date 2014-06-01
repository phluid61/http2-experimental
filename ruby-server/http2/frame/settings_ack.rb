
require_relative '../frame'

class HTTP2_Frame_SETTINGS_ACK

	def initialize
		@frame = HTTP2_Frame.new :SETTINGS, flags: HTTP2_Frame_SETTINGS::FLAG_ACK
	end

	def ack?
		true
	end

	def to_s
		@frame.to_s
	end

end

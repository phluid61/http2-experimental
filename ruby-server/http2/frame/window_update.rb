
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_WINDOW_UPDATE

	def self.from f
		raise ArgumentError unless f.type_symbol == :WINDOW_UPDATE
		raise PROTOCOL_ERROR if f.length != 4
		wsi = f.payload.unpack('L>').first
		wsi &= 0x7FFF_FFFF
		self.new wsi, stream_id: f.stream_id
	end

	def initialize window_size_increment, stream_id: 0
		self.window_size_increment = window_size_increment
		@frame = HTTP2_Frame.new :WINDOW_UPDATE, stream_id: stream_id, payload: __serialize
	end

	attr_reader :window_size_increment

	def stream_id
		@frame.stream_id
	end

	def window_size_increment= wsi
		raise ArgumentError if wsi < 0 || wsi > 0x7FFF_FFFF
		@window_size_increment = wsi
		@frame.payload = __serialize if @frame
	end

	def stream_id= sid
		@frame.stream_id = sid
	end

	def to_s
		@frame.to_s
	end

	def __serialize
		[@window_size_increment].pack 'L>'
	end

end


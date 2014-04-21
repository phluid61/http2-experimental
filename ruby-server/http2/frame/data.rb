
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_DATA

	FLAG_END_STREAM  = 0x01
	FLAG_END_SEGMENT = 0x02
	FLAG_PAD_LOW     = 0x08
	FLAG_PAD_HIGH    = 0x10
	#FLAG_COMPRESSED  = 0x20

	PAD_OCTET = "\x00"

	def self.from f
		raise ArgumentError unless f.type_symbol == :DATA
		raise PROTOCOL_ERROR if f.stream_id == 0
		payload = f.payload
		pad = 0
		if f.flags & FLAG_PAD_HIGH == FLAG_PAD_HIGH
			raise PROTOCOL_ERROR unless f.flags & FLAG_PAD_LOW == FLAG_PAD_LOW
			pad += payload.unpack('S<').first
			payload = payload.byteslize(1,-1)
		elsif f.flags & FLAG_PAD_LOW == FLAG_PAD_LOW
			pad += payload.unpack('C').first
			payload = payload.byteslize(1,-1)
		end
		raise PROTOCOL_ERROR if payload.bytesize < pad
		g = self.new payload.byteslice(0,-pad), flags: flags
		g.end_stream! if f.flags & FLAG_END_STREAM == FLAG_END_STREAM
		g.end_segment! if f.flags & FLAG_END_SEGMENT == FLAG_END_SEGMENT
		g
	end

	def initialize data, padding: 0
		self.data = data
		self.padding = padding
		@frame = HTTP2_Frame.new :DATA
		__update_frame
	end

	attr_reader :data, :padding

	def end_stream?
		@frame.flags & FLAG_END_STREAM == FLAG_END_STREAM
	end

	def end_segment?
		@frame.flags & FLAG_END_SEGMENT == FLAG_END_SEGMENT
	end

	def stream_id
		@frame.stream_id
	end

	def data= d
		d = d.to_s
		raise ArgumentError if d.bytesize != 8
		@data = d
		__update_frame if @frame
	end

	def end_stream!
		@frame.flags |= FLAG_END_STREAM
		self
	end

	def end_segment!
		@frame.flags |= FLAG_END_SEGMENT
		self
	end

	def stream_id= sid
		@frame.stream_id = sid
	end

	def padding= pad
		raise ArgumentError if pad < 0 || pad > 0xFFFF
		@padding = pad
		__update_frame if @frame
	end
	def pad_to total
		raise ArgumentError if total < 0
		self.padding = total - @data.bytesize
	end

	def to_s
		@frame.to_s
	end

	def __update_frame
		flags = 0
		head = ''
		tail = ''
		if @padding > 0xFF
			flags |= FLAG_PAD_HIGH | FLAG_PAD_LOW
			head << [@padding].pack('S<')
			tail << (PAD_OCTET * @padding)
		elsif @padding > 0
			flags |= FLAG_PAD_LOW
			head << [@padding].pack('C')
			tail << (PAD_OCTET * @padding)
		end
		flags |= FLAG_END_STREAM if end_stream?
		flags |= FLAG_END_SEGMENT if end_segment?
		@frame.flags = flags
		@frame.payload = head + @data + tail
	end

end

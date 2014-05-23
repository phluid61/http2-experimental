
require_relative 'padded_frame'
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_DATA

	FLAG_END_STREAM  = 0x01
	FLAG_END_SEGMENT = 0x02
	#~~~~               0x04
	#FLAG_PAD_LOW     = 0x08
	#FLAG_PAD_HIGH    = 0x10
	FLAG_COMPRESSED  = 0x20

	def self.from f
		raise ArgumentError unless f.type_symbol == :DATA
		raise PROTOCOL_ERROR if f.stream_id == 0
		pad, payload = PaddedFrame.extract_padding_from f
		raise PROTOCOL_ERROR if payload.bytesize < pad
		payload = payload.byteslice(0,-pad) if pad > 0
		g = self.new f.stream_id, payload, padding: pad
		g.end_stream! if f.flags & FLAG_END_STREAM == FLAG_END_STREAM
		g.end_segment! if f.flags & FLAG_END_SEGMENT == FLAG_END_SEGMENT
		g.compressed! if f.flags & FLAG_COMPRESSED == FLAG_COMPRESSED
		g
	end

	def initialize stream_id, data, padding: 0
		self.data = data
		self.padding = padding
		@frame = HTTP2_Frame.new :DATA, stream_id: stream_id
		__update_frame
	end

	attr_reader :data, :padding

	def end_stream?
		@frame.flags & FLAG_END_STREAM == FLAG_END_STREAM
	end

	def end_segment?
		@frame.flags & FLAG_END_SEGMENT == FLAG_END_SEGMENT
	end

	def compressed?
		@frame.flags & FLAG_COMPRESSED == FLAG_COMPRESSED
	end

	def stream_id
		@frame.stream_id
	end

	def data= d
		d = d.to_s
		# FIXME: range check here!
		#raise ArgumentError if d.bytesize >= 2**14
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

	def compressed!
		@frame.flags |= FLAG_COMPRESSED
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
	def pad_to total, truncate: false
		pad = total - @data.bytesize
		raise ArgumentError if pad < 0 && !truncate
		if pad > 0
			self.padding = pad
		else
			self.padding = 0
		end
	end

	def to_s
		@frame.to_s
	end

	def __update_frame
		flags, head, tail = PaddedFrame.generate_padding @padding
		flags |= FLAG_END_STREAM if end_stream?
		flags |= FLAG_END_SEGMENT if end_segment?
		flags |= FLAG_COMPRESSED if compressed?
		@frame.flags = flags
		@frame.payload = head + @data + tail
	end

end

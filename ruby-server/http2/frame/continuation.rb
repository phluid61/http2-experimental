
require_relative 'padded_frame'
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_CONTINUATION

	FLAG_END_HEADERS = 0x04
	#FLAG_PAD_LOW     = 0x08
	#FLAG_PAD_HIGH    = 0x10

	def self.from f
		raise ArgumentError unless f.type_symbol == :CONTINUATION
		raise PROTOCOL_ERROR if f.stream_id == 0
		pad, payload = PaddedFrame.extract_padding_from f
		raise PROTOCOL_ERROR if payload.bytesize < pad
		g = self.new f.stream_id, payload.byteslice(0,-pad), padding: pad
		g.end_headers! if f.flags & FLAG_END_HEADERS == FLAG_END_HEADERS
		g
	end

	def initialize stream_id, fragment, padding: 0
		self.fragment = fragment
		self.padding = padding
		@frame = HTTP2_Frame.new :CONTINUATION, stream_id: stream_id
		__update_frame
	end

	attr_reader :fragment, :padding

	def end_headers?
		@frame.flags & FLAG_END_HEADERS == FLAG_END_HEADERS
	end

	def stream_id
		@frame.stream_id
	end

	def fragment= f
		f = f.to_s
		# FIXME: range check here!
		#raise ArgumentError if f.bytesize >= 2**14
		@fragment = f
		__update_frame if @frame
	end

	def end_headers!
		@frame.flags |= FLAG_END_HEADERS
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
		pad = total - @fragment.bytesize
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
		flags |= FLAG_END_HEADERS if end_headers?
		@frame.flags = flags
		@frame.payload = head + @fragment + tail
	end

end

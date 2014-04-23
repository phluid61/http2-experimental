
require_relative 'padded_frame'
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_PUSH_PROMISE

	FLAG_END_HEADERS = 0x04
	#FLAG_PAD_LOW     = 0x08
	#FLAG_PAD_HIGH    = 0x10

	def self.from f
		raise ArgumentError unless f.type_symbol == :PUSH_PROMISE
		raise PROTOCOL_ERROR if f.stream_id == 0
		pad, payload = PaddedFrame.extract_padding_from f
		raise PROTOCOL_ERROR if payload.bytesize < (pad+4)
		psid = payload.unpack('L>').first
		psid &= 0x7FFF_FFFF
		g = self.new f.stream_id, psid, payload.byteslice(4,-pad), padding: pad
		g.end_headers! if f.flags & FLAG_END_HEADERS == FLAG_END_HEADERS
		g
	end

	def initialize stream_id, promised_stream_id, fragment, padding: 0
		self.promised_stream_id = promised_stream_id
		self.fragment = fragment
		self.padding = padding
		@frame = HTTP2_Frame.new :PUSH_PROMISE, stream_id: stream_id
		__update_frame
	end

	attr_reader :promised_stream_id, :fragment, :padding

	def end_headers?
		@frame.flags & FLAG_END_HEADERS == FLAG_END_HEADERS
	end

	def stream_id
		@frame.stream_id
	end

	def promised_stream_id= sid
		raise ArgumentError if sid < 0 || sid > 0x7FFF_FFFF
		@promised_stream_id = sid
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

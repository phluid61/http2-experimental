
require_relative 'padded_frame'
require_relative 'prioritised_frame'
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_HEADERS

	FLAG_END_STREAM  = 0x01
	FLAG_END_SEGMENT = 0x02
	FLAG_END_HEADERS = 0x04
	#FLAG_PAD_LOW     = 0x08
	#FLAG_PAD_HIGH    = 0x10
	#FLAG_PRIORITY_GROUP      = 0x20
	#FLAG_PRIORITY_DEPENDENCY = 0x40

	def self.from f
		raise ArgumentError unless f.type_symbol == :HEADERS
		raise PROTOCOL_ERROR if f.stream_id == 0
		pad, payload = PaddedFrame.extract_padding_from f
		pr, payload = PrioritisedFrame.extract_priority_from f, payload: payload
		raise PROTOCOL_ERROR if payload.bytesize < pad
		g = self.new payload.byteslice(0,-pad), padding: pad, priority: pr
		g.end_stream! if f.flags & FLAG_END_STREAM == FLAG_END_STREAM
		g.end_segment! if f.flags & FLAG_END_SEGMENT == FLAG_END_SEGMENT
		g.end_headers! if f.flags & FLAG_END_HEADERS == FLAG_END_HEADERS
		g
	end

	def initialize fragment, padding: 0, priority: nil
		self.fragment = fragment
		self.padding = padding
		self.priority = priority
		@frame = HTTP2_Frame.new :HEADERS
		__update_frame
	end

	attr_reader :fragment, :padding, :priority

	def end_stream?
		@frame.flags & FLAG_END_STREAM == FLAG_END_STREAM
	end

	def end_segment?
		@frame.flags & FLAG_END_SEGMENT == FLAG_END_SEGMENT
	end

	def end_headers?
		@frame.flags & FLAG_END_HEADERS == FLAG_END_HEADERS
	end

	def stream_id
		@frame.stream_id
	end

	def fragment= f
		f = f.to_s
		# FIXME: range check here!
		#raise ArgumentError if f.bytesize != 8
		@fragment = f
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

	def end_headers!
		@frame.flags |= FLAG_END_HEADERS
		self
	end

	def priority= pr
		case pr
		when nil, PrioritisedFrame::PriorityGroup, PrioritisedFrame::PriorityDependency
			@priority = pr
		else
			raise ArgumentError
		end
		__update_frame if @frame
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
		flags, head = PrioritisedFrame.generate_priority @priority, flags: flags, head: head
		flags |= FLAG_END_STREAM if end_stream?
		flags |= FLAG_END_SEGMENT if end_segment?
		flags |= FLAG_END_HEADERS if end_headers?
		@frame.flags = flags
		@frame.payload = head + @fragment + tail
	end

end

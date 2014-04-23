
require_relative 'prioritised_frame'
require_relative '../frame'
require_relative '../error'

class HTTP2_Frame_PRIORITY

	#FLAG_PRIORITY_GROUP      = 0x20
	#FLAG_PRIORITY_DEPENDENCY = 0x40

	def self.from f
		raise ArgumentError unless f.type_symbol == :PRIORITY
		raise PROTOCOL_ERROR if f.stream_id == 0
		pr, payload = PrioritisedFrame.extract_priority_from f
		raise PROTOCOL_ERROR if payload.bytesize > 0
		raise PROTOCOL_ERROR if pr.nil?
		self.new f.stream_id, pr
	end

	def initialize stream_id, priority
		self.priority = priority
		@frame = HTTP2_Frame.new :PRIORITY, stream_id: stream_id
		__update_frame
	end

	attr_reader :priority

	def stream_id
		@frame.stream_id
	end

	def priority= pr
		case pr
		when PrioritisedFrame::PriorityGroup, PrioritisedFrame::PriorityDependency
			@priority = pr
		else
			raise ArgumentError
		end
		__update_frame if @frame
	end

	def stream_id= sid
		@frame.stream_id = sid
	end

	def to_s
		@frame.to_s
	end

	def __update_frame
		flags, body = PrioritisedFrame.generate_priority @priority
		@frame.flags = flags
		@frame.payload = body
	end

end

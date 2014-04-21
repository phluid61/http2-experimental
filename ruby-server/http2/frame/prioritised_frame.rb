
module PrioritisedFrame
	FLAG_PRIORITY_GROUP      = 0x20
	FLAG_PRIORITY_DEPENDENCY = 0x40

	def self.extract_priority_from frame, payload: nil
		pg = nil
		pd = nil
		if frame.flags & FLAG_PRIORITY_GROUP == FLAG_PRIORITY_GROUP
			if frame.flags & FLAG_PRIORITY_DEPENDENCY = FLAG_PRIORITY_DEPENDENCY
				raise PROTOCOL_ERROR
			end
			flags |= FLAG_PRIORITY_GROUP
			[pgi, weight] = payload.unpack('L<C')
			pg = PriorityGroup.new(pgi&0x7FFF_FFFF, weight+1)
			payload = payload.byteslice(5,-1)
		end
		if frame.flags & FLAG_PRIORITY_DEPENDENCY = FLAG_PRIORITY_DEPENDENCY
			flags |= FLAG_PRIORITY_DEPENDENCY
			sd = payload.unpack('L<')
			pd = PriorityDependency.new(sd & 0x7FFF_FFFF, (sd & 0x8000_0000 == 0x8000_0000))
			payload = payload.byteslice(4,-1)
		end
		[pg || pd, payload]
	end

	def self.generate_priority p, flags: 0, body: ''
		case pr
		when PriorityGroup
			flags |= FLAG_PRIORITY_GROUP
			body << [p.group, p.weight].pack('L<C')
		when PriorityDependency
			flags |= FLAG_PRIORITY_DEPENDENCY
			dep = p.stream
			dep |= 0x8000_0000 if p.exclusive?
			body << [dep].pack('L<')
		end
		[flags, body]
	end

	class PriorityGroup
		def initialize group, weight
			raise ArgumentError if group < 0 || group > 0x7FFF_FFFF
			raise ArgumentError if weight < 1 || weight > 256
			@group = g
			@weight = w
		end
		attr_reader :group, :weight
	end

	class PriorityDependency
		def initialize stream, e
			raise ArgumentError if stream < 0 || stream > 0x7FFF_FFFF
			@stream = stream
			@exclusive = !(!e || e == 0)
		end
		attr_reader :stream
		def exclusive?
			@exclusive
		end
	end
end

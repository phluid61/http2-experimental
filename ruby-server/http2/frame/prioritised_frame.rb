
module PrioritisedFrame
	FLAG_PRIORITY = 0x20

	def self.extract_priority_from frame, payload: nil
		priority = nil
		if frame.flags & FLAG_PRIORITY == FLAG_PRIORITY
			flags |= FLAG_PRIORITY
			dep, weight = payload.unpack('L>C')
			priority = Priority.new((dep & 0x8000_0000 == 0x8000_0000), dep & 0x7FFF_FFFF, weight+1)
			payload = payload.byteslice(5,-1)
		end
		[priority, payload]
	end

	def self.generate_priority p, flags: 0, body: ''
		if p
			flags |= FLAG_PRIORITY
			dep = p.stream
			dep |= 0x8000_0000 if p.exclusive?
			body << [dep, p.weight].pack('L>C')
		end
		[flags, body]
	end

	class Priority
		def initialize e, stream, weight
			raise ArgumentError if stream < 0 || stream > 0x7FFF_FFFF
			raise ArgumentError if weight < 1 || weight > 256
			@exclusive = !(!e || e == 0)
			@stream = stream
			@weight = weight
		end
		attr_reader :stream, :weight
		def exclusive?
			@exclusive
		end
	end

end

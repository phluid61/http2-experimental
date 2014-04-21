
module PaddedFrame
	FLAG_PAD_LOW     = 0x08
	FLAG_PAD_HIGH    = 0x10

	PAD_OCTET = "\x00"

	def self.extract_padding_from frame, payload: nil
		payload ||= frame.payload
		pad = 0
		if frame.flags & FLAG_PAD_HIGH == FLAG_PAD_HIGH
			raise PROTOCOL_ERROR unless frame.flags & FLAG_PAD_LOW == FLAG_PAD_LOW
			pad += payload.unpack('S<').first
			payload = payload.byteslice(1,-1)
		elsif frame.flags & FLAG_PAD_LOW == FLAG_PAD_LOW
			pad += payload.unpack('C').first
			payload = payload.byteslice(1,-1)
		end

		[pad, payload]
	end

	def self.generate_padding p, flags: 0, head: '', tail: ''
		if p > 0xFF
			flags |= FLAG_PAD_HIGH | FLAG_PAD_LOW
			head << [p].pack('S<')
			tail << (PAD_OCTET * @padding)
		elsif p > 0
			flags |= FLAG_PAD_LOW
			head << [p].pack('C')
			tail << (PAD_OCTET * @padding)
		end
		[flags, head, tail]
	end
end

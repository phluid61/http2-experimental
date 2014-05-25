
module HPACK

	HUFFMAN_BIT = 0x80

	INDEXED_BIT         = 0x80
	LITERAL_INDEXED_BIT = 0x40
	CONTEXT_UPDATE_BIT  = 0x20
	LITERAL_NOINDEX_BIT = 0x10

	#
	# Returns one or more bytes encoding the integer +i+.
	#
	# @param Integer i the integer to encode
	# @param Integer prefix_bits
	# @param byte prefix the current value of the first byte
	#
	def self.encode_int i, prefix_bits: 8, prefix: 0
		raise ArgumentError if i < 0
		raise ArgumentError if prefix_bits < 1 || prefix_bits > 8
		case prefix
		when Integer
			raise ArgumentError if prefix < 0x00 || prefix > 0xFF
		when String
			raise ArgumentError if prefix.bytesize != 1
			prefix = prefix.unpack('C').first
		when nil
			prefix = 0
		else
			raise ArgumentError
		end
		prefix_mask = (2 ** prefix_bits) - 1
		raise ArgumentError if (prefix & prefix_mask) != 0
		if i < prefix_mask
			[prefix | i].pack('C')
		else
			bytes = ''
			bytes << [prefix | prefix_mask].pack('C')
			i -= prefix_mask
			while i >= 0x80
				bytes << [(i & 0x7F) | 0x80].pack('C')
				i >>= 7
			end
			bytes << [i].pack('C')
		end
	end

	#
	# Decodes an integer.
	#
	# @param String bytes
	# @param Integer prefix_bits
	# @return byte prefix, Integer i, String rest
	#
	def self.decode_int bytes, prefix_bits: 8
		bytes = bytes.to_s unless bytes.is_a? String
		raise ArgumentError if bytes.empty?
		raise ArgumentError if prefix_bits < 1 || prefix_bits > 8
		prefix_mask = (2 ** prefix_bits) - 1
		prefix, bytes = bytes.unpack('Ca*')
		i = prefix & prefix_mask
		prefix = [prefix - i].pack('C')
		if i >= prefix_mask
			shift = 1
			loop do
				b, bytes = bytes.unpack('Ca*')
				i += (b & 0x7F) * shift
				shift <<= 7
				break unless (b & 0x80) == 0x80
			end
		end
		[prefix, i, bytes]
	end

	#
	# Length-encodes a string literal.
	#
	# Doesn't do any Huffman coding (yet?).
	#
	def self.encode_string str
		self.encode_int(str.bytesize, prefix_bits: 7) + str
	end

	#
	# Reads a length-encoded string literal from the start
	# of a sequence of bytes.
	#
	# Doesn't handle Huffman coding (yet?).
	#
	# @return String str, String rest
	#
	def self.decode_string bytes
		bytes = bytes.to_s unless bytes.is_a? String
		raise ArgumentError if bytes.empty?
		prefix, length, bytes = self.decode_int bytes, prefix_bits: 7
		string = ''
		if length > 0
			string = bytes.byteslice(0, length)
			bytes = bytes.byteslice(length..-1)
		end
		raise NotImplementedError if (prefix.unpack('C').first & HUFFMAN_BIT) == HUFFMAN_BIT
		[string, bytes]
	end

end

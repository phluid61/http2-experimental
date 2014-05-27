
module HPACK

	HUFFMAN_BIT = 0x80

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
	# Uses Huffman coding iff that results in a shorter string.
	#
	def self.encode_string str
		huff = self.huffman_code_for str
		if huff.bytesize < str.bytesize
			self.encode_int(huff.bytesize, prefix_bits: 7, prefix: HUFFMAN_BIT) + huff
		else
			self.encode_int(str.bytesize, prefix_bits: 7) + str
		end
	end

	#
	# Reads a length-encoded string literal from the start
	# of a sequence of bytes.
	#
	# Decodes Huffman coded strings.
	#
	# @return [String str, String rest]
	#
	def self.decode_string bytes
		bytes = bytes.to_s unless bytes.is_a? String
		raise ArgumentError if bytes.empty?
		prefix, length, bytes = self.decode_int bytes, prefix_bits: 7
		raise ArgumentError if bytes.bytesize < length
		string = ''
		if length > 0
			string = bytes.byteslice(0, length)
			bytes = bytes.byteslice(length..-1)
		end
		# Handle Huffman-coded strings.
		if (prefix.unpack('C').first & HUFFMAN_BIT) == HUFFMAN_BIT
			string = self.string_from(string)
		end
		[string, bytes]
	end

	#
	# Get the Huffman code for a string.
	#
	def self.huffman_code_for str
		bytes = []
		bitq = 0  # a queue
		bitn = 0  # depth of the queue
		str.each_byte do |idx|
			bits, n = HuffmanCodes[idx]
			bitq = (bitq << n) | bits  # (max 33 bits wide)
			bitn += n
			# canibalise the top bytes
			while bitn >= 8
				shift = bitn - 8
				mask = 0xFF << shift
				val = (bitq & mask)
				bytes << (val >> shift)
				bitq ^= val
				bitn -= 8
			end
		end
		# pad with EOS (incidentally all 1s)
		if bitn > 0
			shift = 8 - bitn
			mask = (1 << shift) - 1
			bytes << ((bitq << shift) | mask)
		end
		bytes.pack('C*')
	end

	#
	# Get the string from a Huffman code.
	#
	# @throws RuntimeError if the code is invalid
	#
	def self.string_from huff
		return '' if huff.bytesize == 0
		bytes = huff.unpack('C*')
		str = []
		tc = HuffmanDecodes
		catch(:done) do
			until bytes.empty?
				byte = bytes.shift
				bc = 0x80
				mask = 0x7F
				while bc > 0
					bit = (byte & bc) == bc ? 1 : 0
					tc = tc[bit]
					if tc.is_a? Integer
						str << tc
						if bytes.empty? && (byte & mask) == mask
							tc = nil
							throw :done
						else
							tc = HuffmanDecodes
						end
					elsif tc.nil?
						raise "invalid Huffman code"
					end
					bc >>= 1
					mask >>= 1
				end
			end
		end
		if tc
			raise "invalid Huffman code"
		end
		str.pack('C*')
	end

	HuffmanCodes = [
		[0x3ffffba, 26], [0x3ffffbb, 26], [0x3ffffbc, 26],
		[0x3ffffbd, 26], [0x3ffffbe, 26], [0x3ffffbf, 26],
		[0x3ffffc0, 26], [0x3ffffc1, 26], [0x3ffffc2, 26],
		[0x3ffffc3, 26], [0x3ffffc4, 26], [0x3ffffc5, 26],
		[0x3ffffc6, 26], [0x3ffffc7, 26], [0x3ffffc8, 26],
		[0x3ffffc9, 26], [0x3ffffca, 26], [0x3ffffcb, 26],
		[0x3ffffcc, 26], [0x3ffffcd, 26], [0x3ffffce, 26],
		[0x3ffffcf, 26], [0x3ffffd0, 26], [0x3ffffd1, 26],
		[0x3ffffd2, 26], [0x3ffffd3, 26], [0x3ffffd4, 26],
		[0x3ffffd5, 26], [0x3ffffd6, 26], [0x3ffffd7, 26],
		[0x3ffffd8, 26], [0x3ffffd9, 26], [0x6, 5], [0x1ffc, 13],
		[0x1f0, 9], [0x3ffc, 14], [0x7ffc, 15], [0x1e, 6], [0x64, 7],
		[0x1ffd, 13], [0x3fa, 10], [0x1f1, 9], [0x3fb, 10], [0x3fc, 10],
		[0x65, 7], [0x66, 7], [0x1f, 6], [0x7, 5], [0x0, 4], [0x1, 4],
		[0x2, 4], [0x8, 5], [0x20, 6], [0x21, 6], [0x22, 6], [0x23, 6],
		[0x24, 6], [0x25, 6], [0x26, 6], [0xec, 8], [0x1fffc, 17],
		[0x27, 6], [0x7ffd, 15], [0x3fd, 10], [0x7ffe, 15], [0x67, 7],
		[0xed, 8], [0xee, 8], [0x68, 7], [0xef, 8], [0x69, 7], [0x6a, 7],
		[0x1f2, 9], [0xf0, 8], [0x1f3, 9], [0x1f4, 9], [0x1f5, 9],
		[0x6b, 7], [0x6c, 7], [0xf1, 8], [0xf2, 8], [0x1f6, 9], [0x1f7, 9],
		[0x6d, 7], [0x28, 6], [0xf3, 8], [0x1f8, 9], [0x1f9, 9], [0xf4, 8],
		[0x1fa, 9], [0x1fb, 9], [0x7fc, 11], [0x3ffffda, 26], [0x7fd, 11],
		[0x3ffd, 14], [0x6e, 7], [0x3fffe, 18], [0x9, 5], [0x6f, 7],
		[0xa, 5], [0x29, 6], [0xb, 5], [0x70, 7], [0x2a, 6], [0x2b, 6],
		[0xc, 5], [0xf5, 8], [0xf6, 8], [0x2c, 6], [0x2d, 6], [0x2e, 6],
		[0xd, 5], [0x2f, 6], [0x1fc, 9], [0x30, 6], [0x31, 6], [0xe, 5],
		[0x71, 7], [0x72, 7], [0x73, 7], [0x74, 7], [0x75, 7], [0xf7, 8],
		[0x1fffd, 17], [0xffc, 12], [0x1fffe, 17], [0xffd, 12],
		[0x3ffffdb, 26], [0x3ffffdc, 26], [0x3ffffdd, 26],
		[0x3ffffde, 26], [0x3ffffdf, 26], [0x3ffffe0, 26],
		[0x3ffffe1, 26], [0x3ffffe2, 26], [0x3ffffe3, 26],
		[0x3ffffe4, 26], [0x3ffffe5, 26], [0x3ffffe6, 26],
		[0x3ffffe7, 26], [0x3ffffe8, 26], [0x3ffffe9, 26],
		[0x3ffffea, 26], [0x3ffffeb, 26], [0x3ffffec, 26],
		[0x3ffffed, 26], [0x3ffffee, 26], [0x3ffffef, 26],
		[0x3fffff0, 26], [0x3fffff1, 26], [0x3fffff2, 26],
		[0x3fffff3, 26], [0x3fffff4, 26], [0x3fffff5, 26],
		[0x3fffff6, 26], [0x3fffff7, 26], [0x3fffff8, 26],
		[0x3fffff9, 26], [0x3fffffa, 26], [0x3fffffb, 26],
		[0x3fffffc, 26], [0x3fffffd, 26], [0x3fffffe, 26],
		[0x3ffffff, 26], [0x1ffff80, 25], [0x1ffff81, 25],
		[0x1ffff82, 25], [0x1ffff83, 25], [0x1ffff84, 25],
		[0x1ffff85, 25], [0x1ffff86, 25], [0x1ffff87, 25],
		[0x1ffff88, 25], [0x1ffff89, 25], [0x1ffff8a, 25],
		[0x1ffff8b, 25], [0x1ffff8c, 25], [0x1ffff8d, 25],
		[0x1ffff8e, 25], [0x1ffff8f, 25], [0x1ffff90, 25],
		[0x1ffff91, 25], [0x1ffff92, 25], [0x1ffff93, 25],
		[0x1ffff94, 25], [0x1ffff95, 25], [0x1ffff96, 25],
		[0x1ffff97, 25], [0x1ffff98, 25], [0x1ffff99, 25],
		[0x1ffff9a, 25], [0x1ffff9b, 25], [0x1ffff9c, 25],
		[0x1ffff9d, 25], [0x1ffff9e, 25], [0x1ffff9f, 25],
		[0x1ffffa0, 25], [0x1ffffa1, 25], [0x1ffffa2, 25],
		[0x1ffffa3, 25], [0x1ffffa4, 25], [0x1ffffa5, 25],
		[0x1ffffa6, 25], [0x1ffffa7, 25], [0x1ffffa8, 25],
		[0x1ffffa9, 25], [0x1ffffaa, 25], [0x1ffffab, 25],
		[0x1ffffac, 25], [0x1ffffad, 25], [0x1ffffae, 25],
		[0x1ffffaf, 25], [0x1ffffb0, 25], [0x1ffffb1, 25],
		[0x1ffffb2, 25], [0x1ffffb3, 25], [0x1ffffb4, 25],
		[0x1ffffb5, 25], [0x1ffffb6, 25], [0x1ffffb7, 25],
		[0x1ffffb8, 25], [0x1ffffb9, 25], [0x1ffffba, 25],
		[0x1ffffbb, 25], [0x1ffffbc, 25], [0x1ffffbd, 25],
		[0x1ffffbe, 25], [0x1ffffbf, 25], [0x1ffffc0, 25],
		[0x1ffffc1, 25], [0x1ffffc2, 25], [0x1ffffc3, 25],
		[0x1ffffc4, 25], [0x1ffffc5, 25], [0x1ffffc6, 25],
		[0x1ffffc7, 25], [0x1ffffc8, 25], [0x1ffffc9, 25],
		[0x1ffffca, 25], [0x1ffffcb, 25], [0x1ffffcc, 25],
		[0x1ffffcd, 25], [0x1ffffce, 25], [0x1ffffcf, 25],
		[0x1ffffd0, 25], [0x1ffffd1, 25], [0x1ffffd2, 25],
		[0x1ffffd3, 25], [0x1ffffd4, 25], [0x1ffffd5, 25],
		[0x1ffffd6, 25], [0x1ffffd7, 25], [0x1ffffd8, 25],
		[0x1ffffd9, 25], [0x1ffffda, 25], [0x1ffffdb, 25],
		[0x1ffffdc, 25],
	]

	HuffmanDecodes = [[[[48,49],[50,[32,47]]],[[[51,97],[99,101]],[[105,
		111],[116,[37,46]]]]],[[[[[52,53],[54,55]],[[56,57],[58,61]]],
		[[[84,100],[103,104]],[[108,109],[110,112]]]],[[[[114,115],[[38,
		44],[45,65]]],[[[68,70],[71,77]],[[78,83],[95,98]]]],[[[[102,117],
		[118,119]],[[120,121],[[59,66],[67,69]]]],[[[[73,79],[80,85]],
		[[88,106],[107,122]]],[[[[34,41],[72,74]],[[75,76],[81,82]]],
		[[[86,87],[89,90]],[[113,[40,42]],[[43,63],[[91,93],[[124,126],
		[[33,39],[[35,94],[[36,62],[64,[[60,123],[125,[96,[[[[[[[164,165],
		[166,167]],[[168,169],[170,171]]],[[[172,173],[174,175]],[[176,
		177],[178,179]]]],[[[[180,181],[182,183]],[[184,185],[186,187]]],
		[[[188,189],[190,191]],[[192,193],[194,195]]]]],[[[[[196,197],[198,
		199]],[[200,201],[202,203]]],[[[204,205],[206,207]],[[208,209],
		[210,211]]]],[[[[212,213],[214,215]],[[216,217],[218,219]]],[[[220,
		221],[222,223]],[[224,225],[226,227]]]]]],[[[[[[228,229],[230,
		231]],[[232,233],[234,235]]],[[[236,237],[238,239]],[[240,241],
		[242,243]]]],[[[[244,245],[246,247]],[[248,249],[250,251]]],[[[252,
		253],[254,255]],[[nil,[0,1]],[[2,3],[4,5]]]]]],[[[[[[6,7],[8,9]],
		[[10,11],[12,13]]],[[[14,15],[16,17]],[[18,19],[20,21]]]],[[[[22,
		23],[24,25]],[[26,27],[28,29]]],[[[30,31],[92,127]],[[128,129],
		[130,131]]]]],[[[[[132,133],[134,135]],[[136,137],[138,139]]],
		[[[140,141],[142,143]],[[144,145],[146,147]]]],[[[[148,149],[150,
		151]],[[152,153],[154,155]]],[[[156,157],[158,159]],[[160,161],
		[162,163]]]]]]]]]]]]]]]]]]]]]]]]]]

	private_constant :HuffmanCodes, :HuffmanDecodes

end

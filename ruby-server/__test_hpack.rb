# Encoding: ascii-8bit

require 'minitest/autorun'
require 'minitest/unit'
$VERBOSE = true

require_relative 'hpack/core'

class Test_hpack < MiniTest::Unit::TestCase

	def test_encode_int
		[
			[0x00, "\x00"],
			[0x01, "\x01"],
			[0xFE, "\xFE"],
			[0xFF, "\xFF\x00"],
			[0x100,"\xFF\x01"],
		].each do |i, x|
			assert_equal( x.bytes, HPACK.encode_int(i).bytes )
		end
	end

	def test_encode_int2
		[
			[0x01, 8, "\x01"],
			[0xFF, 8, "\xFF\x00"],
			[0x01, 7, "\x01"],
			[0x7E, 7, "\x7E"],
			[0x7F, 7, "\x7F\x00"],
			[0xFE, 7, "\x7F\x7F"],
			[0xFF, 7, "\x7F\x80\x01"],
			[0x100,7, "\x7F\x81\x01"],
		].each do |i, b, x|
			assert_equal( x.bytes, HPACK.encode_int(i, prefix_bits: b).bytes )
		end
	end

	def test_encode_int3
		[
			[0x01, 8, 0,    "\x01"],
			[0x01, 8, "\0", "\x01"],
			[0x01, 7, 0,     "\x01"],
			[0x01, 7, "\x0", "\x01"],
			[0x01, 7, 0x80,  "\x81"],
		].each do |i, b, p, x|
			assert_equal( x.bytes, HPACK.encode_int(i, prefix_bits: b, prefix: p).bytes )
		end
	end

	def test_encode_intX
		[
			[-1, 8, 0], # i < 0
			[1, 0, 0],  # prefix bits < 0
			[1, 9, 0],  # prefix bits > 8
			[1, 8, -1], # prefix < 0x00
			[1, 8, 0x100], # prefix > 0xFF
			[1, 8, ""],   # prefix not 1 byte
			[1, 8, "XX"], # prefix not 1 byte
			[1, 8, self], # prefix not Integer|String|NilClass
			[1, 4, 0xFF], # prefix sets masked bits
		].each do |i, b, p|
			assert_raises(ArgumentError) { HPACK.encode_int(i, prefix_bits: b, prefix: p) }
		end
	end

	def test_decode_int
		[
			[["\x00", 0x00, ''], "\x00"],
			[["\x00", 0x01, ''], "\x01"],
			[["\x00", 0xFE, ''], "\xFE"],
			[["\x00", 0xFF, ''], "\xFF\x00"],
			[["\x00", 0x100,''], "\xFF\x01"],
			[["\x00", 0x00, 'abc'], "\x00abc"],
			[["\x00", 0x100,'abc'], "\xFF\x01abc"],
		].each do |x, b|
			assert_equal( x, HPACK.decode_int(b) )
		end
	end

	def test_decode_int2
		[
			[["\x00", 0x00, ''], "\x00", 8],
			[["\x00", 0xFF, ''], "\xFF\x00", 8],
			[["\x00", 0x01, ''], "\x01", 7],
			[["\x00", 0x7E, ''], "\x7E", 7],
			[["\x00", 0x7F, ''], "\x7F\x00", 7],
			[["\x00", 0xFE, ''], "\x7F\x7F", 7],
			[["\x00", 0xFF, ''], "\x7F\x80\x01", 7],
			[["\x00", 0x100,''], "\x7F\x81\x01", 7],
			[["\x80", 0x01, ''], "\x81", 7],
			[["\x80", 0x100,''], "\xFF\x81\x01", 7],
			[["\x00", 0x00, 'abc'], "\x00abc", 8],
			[["\x00", 0x01, 'abc'], "\x01abc", 7],
		].each do |x, b, p|
			assert_equal( x.inspect, HPACK.decode_int(b, prefix_bits: p).inspect )
		end
	end

	def test_decode_intX
		[
			['', 8], # no bytes
			["\x00", -1], # prefix bits < 0
			["\x00", 9], # prefix bits > 8
		].each do |b, p|
			assert_raises(ArgumentError) { HPACK.decode_int(b, prefix_bits: p) }
		end
	end

	def test_huffman_code_for
		[
			['', ''],
			[';', "\xEC"],
			['3', 'G'],
			['33', 'B?'],
			['1020', "\x10\x20"],
			["\xA3", "\xFF\xFF\xFF\xFF"],
			['www.example.com', "\xE7\xCF\x9B\xEB\xE8\x9B\x6F\xB1\x6F\xA9\xB6\xFF"],
			['/.well-known/host-meta', "\x3B\xFC\xD7\x65\x99\xBD\xAE\x6F\x3B\x8F\x5B\x71\x76\x6B\x56\xE4\xFF"],
		].each do |s, x|
			assert_equal( x, HPACK.huffman_code_for(s) )
		end
	end

	def test_string_from
		[
			['', ''],
			[';', "\xEC"],
			['3', 'G'],
			['33', 'B?'],
			['1020', "\x10\x20"],
			["\xA3", "\xFF\xFF\xFF\xFF"],
			['www.example.com', "\xE7\xCF\x9B\xEB\xE8\x9B\x6F\xB1\x6F\xA9\xB6\xFF"],
			['/.well-known/host-meta', "\x3B\xFC\xD7\x65\x99\xBD\xAE\x6F\x3B\x8F\x5B\x71\x76\x6B\x56\xE4\xFF"],
		].each do |x, h|
			assert_equal( x, HPACK.string_from(h) )
		end
	end

	def test_string_fromX
		[
			"\xE0", # \xE1 would be 'f', but wrong padding
			"\xFF\xFF\xEE\x7F", # Valid encoding of EOS
		].each do |h|
			assert_raises(RuntimeError, "#{h.inspect} should be invalid") { HPACK.string_from(h) }
		end
	end

	def test_encode_string
		foo = '<?>'*86
		[
			['', "\x00"],
			['Hello', "\x84\xF9\x2E\xCB\x1B"],
			[foo, "\x7F\x83\x01#{foo}"],
		].each do |s, x|
			assert_equal( x, HPACK.encode_string(s) )
		end
	end

	def test_decode_string
		foo = 'foo'*86
		[
			[['', ''], "\x00"],
			[['Hello', ''], "\x05Hello"],
			[['Hello', ''], "\x84\xF9\x2E\xCB\x1B"],
			[[foo, ''], "\x7F\x83\x01#{foo}"],
			[['', 'bar'], "\x00bar"],
			[[foo, 'bar'], "\x7F\x83\x01#{foo}bar"],
		].each do |x, b|
			assert_equal( x, HPACK.decode_string(b) )
		end
	end

	def test_decode_stringX
		[
			'', # no bytes
			"\x01", # not enough bytes
		].each do |b|
			assert_raises(ArgumentError) { HPACK.decode_string(b) }
		end
	end

end

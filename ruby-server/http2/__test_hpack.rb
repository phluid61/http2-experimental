# Encoding: ascii-8bit

require 'minitest/autorun'
require 'minitest/unit'
$VERBOSE = true

require_relative 'hpack'

class Test_hpack < MiniTest::Test

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

	def test_encode_string
		foo = 'foo'*86
		[
			['', "\x00"],
			['Hello', "\x05Hello"],
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
			[[foo, ''], "\x7F\x83\x01#{foo}"],
			[['', 'bar'], "\x00bar"],
			[[foo, 'bar'], "\x7F\x83\x01#{foo}bar"],
		].each do |x, b|
			assert_equal( x, HPACK.decode_string(b) )
		end
	end

end

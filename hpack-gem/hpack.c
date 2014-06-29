
#include "mk-hpack/src/hpack.c"

#include "ruby.h"

#define BUFFER_SIZE (1024*16)
#define INTBUFF_SIZE 9

VALUE HPACK = Qnil;

void Init_hpack();

VALUE rb_hpack_encode_int(VALUE self, VALUE str);
/*VALUE rb_hpack_decode_int(VALUE self, VALUE str);*/
VALUE rb_huffman_encode(VALUE self, VALUE str);
VALUE rb_huffman_decode(VALUE self, VALUE str);
VALUE rb_huffman_length(VALUE self, VALUE str);
/*VALUE rb_hpack_encode(VALUE self, VALUE str);*/
/*VALUE rb_hpack_decode(VALUE self, VALUE str);*/

void Init_hpack() {
	HPACK = rb_define_module("HPACK");
	rb_define_singleton_method(HPACK, "encode_int", rb_hpack_encode_int, 1);
/*	rb_define_singleton_method(HPACK, "decode_int", rb_hpack_decode_int, 1);*/
	rb_define_singleton_method(HPACK, "huffman_encode", rb_huffman_encode, 1);
	rb_define_singleton_method(HPACK, "huffman_decode", rb_huffman_decode, 1);
	rb_define_singleton_method(HPACK, "huffman_length", rb_huffman_length, 1);
/*	rb_define_singleton_method(HPACK, "encode", rb_hpack_encode, 1);*/
/*	rb_define_singleton_method(HPACK, "decode", rb_hpack_decode, 1);*/
}

/**
 * call-seq:
 *    HPACK.encode_int i
 *    HPACK.encode_int i, prefix_bits
 *    HPACK.encode_int i, prefix_bits, prefix
 *
 * Encode an integer as a sequence of bytes.
 *
 * @param i       integer to encode
 * @param prefix_bits  bit-width of prefix (1 to 8 inclusive)
 * @param prefix    first byte, with bits before the prefix preloaded
 */
VALUE rb_hpack_encode_int(int argc, VALUE *argv, VALUE self) {
	unsigned char buffer[INTBUFF_SIZE], *buf = buffer;
	unsigned long i; unsigned long prefix_bits=8; unsigned long prefix=0;
	int error; unsigned long length;
	VALUE out;
	if (argc < 1) {
		rb_raise(rb_eArgumentError, "wrong number of arguments (0 for 1)");
	}
	if (!FIXNUM_P(*argv)) {
		rb_raise(rb_eArgumentError, "can't convert +i+ to Fixnum");
	}
	i = FIX2ULONG(*argv);
	if (argc > 1) {
		argv++;
		if (!FIXNUM_P(*argv)) {
			rb_raise(rb_eArgumentError, "can't convert +prefix_bits+ to Fixnum");
		}
		prefix_bits = FIX2ULONG(*argv);
		if (prefix_bits < 1 || prefix_bits > 8) {
			rb_raise(rb_eArgumentError, "+prefix_bits+ outside range 1..8");
		}
		if (argc > 2) {
			argv++;
			if (!FIXNUM_P(*argv)) {
				rb_raise(rb_eArgumentError, "can't convert +prefix+ to Fixnum");
			}
			prefix = FIX2ULONG(*argv);
			if (prefix > 0xFF) {
				rb_raise(rb_eArgumentError, "+prefix+ not a byte");
			}
		}
	}
	error = hpack_encode_int(
		i, prefix_bits, (unsigned char)prefix,
		*buffer, INTBUFF_SIZE, &length
	);
	if (error) {
		rb_raise(rb_eRuntimeError, "encoding error %d", error);
	}
	out = rb_str_new((char*)buf, length);
	if (buf != buffer) xfree(buf);
	return out;
}

VALUE rb_huffman_encode(VALUE self, VALUE str) {
	unsigned char buffer[BUFFER_SIZE], *buf=buffer;
	size_t n;
	int e;
	VALUE out;

	Check_Type(str, T_STRING);

	e = huffman_encode(
		(unsigned char*)RSTRING_PTR(str), (size_t)RSTRING_LEN(str), NULL,
		buf, BUFFER_SIZE, &n
	);
	if (e) {
		rb_raise(rb_eRuntimeError, "Huffman encoder error %d", e);
	}
	out = rb_str_new((char*)buf,n);
	if (buf != buffer) xfree(buf);
	return out;
}

VALUE rb_huffman_decode(VALUE self, VALUE str) {
	unsigned char buffer[BUFFER_SIZE], *buf=buffer;
	size_t n;
	int e;
	VALUE out;

	Check_Type(str, T_STRING);

	e = huffman_decode(
		(unsigned char*)RSTRING_PTR(str) ,(size_t)RSTRING_LEN(str), NULL,
		buf, BUFFER_SIZE, &n
	);
	if (e) {
		rb_raise(rb_eRuntimeError, "Huffman decoder error %d", e);
	}
	out = rb_str_new((char*)buf,n);
	if (buf != buffer) xfree(buf);
	return out;
}

VALUE rb_huffman_length(VALUE self, VALUE str) {
	size_t n;

	Check_Type(str, T_STRING);

	n = huffman_length((unsigned char*)RSTRING_PTR(str), (size_t)RSTRING_LEN(str));
	return UINT2NUM(n);
}

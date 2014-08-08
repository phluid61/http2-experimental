
#include <hpack.h>

#include "ruby.h"

#define BUFFER_SIZE (1024*16)

VALUE HPACK = Qnil;

void Init_hpack();

VALUE rb_huffman_encode(VALUE self, VALUE str);
VALUE rb_huffman_decode(VALUE self, VALUE str);

void Init_hpack() {
	HPACK = rb_define_module("HPACK");
	rb_define_singleton_method(HPACK, "huffman_encode", rb_huffman_encode, 1);
	rb_define_singleton_method(HPACK, "huffman_decode", rb_huffman_decode, 1);
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
			(unsigned char*)RSTRING_PTR(str), (size_t)RSTRING_LEN(str), NULL,
			buf, BUFFER_SIZE, &n
	);
	if (e) {
		rb_raise(rb_eRuntimeError, "Huffman decoder error %d", e);
	}
	out = rb_str_new((char*)buf,n);
	if (buf != buffer) xfree(buf);
	return out;
}


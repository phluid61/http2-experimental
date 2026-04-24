hpack-gem
=========

A Ruby native extension (C gem) that wraps the
[mk-hpack](https://github.com/phluid61/mk-hpack) C library, exposing
HPACK and Huffman encoding/decoding to Ruby.


## API

The extension defines a single `HPACK` module with four singleton methods:

- `HPACK.encode(string)` — HPACK-encode a string
- `HPACK.decode(string)` — HPACK-decode a string
- `HPACK.huffman_encode(string)` — Huffman-encode a string
- `HPACK.huffman_decode(string)` — Huffman-decode a string

All methods accept and return binary strings. On error, a `RuntimeError`
is raised with the underlying C error code.


## Prerequisites

The `mk-hpack` submodule must be initialised before building. From the
repository root:

```
git submodule update --init mk-hpack
```

The `mk-hpack/` directory inside `hpack-gem/` expects a pre-built
`hpack.h` header and `libhpack.a` static library from the submodule.

You will also need a working Ruby development environment (with
`mkmf`/`ruby.h`).


## Building

```
cd hpack-gem
ruby extconf.rb
make
```

This produces `hpack.so` (or equivalent shared library for your
platform).


## Testing

A manual test script is included:

```
ruby test/test.rb
```

The test encodes and decodes several sample strings
(e.g. `www.example.com`, `/sample/path`) and verifies round-trip
correctness for both Huffman and HPACK operations.


## Files

| File | Purpose |
|---|---|
| `extconf.rb` | `mkmf` build script; locates `hpack.h` and `libhpack.a` |
| `hpack.c` | C extension source; bridges mk-hpack functions to Ruby |
| `mk-hpack/` | Expected location of the built mk-hpack library |
| `test/test.rb` | Manual round-trip test script |

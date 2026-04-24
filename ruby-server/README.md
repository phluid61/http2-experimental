ruby-server
===========

A from-scratch, pure-Ruby implementation of an HTTP/2 server and client,
including a complete HPACK header compression implementation with Huffman
coding. This is the main experiment in the repository.


## Prerequisites

- Ruby (developed against MRI ~2.x)
- Bundler

Install dependencies:

```
bundle install
```

Dependencies (from Gemfile):

- `hashmap` — ordered hash map
- `threadpuddle` — thread pool


## Usage

### Server

```
ruby server.rb <port>
```

Starts an HTTP/2 server on the given port. The server responds with
`200 Ok` to GET requests, `501 Not Implemented` for other methods, and
`400 Bad Request` if no method is present.

### Client

```
ruby client.rb <port>
```

Connects to `localhost` on the given port, sends a `GET /` and a
`POST /` (with body `foo`), then sends GOAWAY.

### Fake client

```
ruby fake-client.rb <port>
```

A raw TCP client that sends hand-crafted binary frames: connection
preface, SETTINGS, SETTINGS ACK, a GET request, a POST with body, a
PING, and a GOAWAY. Useful for debugging the server at the wire level.

### HPACK interop test client

```
ruby __test_client.rb <port> __test_stories/story_00.json
```

Reads a JSON test case file (from the
[hpack-test-case](https://github.com/http2jp/hpack-test-case) project)
and sends each case's wire bytes as HEADERS frames to the server.

### Unit tests

```
ruby __test_hpack.rb
```

MiniTest unit tests for the HPACK module: integer encoding/decoding,
Huffman coding round-trips, and string encoding/decoding.

### Benchmarks

```
ruby __bench_hpack.rb
```

Benchmarks Huffman encode/decode across various code-length categories.
Sample results (from Ruby 2.1.2) are saved in `__bench_hpack.txt`.


## Architecture

### HPACK layer (`hpack/`)

| File | Purpose |
|---|---|
| `hpack.rb` | Entry point; loads `hpack/context` |
| `hpack/core.rb` | Low-level primitives: integer encoding/decoding (RFC 7541 §5.1), string literal encoding/decoding, Huffman coding with full code table and binary trie decoder |
| `hpack/context.rb` | `HPACK_Context` class: reference set, dynamic/static header table with eviction, indexed/literal/never-indexed header representations, the 61-entry static table |
| `hpack/__gen_codes.rb` | Code generator: parses the RFC Huffman table and emits both Ruby and C lookup structures |
| `hpack/__gentable.rb` | Standalone utility to generate C decode tables from the Ruby trie |

### HTTP/2 layer (`http2/`)

| File | Purpose |
|---|---|
| `http2.rb` | Entry point; loads the server module |
| `http2/frame.rb` | `HTTP2_Frame` base class: reads/writes the 8-byte frame header, supports all frame types |
| `http2/frame/` | Subclasses for each frame type (DATA, HEADERS, SETTINGS, PING, GOAWAY, etc.) |
| `http2/connection.rb` | Core connection state machine: HPACK contexts, settings negotiation, frame dispatch, stream management, DATA chunking, GOAWAY, PING/PONG |
| `http2/server_connection.rb` | Server-side connection: validates the HTTP/2 connection preface |
| `http2/client_connection.rb` | Client-side connection: sends the preface, starts the frame pump |
| `http2/server.rb` | `HTTP2_Server`: listens on a TCP port with a thread pool (100 threads), dispatches connections |
| `http2/client.rb` | `HTTP2_Client`: connects to a server, sends sample requests |
| `http2/stream.rb` | Stream state machine (idle → open → half-closed → closed) with header/data/push-promise/RST handling |
| `http2/error.rb` | All 13 HTTP/2 error codes with lookup helpers and a `PROTOCOL_ERROR` exception class |

### Test data (`__test_stories/`)

31 JSON test case files (`story_00.json` through `story_30.json`) from
the [hpack-test-case](https://github.com/http2jp/hpack-test-case) project
(nghttp2 stories), used by `__test_client.rb` for HPACK interop testing.

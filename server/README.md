server
======

A bare-bones HTTP/2 server written in C, targeting an **early draft** of
the HTTP/2 specification (pre-RFC 7540). It handles the connection
preface and sends initial SETTINGS, but does not yet process subsequent
frames.


## Building

Requires `gcc` and `libpthread`. No external libraries.

```
make
```

This produces a `server` binary.


## Usage

```
./server <port>
```

The server listens on the given TCP port, accepts connections in a
threaded loop (pool of 100), validates the HTTP/2 connection preface,
and sends a SETTINGS frame with flow-control options enabled. The
connection is then closed (the `connection_established()` handler is a
stub).


## Architecture

| File | Purpose |
|---|---|
| `main.c` | Entry point; parses port from `argv[1]` and starts the server |
| `server.c` / `server.h` | TCP server: socket, bind, listen, accept loop with a ring-buffer thread pool |
| `handler.c` / `handler.h` | HTTP/2 protocol handler: frame header and settings structs, connection preface validation, initial SETTINGS exchange |
| `callback.h` | Typedef for the handler function pointer (`void (*)(int sockfd)`) |
| `errors.c` / `errors.h` | `die()`: variadic fatal-error function with `perror` support |
| `mystring.c` / `mystring.h` | Utilities: `fhexdump()` for hex dumps, `read_packet()` for exact-length reads |
| `Makefile` | Build rules; compiles with `-Wall -std=c99`, links `-lpthread` |


## Notes

This implementation reflects a very early HTTP/2 draft:

- The frame header uses a **16-bit length** field (the final RFC 7540
  uses 24-bit).
- Frame type numbering differs from the final spec (e.g. `HEADERS` is
  `0x8`, `HEADERS_PRIORITY` is `0x1`).
- Settings IDs include SPDY-era names (`UPLOAD_BANDWIDTH`,
  `DOWNLOAD_BANDWIDTH`, `ROUND_TRIP_TIME`, `CURRENT_CWND`,
  `DOWNLOAD_RETRANS_RATE`).
- The connection preface can be toggled between variants via compile-time
  defines (`PRE_AC468F3`, `USE_ALT_HEADER`).
- The thread pool has a known race condition (marked `FIXME` in source).


## Cleaning

```
make clean
```

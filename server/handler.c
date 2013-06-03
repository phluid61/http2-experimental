/* vim:ts=4:sts=4:sw=4
*/

#include <sys/socket.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <byteswap.h>

#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include "errors.h"
#include "mystring.h"

const char CONNECTION_HEADER[] = {
	0x43,0x4f,0x4e,0x20,0x2a,0x20,0x48,0x54,
	0x54,0x50,0x2f,0x32,0x2e,0x30,0x0d,0x0a,
	0x0d,0x0a,0x67,0x6f,0x0d,0x0a,0x0d,0x0a};
const size_t CONNECTION_HEADER_S = sizeof(CONNECTION_HEADER);

/* the following macros assume LE machine */

typedef struct frame_header {
	uint16_t length;
	uint8_t  type;
	uint8_t  flags;
	uint32_t stream_identifier;
} frame_header;

#define FRAME_LENGTH(fh) __bswap_16((fh)->length)
#define SET_FRAME_LENGTH(fh,l) ((fh)->length=__bswap_16(l))

#define IS_FINAL(fh) ((fh)->flags&1)
#define SET_FINAL(fh) ((fh)->flags|=1)
#define CLEAR_FINAL(fh) ((fh)->flags&=0xFE)

/* for type==frame_SETTINGS */
#define SET_CLEAR_PERSISTED(fh) ((fh)->flags|=2)
#define CLEAR_CLEAR_PERSISTED(fh) ((fh)->flags&=0xFD)

#define STREAM_ID(fh) __bswap_32((fh)->stream_identifier)
#define SET_STREAM_ID(fh,id) ((fh)->stream_identifier=__bswap_32((id)&0x7FFFFFFF))

#define FRAME_TYPE(fh) ((fh)->type)
#define SET_FRAME_TYPE(fh,t) ((fh)->type=(t))
#define frame_DATA				0x0
#define frame_HEADERS_PRIORITY	0x1
#define frame_RST_STREAM		0x3
#define frame_SETTINGS			0x4
#define frame_PUSH_PROMISE		0x5
#define frame_PING				0x6
#define frame_GOAWAY			0x7
#define frame_HEADERS			0x8
#define frame_WINDOW_UPDATE		0x9

typedef struct settings_frame {
	uint8_t  flags;
	uint8_t  id0;
	uint16_t id1;
	uint32_t value;
} settings_frame;

#define SETTINGS_FLAGS(sf) ((sf)->flags)
#define SET_SETTINGS_FLAGS(sf,f) ((sf)->flags=(f))

#define SETTINGS_ID(sf) ((sf)->id0<<16|__bswap_16((sf)->id1))
#define SET_SETTINGS_ID(sf,id) {(sf)->id0=((id)>>16)&0xFF;(sf)->id1=__bswap_16((id)&0xFFFF);}

#define SETTINGS_UPLOAD_BANDWIDTH		1
#define SETTINGS_DOWNLOAD_BANDWIDTH		2
#define SETTINGS_ROUND_TRIP_TIME		3
#define SETTINGS_MAX_CONCURRENT_STREAMS	4
#define SETTINGS_CURRENT_CWND			5
#define SETTINGS_DOWNLOAD_RETRANS_RATE	6
#define	SETTINGS_INITIAL_WINDOW_SIZE	7
#define SETTINGS_FLOW_CONTROL_OPTIONS	10

#define IS_PERSISTED(sf) ((sf)->flags&2)
#define SET_PERSIST(sf) ((sf)->flags|=1)
#define CLEAR_PERSIST(sf) ((sf)->flags&=0xFE)

#define SETTINGS_VALUE(sf) __bswap_32((sf)->value)
#define SET_SETTINGS_VALUE(sf,val) ((sf)->value=__bswap_32(val))

#define init_frame_header(fh,t,id) {(fh)->length=0;(fh)->type=(t);(fh)->flags=0;(fh)->stream_identifier=(id);}
#define init_settings_frame_header(fh) {(fh)->length=sizeof(settings_frame);(fh)->type=frame_SETTINGS;(fh)->flags=0;(fh)->stream_identifier=0;}

#define init_settings_frame(sf,id,val) {(sf)->flags=0;SET_SETTINGS_ID(sf,id);SET_SETTINGS_VALUE(sf,val);}

void send_settings(int sockfd);
void connection_established(int sock_fd);

void handle(int sock_fd) {
	char inbound_connection_header[CONNECTION_HEADER_S];

	printf("Accepted socket %d\n", sock_fd);
	write(sock_fd, CONNECTION_HEADER, CONNECTION_HEADER_S);
	read_packet(sock_fd, inbound_connection_header, CONNECTION_HEADER_S);

	if (strncmp(CONNECTION_HEADER, inbound_connection_header, CONNECTION_HEADER_S)) {
		fprintf(stderr, "Connection sent bad header:\n");
		fhexdump(stderr, inbound_connection_header, CONNECTION_HEADER_S);
	} else {
		send_settings(sock_fd);
		connection_established(sock_fd);
	}

	if (close(sock_fd) < 0) {
		perror("Error closing socket");
	}
}

void send_settings(int sock_fd) {
	frame_header fh;
	settings_frame sf;

	init_settings_frame_header(&fh);
	init_settings_frame(&sf, SETTINGS_FLOW_CONTROL_OPTIONS, 1);

	write(sock_fd, (void*)&fh, sizeof(frame_header));
	write(sock_fd, (void*)&sf, sizeof(settings_frame));
}

void connection_established(int sock_fd) {
}


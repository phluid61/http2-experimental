/* vim:ts=4:sts=4:sw=4
*/

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

#include "errors.h"
#include "server.h"
#include "handler.h"

short get_port(int argc, char *argv[]);

int main(int argc, char *argv[]) {
	short port;

	port = get_port(argc, argv);
	server_start(port, (callback_t) &handle); /* infinite loop */

	return EXIT_SUCCESS; /* to make gcc happy */
}

short get_port(int argc, char *argv[]) {
	short port;
	char *end;

	if (argc != 2) {
		die("Invalid arguments");
	}

	port = strtol(argv[1], &end, 0);
	if (*end) {
		die("Invalid port number");
	}

	return port;
}


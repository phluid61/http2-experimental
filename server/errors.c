/* vim:ts=4:sts=4:sw=4
*/

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

#include <errno.h>

/* if someone needs to print an error >1kB they can suck it up for now */
#define ERROR_BUFFER_SIZE (1024)

void die(const char *fmt, ...) {
	/* happy to put the buffer on the stack; die() doesn't have to play nice */
	char buffer[ERROR_BUFFER_SIZE];
	va_list args;
	va_start(args, fmt);
	if (errno) {
		vsnprintf(buffer, (size_t)ERROR_BUFFER_SIZE, fmt, args);
		buffer[ERROR_BUFFER_SIZE-1] = 0; /* in case of truncation */
		perror((const char*)buffer);
	} else {
		vfprintf(stderr, fmt, args);
		fprintf(stderr, "\n");
	}
	va_end(args);
	exit(EXIT_FAILURE);
}


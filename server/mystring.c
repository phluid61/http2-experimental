/* vim:ts=4:sts=4:sw=4
*/

#include <sys/types.h>
#include <unistd.h>
#include <stddef.h>
#include <stdio.h>

/**
 * Hex-dump a sequence of bytes.
 * Adds a line-break after every 16th byte.
 */
void fhexdump(FILE* stream, const char* bytes, size_t n) {
	size_t i;
	char *ptr = (char*)bytes;
	for (i=0; i<n; i++, ptr++) {
		fprintf(stream, "%c%c "
				, (*ptr>>4) + ((*ptr>>4) > 9 ? ('A'-10) : '0')
				, (*ptr&15) + ((*ptr&15) > 9 ? ('A'-10) : '0')
		);
		if (i%16==15 && i<(n-1))
			fprintf(stream, "\n");
		else if (i%8==7 && i<(n-1))
			fprintf(stream, " ");
	}
	fprintf(stream, "\n");
}

/**
 * Reads nbyte bytes from the file associated with the open file
 * descriptor, fildes, into the buffer pointed to by buf.
 *
 * Returns the number of bytes read.  This should always be equal
 * to nbyte unless it hits EOF beforehand.
 *
 * Otherwise identical to read(3)
 */
ssize_t read_packet(int fildes, void *buf, size_t nbyte) {
	ssize_t total=0, this=0;
	char *ptr = (char*)buf;
	while (total < nbyte) {
		this = read(fildes, (void*)ptr, nbyte-total);
		if (this == 0)
			break;
		total += this;
		ptr += this;
	}
	return total;
}


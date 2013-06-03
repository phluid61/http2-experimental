/* vim:ts=4:sts=4:sw=4
*/

#include <stddef.h>

void fhexdump(FILE* stream, const char* bytes, size_t n);
ssize_t read_packet(int fildes, void *buf, size_t nbyte);

/* vim:ts=4:sts=4:sw=4
*/

#include <sys/socket.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <stdio.h>

#include "errors.h"

void handle(int sock_fd) {
	printf("Accepted socket %d\n", sock_fd);
	write(sock_fd, "Hello. Goodbye.\n", 17); /* TODO */

	if (close(sock_fd) < 0) {
		/*die("Error closing socket");*/ /* FIXME: maybe not so fatal? */
		perror("Error closing socket");
	}
}


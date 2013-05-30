/* vim:ts=4:sts=4:sw=4
*/

#include <sys/socket.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#include <pthread.h>

#include <string.h>

#include "errors.h"
#include "callback.h"

#define LISTEN_QUEUE (100)

void init_thread_pool();
void spawn_handler(callback_t handler, int sockfd);

void server_start(short port, callback_t handler) {
	int listen_sock;
	int connect_sock;
	struct sockaddr_in servaddr;

	listen_sock = socket(AF_INET, SOCK_STREAM, 0);
	if (listen_sock < 0) {
		die("Error creating listening socket");
	}

	memset(&servaddr, 0, sizeof(servaddr));
	servaddr.sin_family = AF_INET;
	servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
	servaddr.sin_port = htons(port);

	if (bind(listen_sock, (struct sockaddr*)&servaddr, sizeof(servaddr)) < 0) {
		die("Error binding listening socket");
	}
	if (listen(listen_sock, LISTEN_QUEUE) < 0) {
		die("Error listening on socket");
	}

	init_thread_pool();
	while (1) {
		connect_sock = accept(listen_sock, NULL, NULL);
		if (connect_sock < 0) {
			die("Error accepting connectiong");
		}
		spawn_handler(handler, connect_sock);
	}
}


/*----- THREAD POOL BELOW: -----*/

/*struct thread_pool {*/
	pthread_t *thread_pool; /* ring buffer */
	pthread_t *thread_pool_end; /* do not modify */
	pthread_t *next_thread;
/*}*/

typedef struct thread_data {
	pthread_t *tptr;
	callback_t handler;
	int sockfd;
} thread_data;

void init_thread_pool() {
	thread_pool = (pthread_t*) malloc(sizeof(pthread_t) * LISTEN_QUEUE);
	thread_pool_end = thread_pool + LISTEN_QUEUE;
	memset(thread_pool, 0, sizeof(thread_pool));
	next_thread = (pthread_t*)thread_pool;
}

void _handler(thread_data *data) {
	data->handler(data->sockfd);

	/* FIXME: racy! add mutex */
	*(data->tptr) = 0;
}

void spawn_handler(callback_t handler, int sockfd) {
	pthread_t *ptr;
	pthread_t *eol;
	int stat;
	struct thread_data data;

	ptr = next_thread;
	eol = next_thread;
	while (*ptr != 0) {
		ptr ++;
		if (ptr >= thread_pool_end) ptr = thread_pool;
		if (ptr == eol) die("No free threads (FIXME: this should not be fatal.)");
	}

	data.tptr = ptr;
	data.handler = handler;
	data.sockfd  = sockfd;
	stat = pthread_create(ptr, NULL, (void*) &_handler, (void*) &data);
	if (stat != 0) {
		die("Error creating thread: [%d] %s", stat, strerror(stat)); /* FIXME: too fatal? */
	}
}


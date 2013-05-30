
CC=gcc
#COPTS=-Wall -std=c99 -O3
COPTS=-Wall -std=c99
OBJECTS=main.o errors.o server.o handler.o
.PHONY: clean

server: $(OBJECTS)
	$(CC) $(OBJECTS) -o $@ -lpthread

main.o: main.c errors.h server.h handler.h
	$(CC) $(COPTS) -c $< -o $@

errors.o: errors.c
	$(CC) $(COPTS) -c $< -o $@

server.o: server.c errors.h callback.h
	$(CC) $(COPTS) -c $< -o $@

handler.o: handler.c
	$(CC) $(COPTS) -c $< -o $@


clean:
	-rm -r $(OBJECTS)


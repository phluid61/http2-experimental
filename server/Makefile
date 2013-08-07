
CC=gcc
#COPTS=-Wall -std=c99 -O3
COPTS=-Wall -std=c99
HANDLER_OPTS=-D USE_DRAFT_HEADER -D AC468F3
OBJECTS=main.o errors.o server.o handler.o mystring.o
.PHONY: clean

server: $(OBJECTS)
	$(CC) $(OBJECTS) -o $@ -lpthread

main.o: main.c errors.h server.h handler.h
	$(CC) $(COPTS) -c $< -o $@

errors.o: errors.c
	$(CC) $(COPTS) -c $< -o $@

server.o: server.c errors.h callback.h
	$(CC) $(COPTS) -c $< -o $@

handler.o: handler.c mystring.h
	$(CC) $(COPTS) $(HANDLER_OPTS) -c $< -o $@

mystring.o: mystring.c
	$(CC) $(COPTS) -c $< -o $@

clean:
	-rm -r $(OBJECTS)


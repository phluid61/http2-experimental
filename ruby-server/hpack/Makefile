CC=/usr/bin/gcc
COPTS=-Wall

OBJS=huffman.o
HEADERS=huffman.h
TARGET=test
SRC=$(TARGET).c

$(TARGET): $(SRC) $(HEADERS) $(OBJS)
	$(CC) $(COPTS) $< $(OBJS) -o $@

.PHONY: run
run: $(TARGET)
	./$(TARGET)
	@echo "$$? test failures"

.PHONY: clean
clean:
	rm -r $(TARGET) $(OBJS)


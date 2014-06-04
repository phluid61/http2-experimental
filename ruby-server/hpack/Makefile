.SUFFIXES:
CC=/usr/bin/gcc
CFLAGS=-Wall

# Names of target libraries
NAMES := huffman

# Headers & Objects for using target libraries
huffman_HEADERS = huffman.h
huffman_OBJECTS = huffman.o

# Handy rule targets
OBJECTS := $(addsuffix .o,$(NAMES))
TESTS := $(addprefix test-,$(NAMES))
TEST_OBJECTS := $(addsuffix .o,$(TESTS))

#
# General rules
#

.PHONY: all
all: objs tests

.PHONY: objs
objs: $(OBJECTS)

.PHONY: tests
tests: $(TESTS)

.PHONY: test
test: tests
	@$(foreach t,$(TESTS),echo "$(t)"; ./$(t); echo "$$? test failures";) echo "Done"

#
# Test programs
#

define TEST_rules
$(1).o: $(1).c $$($(1)_HEADERS)
	$$(CC) $$(CFLAGS) -c $$< -o $$@

$(1): $(1).o $$($(1)_OBJECS)
	$$(CC) $$(CFLAGS) $$< $$($(1)_OBJECTS) -o $$@
endef
$(foreach prog,$(TESTS),$(eval $(call TEST_rules,$(prog))))


#
# Objects
#

%.o: %.c %.h
	$(CC) $(CFLAGS) -c $< -o $@


#
# Housekeeping
#

.PHONY: clean
clean:
	-rm $(TESTS) $(TEST_OBJECTS) $(OBJECTS)


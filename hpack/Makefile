.SUFFIXES:
CC=/usr/bin/gcc
CFLAGS=-Wall -O1

# Names of target libraries
NAMES := huffman

# Headers & Objects for using target libraries
huffman_HEADERS = huffman.h
huffman_OBJECTS = huffman.o

# Headers & Sources for building target libraries
huffman_HEADER = huffman.h
huffman_SOURCE = huffman.c

# Lists ...
OBJECTS :=
TEST_OBJECTS :=
TESTS :=


#
# Default rule
#

.PHONY: all
all: objs tests


#
# Libraries and tests
#

define LIBRARY_RULES

ifeq (,$$(findstring $(1).o,$$(OBJECTS)))
	OBJECTS += $(1).o
endif
$(1).o: $$($(1)_SOURCE) $$($(1)_HEADER)
	$$(CC) $$(CFLAGS) -c $$< -o $$@

TEST_OBJECTS += test-$(1).o
test-$(1).o: test-$(1).c $$($(1)_HEADERS)
	$$(CC) $$(CFLAGS) -c $$< -o $$@

TESTS += test-$(1)
test-$(1): test-$(1).o $$($(1)_OBJECTS)
	$$(CC) $$(CFLAGS) $$^ -o $$@

endef
$(foreach lib,$(NAMES),$(eval $(call LIBRARY_RULES,$(lib))))


#
# Working with lists
#

.PHONY: objs
objs: $(OBJECTS)

.PHONY: tests
tests: $(TESTS)

.PHONY: run-tests
run-tests: tests
	@$(foreach t,$(TESTS),echo "$(t)"; ./$(t); echo "$$? test failures";) echo "Done"

.PHONY: clean
clean:
	-rm $(TESTS) $(TEST_OBJECTS) $(OBJECTS)


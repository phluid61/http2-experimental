.SUFFIXES:
CC=/usr/bin/gcc
CFLAGS=-Wall

NAMES := huffman

OBJS := $(addsuffix .o,$(NAMES))
HEADERS := $(addsuffix .h,$(NAMES))
TESTS := $(addprefix test-,$(NAMES))
TEST_OBJS := $(addsuffix .o,$(TESTS))

#
# General rules
#

.PHONY: all
all: objs tests

.PHONY: objs
objs: $(OBJS)

.PHONY: tests
tests: $(TESTS)

.PHONY: test
test: tests
	@$(foreach t,$(TESTS),./$(t); )echo "$$? test failures"

#
# Test programs
#

define TEST_rules
$(1).o: $(1).c $$(HEADERS)
	$$(CC) $$(CFLAGS) -c $$< -o $$@

$(1): $(1).o $$(OBJS)
	$$(CC) $$(CFLAGS) $$< $$(OBJS) -o $$@
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
	-rm $(TESTS) $(TEST_OBJS) $(OBJS)


# Disable default suffix rules
.SUFFIXES:
# Using bash as shell for commands
SHELL := /bin/bash
LSSRC := $(wildcard *.ls)
COFFEESRC += $(wildcard *.coffee)
TESTS := $(LSSRC:.ls=.js) 
TESTS += $(COFFEESRC:.coffee=.js)

all: $(SRC) $(TESTS)
	@for i in $(TESTS); do echo "[Test] $$i ..."; casperjs $$i; done

%.js: %.ls
	lsc -c $<

%.js: %.coffee
	coffee -c $<

.PHONY: all

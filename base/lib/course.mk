# Included by each course's Makefile:  include ../../base/lib/course.mk
ROOT    := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
KDRILL  ?= $(ROOT)/bin/kdrill
COURSE  := $(notdir $(CURDIR))

.DEFAULT_GOAL := help
.PHONY: help start stop lessons status

$(KDRILL):
	$(MAKE) -C $(ROOT) build

help:
	@echo "Course $(COURSE): make start | stop | status"

start stop: $(KDRILL)
	@$(KDRILL) course $@ $(COURSE)
status lessons: $(KDRILL)
	@$(KDRILL) status $(COURSE)

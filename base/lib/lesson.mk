# Included by each lesson's Makefile:  include ../../../../base/lib/lesson.mk
# Runs kdrill commands for the lesson in the current directory.
ROOT    := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
KDRILL  ?= $(ROOT)/bin/kdrill
LESSON  := $(notdir $(CURDIR))
COURSE  := $(notdir $(abspath $(CURDIR)/../..))
REF     := $(COURSE)/$(LESSON)

.DEFAULT_GOAL := help
.PHONY: help setup verify hint reset cleanup solution show next status py

$(KDRILL):
	$(MAKE) -C $(ROOT) build

help:
	@echo "Lesson $(REF)"
	@echo "  make setup     start this lesson"
	@echo "  make verify    check your work"
	@echo "  make hint      next hint"
	@echo "  make reset     start over"
	@echo "  make cleanup   remove lesson resources"
	@echo "  make solution  show the solution"
	@echo "  make show      reprint the task"
	@echo "  make next      clean up and start the next lesson"
	@echo "  make status    cluster, active lesson and this course's progress"
	@echo "  make py F=x.py run Python in the course container (local courses only)"

setup: $(KDRILL)
	@$(KDRILL) start $(REF)
verify hint reset cleanup solution show: $(KDRILL)
	@$(KDRILL) $@ $(REF)
# next works from the active lesson, which must be this one.
next: $(KDRILL)
	@$(KDRILL) next $(REF)
status: $(KDRILL)
	@$(KDRILL) status $(COURSE)
# Local courses: run Python in the course container. make py F=file.py ARGS="..."
py: $(KDRILL)
	@$(KDRILL) py $(F) $(ARGS)

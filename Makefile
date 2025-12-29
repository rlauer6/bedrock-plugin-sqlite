#-*- mode: makefile; -*-

PERL_MODULES = \
    lib/BLM/Startup/SQLiteSession.pm

SHELL := /bin/bash

.SHELLFLAGS := -ec

VERSION := $(shell cat VERSION)

TARBALL = BLM-Startup-SQLiteSession-$(VERSION).tar.gz

%.pm: %.pm.in
	sed  's/[@]PACKAGE_VERSION[@]/$(VERSION)/;' $< > $@

$(TARBALL): buildspec.yml $(PERL_MODULES) requires test-requires README.md
	make-cpan-dist.pl -b $<

README.md: lib/BLM/Startup/SQLiteSession.pm
	pod2markdown $< > $@

include version.mk

clean:
	rm -f *.tar.gz $(PERL_MODULES)


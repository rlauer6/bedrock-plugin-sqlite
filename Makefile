#-*- mode: makefile; -*-

PERL_MODULES = \
    lib/BLM/Startup/SQLiteSession.pm

VERSION := $(shell perl -I lib -MBLM::Startup::SQLiteSession -e 'print $$BLM::Startup::SQLiteSession::VERSION;')

TARBALL = BLM-Startup-SQLiteSession-$(VERSION).tar.gz

$(TARBALL): buildspec.yml $(PERL_MODULES) requires test-requires README.md
	make-cpan-dist.pl -b $<

README.md: lib/BLM/Startup/SQLiteSession.pm
	pod2markdown $< > $@

clean:
	rm -f *.tar.gz

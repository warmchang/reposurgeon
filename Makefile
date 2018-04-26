#
# makefile for reposurgeon
#

INSTALL=install
XMLTO=xmlto
XMLTOOPTS=-m docbook-extra.xml
ASCIIDOC=asciidoc
PYLINT=pylint
prefix?=/usr/local
mandir?=share/man
target=$(DESTDIR)$(prefix)

CYTHON?=cython
PYVERSION=2.7
pyinclude?=$(shell pkg-config --cflags python-$(PYVERSION) || echo "-I/usr/include/python$(PYVERSION)")
pylib?=$(shell pkg-config --libs python-$(PYVERSION) || echo "-lpython$(PYVERSION)")

VERS=$(shell sed <reposurgeon -n -e '/version=\"\(.*\)\"/s//\1/p')
SOURCES += docbook-extra.xml nofooter.conf
SOURCES += \
	reposurgeon reposurgeon.xml \
	repotool repotool.xml \
	repodiffer repodiffer.xml \
	repomapper repomapper.xml \
	repocutter repocutter.xml \
	reporting-bugs.asc features.asc dvcs-migration-guide.asc \
	reposurgeon-mode.el
SOURCES += Makefile control reposturgeon.png reposurgeon-git-aliases
SOURCES += Dockerfile ci/prepare.sh ci/Makefile ci/requirements.txt

.PHONY: all install clean uninstall version pylint check zip release refresh \
    docker-build docker-check docker-check-noscm

BINARIES = reposurgeon repotool repodiffer repomapper repocutter
MANPAGES = reposurgeon.1 repotool.1 repodiffer.1 repomapper.1 repocutter.1
HTMLFILES = $(MANPAGES:.1=.html) \
            dvcs-migration-guide.html features.html reporting-bugs.html
SHARED    = README.md NEWS TODO reposurgeon-git-aliases $(HTMLFILES)

all:  $(MANPAGES) $(HTMLFILES)

%.1: %.xml
	$(XMLTO) $(XMLTOOPTS) man $<

%.html: %.xml
	$(XMLTO) $(XMLTOOPTS) html-nochunks $<

dvcs-migration-guide.html: ASCIIDOC_ARGS=-a toc -f nofooter.conf
%.html: %.asc
	$(ASCIIDOC) $(ASCIIDOC_ARGS) $<

cy%.c: %
	$(CYTHON) --embed $< -o $@

cy%.o: cy%.c
	${CC} ${CFLAGS} $(pyinclude) -c $< -o $@

cy%: cy%.o
	${CC} ${CFLAGS} ${LDFLAGS} $^ $(pylib) -o $@

#
# Installation
#

install: all
	$(INSTALL) -d "$(target)/bin"
	$(INSTALL) -d "$(target)/share/doc/reposurgeon"
	$(INSTALL) -d "$(target)/$(mandir)/man1"
	$(INSTALL) -m 755 $(BINARIES) "$(target)/bin"
	$(INSTALL) -m 644 $(SHARED) "$(target)/share/doc/reposurgeon"
	$(INSTALL) -m 644 $(MANPAGES) "$(target)/$(mandir)/man1"

clean:
	rm -fr  *~ *.1 *.html *.tar.xz MANIFEST *.md5
	rm -fr .rs .rs* test/.rs test/.rs*
	rm -f typescript test/typescript *.pyc

# Uninstallation
INSTALLED_BINARIES := $(BINARIES:%="$(target)/bin/%")
INSTALLED_SHARED   := $(SHARED:%="$(target)/share/doc/reposurgeon/%")
INSTALLED_MANPAGES := $(MANPAGES:%="$(target)/$(mandir)/man1/%")

uninstall:
	rm -f $(INSTALLED_BINARIES)
	rm -f $(INSTALLED_MANPAGES)
	rm -f $(INSTALLED_SHARED)
	rmdir "$(target)/share/doc/reposurgeon"

version:
	@echo $(VERS)

#
# Code validation
#

COMMON_PYLINT = --rcfile=/dev/null --reports=n \
	--msg-template="{path}:{line}: [{msg_id}({symbol}), {obj}] {msg}" \
	--dummy-variables-rgx='^_'
PYLINTOPTS1 = "C0103,C0111,C0301,C0302,C0322,C0324,C0325,C0321,C0323,C0330,C0410,C0411,C0412,C0413,C1001,R0201,R0101,R0204,R0902,R0903,R0904,R0911,R0912,R0913,R0914,R0915,W0108,W0110,W0123,W0122,W0141,W0142,W0212,W0221,W0232,W0233,W0603,W0632,W0633,W0640,W0511,W0611,E0611,E1101,E1103,E1124,E1133,I0011,F0401"
PYLINTOPTS2 = "C0103,C0111,C0325,C0301,C0326,C0330,C0410,C1001,W0603,W0621,E1101,E1103,R0401,R0902,R0903,R0912,R0914,R0915"
PYLINTOPTS3 = "C0103,C0301,C0410,C1001,R0401,R0903,W0621"
PYLINTOPTS4 = "C0103,C0301,C0302,C0325,C0111,C0410,C0413,C1001,R0101,R0903,R0401,R0912,R0913,R0914,R0915,W0110,W0141,W0603,W0621,W1504"
pylint:
	@$(PYLINT) $(COMMON_PYLINT) --disable=$(PYLINTOPTS1) reposurgeon
	@$(PYLINT) $(COMMON_PYLINT) --disable=$(PYLINTOPTS2) repodiffer
	@$(PYLINT) $(COMMON_PYLINT) --disable=$(PYLINTOPTS3) repomapper
	@$(PYLINT) $(COMMON_PYLINT) --disable=$(PYLINTOPTS4) repocutter

check:
	cd test; $(MAKE) --quiet check

portcheck:
	cd test; $(MAKE) --quiet portcheck

#
# Continuous integration.  More specifics are in the ci/ directory
#

docker-build: $(SOURCES)
	docker build -t reposurgeon .

docker-check: docker-build
	docker run --rm -i -e "MAKEFLAGS=$(MAKEFLAGS)" -e "MAKEOVERRIDES=$(MAKEOVERRIDES)" reposurgeon make check

docker-check-only-%: docker-build
	docker run --rm -i -e "MAKEFLAGS=$(MAKEFLAGS)" -e "MAKEOVERRIDES=$(MAKEOVERRIDES)" reposurgeon bash -c "make -C ci install-only-$(*) && make check"

docker-check-no-%: docker-build
	docker run --rm -i -e "MAKEFLAGS=$(MAKEFLAGS)" -e "MAKEOVERRIDES=$(MAKEOVERRIDES)" reposurgeon bash -c "make -C ci install-no-$(*) && make check"

# Test that support for each VCS stands on its own and test without legacy
# VCS installed
docker-check-noscm: docker-check-only-bzr docker-check-only-cvs \
    docker-check-only-git docker-check-only-mercurial \
    docker-check-only-subversion docker-check-no-cvs 
# Due to many tests depending on git, docker-check-only-mercurial is a very poor
# test of Mercurial

#
# Release shipping.
#

reposurgeon-$(VERS).tar.xz: $(SOURCES)
	tar --transform='s:^:reposurgeon-$(VERS)/:' --show-transformed-names -cJf reposurgeon-$(VERS).tar.xz $(SOURCES) test

dist: reposurgeon-$(VERS).tar.xz reposurgeon.1 repotool.1 repodiffer.1

reposurgeon-$(VERS).md5: reposurgeon-$(VERS).tar.xz
	@md5sum reposurgeon-$(VERS).tar.xz >reposurgeon-$(VERS).md5

zip: $(SOURCES)
	zip -r reposurgeon-$(VERS).zip $(SOURCES)

release: reposurgeon-$(VERS).tar.xz reposurgeon-$(VERS).md5 reposurgeon.html repodiffer.html repocutter.html reporting-bugs.html dvcs-migration-guide.html features.html
	shipper version=$(VERS) | sh -e -x

refresh: reposurgeon.html repodiffer.html reporting-bugs.html features.html
	shipper -N -w version=$(VERS) | sh -e -x

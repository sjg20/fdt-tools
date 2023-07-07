# SPDX-License-Identifier: GPL-2.0-or-later
#
# Device Tree Tools
#

#
# Version information will be constructed in this order:
# EXTRAVERSION might be "-rc", for example.
# LOCAL_VERSION is likely from command line.
# CONFIG_LOCALVERSION from some future config system.
#
VERSION = 1
PATCHLEVEL = 7
SUBLEVEL = 0
EXTRAVERSION =
LOCAL_VERSION =
CONFIG_LOCALVERSION =

CPPFLAGS = -I libfdt -I . -DFDT_ASSUME_MASK=$(ASSUME_MASK)
WARNINGS = -Wall -Wpointer-arith -Wcast-qual -Wnested-externs -Wsign-compare \
	-Wstrict-prototypes -Wmissing-prototypes -Wredundant-decls -Wshadow \
	-Wsuggest-attribute=format -Wwrite-strings
CFLAGS = -g -Os $(SHAREDLIB_CFLAGS) -Werror $(WARNINGS) $(EXTRA_CFLAGS)
LDLIBS_fdtgrep = -lfdt

PKG_CONFIG ?= pkg-config
PYTHON ?= python3

INSTALL = /usr/bin/install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_LIB = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644
INSTALL_SCRIPT = $(INSTALL)
DESTDIR =
PREFIX = $(HOME)
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib
INCLUDEDIR = $(PREFIX)/include

HOSTOS := $(shell uname -s | tr '[:upper:]' '[:lower:]' | \
	    sed -e 's/\(cygwin\|msys\).*/\1/')

NO_VALGRIND := $(shell $(PKG_CONFIG) --exists valgrind; echo $$?)
ifeq ($(NO_VALGRIND),1)
	CPPFLAGS += -DNO_VALGRIND
else
	CFLAGS += $(shell $(PKG_CONFIG) --cflags valgrind)
endif

ifeq ($(HOSTOS),darwin)
SHAREDLIB_EXT     = dylib
SHAREDLIB_CFLAGS  = -fPIC
SHAREDLIB_LDFLAGS = -fPIC -dynamiclib -Wl,-install_name -Wl,
else ifeq ($(HOSTOS),$(filter $(HOSTOS),msys cygwin))
SHAREDLIB_EXT     = so
SHAREDLIB_CFLAGS  =
SHAREDLIB_LDFLAGS = -shared -Wl,--version-script=$(LIBFDT_version) -Wl,-soname,
else
SHAREDLIB_EXT     = so
SHAREDLIB_CFLAGS  = -fPIC
SHAREDLIB_LDFLAGS = -fPIC -shared -Wl,--version-script=$(LIBFDT_version) -Wl,-soname,
endif

#
# Overall rules
#
ifdef V
VECHO = :
else
VECHO = echo "	"
ARFLAGS = rc
.SILENT:
endif

NODEPTARGETS = clean
ifeq ($(MAKECMDGOALS),)
DEPTARGETS = all
else
DEPTARGETS = $(filter-out $(NODEPTARGETS),$(MAKECMDGOALS))
endif

#
# Rules for versioning
#

FDT_TOOLS_VERSION = $(VERSION).$(PATCHLEVEL).$(SUBLEVEL)$(EXTRAVERSION)
VERSION_FILE = version_gen.h

CONFIG_SHELL := $(shell if [ -x "$$BASH" ]; then echo $$BASH; \
	  else if [ -x /bin/bash ]; then echo /bin/bash; \
	  else echo sh; fi ; fi)

nullstring :=
space	:= $(nullstring) # end of line

localver_config = $(subst $(space),, $(string) \
			      $(patsubst "%",%,$(CONFIG_LOCALVERSION)))

localver_cmd = $(subst $(space),, $(string) \
			      $(patsubst "%",%,$(LOCALVERSION)))

localver_scm = $(shell $(CONFIG_SHELL) ./scripts/setlocalversion)
localver_full  = $(localver_config)$(localver_cmd)$(localver_scm)

fdt_tools_version = $(FDT_TOOLS_VERSION)$(localver_full)

# Contents of the generated version file.
define filechk_version
	(echo "#define FDT_TOOLS_VERSION \"FDT_TOOLS $(fdt_tools_version)\""; )
endef

define filechk
	set -e;					\
	echo '	CHK $@';			\
	mkdir -p $(dir $@);			\
	$(filechk_$(1)) < $< > $@.tmp;		\
	if [ -r $@ ] && cmp -s $@ $@.tmp; then	\
		rm -f $@.tmp;			\
	else					\
		echo '	UPD $@';		\
		mv -f $@.tmp $@;		\
	fi;
endef


FDTGREP_SRCS = \
	fdtgrep.c \
	fdt_region.c \
	util.c

FDTGREP_OBJS = $(FDTGREP_SRCS:%.c=%.o)

fdtgrep: $(FDTGREP_OBJS)

BIN += fdtgrep

all: $(BIN)

ifneq ($(DEPTARGETS),)
ifneq ($(MAKECMDGOALS),libfdt)
-include $(FDTGREP_OBJS:%.o=%.d)
endif
endif

install-bin: all $(SCRIPTS)
	@$(VECHO) INSTALL-BIN
	$(INSTALL) -d $(DESTDIR)$(BINDIR)
	$(INSTALL_PROGRAM) $(BIN) $(DESTDIR)$(BINDIR)
	$(INSTALL_SCRIPT) $(SCRIPTS) $(DESTDIR)$(BINDIR)

install-lib: all
	@$(VECHO) INSTALL-LIB
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	$(INSTALL_LIB) $(LIBFDT_lib) $(DESTDIR)$(LIBDIR)
	ln -sf $(notdir $(LIBFDT_lib)) $(DESTDIR)$(LIBDIR)/$(LIBFDT_soname)
	ln -sf $(LIBFDT_soname) $(DESTDIR)$(LIBDIR)/libfdt.$(SHAREDLIB_EXT)
	$(INSTALL_DATA) $(LIBFDT_archive) $(DESTDIR)$(LIBDIR)

install-includes:
	@$(VECHO) INSTALL-INC
	$(INSTALL) -d $(DESTDIR)$(INCLUDEDIR)
	$(INSTALL_DATA) $(LIBFDT_include) $(DESTDIR)$(INCLUDEDIR)

install: install-bin install-lib install-includes

$(VERSION_FILE): Makefile FORCE
	$(call filechk,version)


dtc: $(DTC_OBJS)

convert-dtsv0: $(CONVERT_OBJS)
	@$(VECHO) LD $@
	$(LINK.c) -o $@ $^

fdtdump:	$(FDTDUMP_OBJS)

fdtget:	$(FDTGET_OBJS) $(LIBFDT_dep)

fdtput:	$(FDTPUT_OBJS) $(LIBFDT_dep)

fdtoverlay: $(FDTOVERLAY_OBJS) $(LIBFDT_dep)

dist:
	git archive --format=tar --prefix=dtc-$(FDT_TOOLS_VERSION)/ HEAD \
		> ../dtc-$(FDT_TOOLS_VERSION).tar
	cat ../dtc-$(FDT_TOOLS_VERSION).tar | \
		gzip -9 > ../dtc-$(FDT_TOOLS_VERSION).tar.gz


#
# Release signing and uploading
# This is for maintainer convenience, don't try this at home.
#
ifeq ($(MAINTAINER),y)
GPG = gpg2
KUP = kup
KUPDIR = /pub/software/utils/dtc

kup: dist
	$(GPG) --detach-sign --armor -o ../dtc-$(FDT_TOOLS_VERSION).tar.sign \
		../dtc-$(FDT_TOOLS_VERSION).tar
	$(KUP) put ../dtc-$(FDT_TOOLS_VERSION).tar.gz ../dtc-$(FDT_TOOLS_VERSION).tar.sign \
		$(KUPDIR)/dtc-$(FDT_TOOLS_VERSION).tar.gz
endif

tags: FORCE
	rm -f tags
	find . \( -name tests -type d -prune \) -o \
	       \( ! -name '*.tab.[ch]' ! -name '*.lex.c' \
	       -name '*.[chly]' -type f -print \) | xargs ctags -a

#
# Testsuite rules
#
TESTS_PREFIX=tests/

TESTS_BIN += fdtgrep

ifneq ($(MAKECMDGOALS),libfdt)
include tests/Makefile.tests
endif

#
# Clean rules
#
STD_CLEANFILES = *~ *.o *.$(SHAREDLIB_EXT) *.d *.a *.i *.s core a.out vgcore.* \
	*.tab.[ch] *.lex.c *.output

clean: tests_clean
	@$(VECHO) CLEAN
	rm -f $(STD_CLEANFILES)
	rm -f $(VERSION_FILE)
	rm -f $(BIN)
	rm -f dtc-*.tar dtc-*.tar.sign dtc-*.tar.asc

#
# Generic compile rules
#
%: %.o
	@$(VECHO) LD $@
	$(LINK.c) -o $@ $^ $(LDLIBS_$*)

%.o: %.c
	@$(VECHO) CC $@
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ -c $<

%.o: %.S
	@$(VECHO) AS $@
	$(CC) $(CPPFLAGS) $(AFLAGS) -D__ASSEMBLY__ -o $@ -c $<

%.d: %.c
	@$(VECHO) DEP $<
	$(CC) $(CPPFLAGS) $(CFLAGS) -MM -MG -MT "$*.o $@" $< > $@

%.d: %.S
	@$(VECHO) DEP $<
	$(CC) $(CPPFLAGS) -MM -MG -MT "$*.o $@" $< > $@

%.i:	%.c
	@$(VECHO) CPP $@
	$(CC) $(CPPFLAGS) -E $< > $@

%.s:	%.c
	@$(VECHO) CC -S $@
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ -S $<

%.dtb:	%.dts
	@$(VECHO) dtc $@
	dtc $< -o $@

FORCE:

ifeq ($(MAKE_RESTARTS),10)
$(error "Make re-executed itself $(MAKE_RESTARTS) times. Infinite recursion?")
endif

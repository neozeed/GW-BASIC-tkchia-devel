#	Permission is hereby granted, free of charge, to any person
#	obtaining a copy of this software and associated documentation files
#	(the "Software"), to deal in the Software without restriction,
#	including without limitation the rights to use, copy, modify, merge,
#	publish, distribute, sublicense, and/or sell copies of the Software,
#	and to permit persons to whom the Software is furnished to do so,
#	subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be
#	included in all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#	NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
#	BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
#	ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#	SOFTWARE.

# Use a date as a version indicator.  If this is a Git tree and there are no
# working tree changes, take the date in the Git index.  Otherwise, use the
# current date.
OEMVER := $(shell \
		if git diff --quiet HEAD; then \
			TZ=UTC0 git log -n1 --oneline --date=short-local \
				--format='%ad'; \
		else \
			TZ=UTC0 date '+%Y-%m-%d'; \
		fi)
# An abbreviated version of the date as a version indicator.
SHORTVER := $(shell \
		  echo '$(OEMVER)' | sed -e 's/^..//' -e 's/-0\(.\)-/\1/' \
					 -e 's/-10-/A/' -e 's/-11-/B/' \
					 -e 's/-12-/C/')

SRCS =	GWDATA.ASM ADVGRP.ASM BIMISC.ASM BIPRTU.ASM BIPTRG.ASM \
	BISTRS.ASM CALL86.ASM DSKCOM.ASM FIVEO.ASM GENGRP.ASM GIO86.ASM \
	GIOCAS.ASM GIOCOM.ASM GIOCON.ASM GIODSK.ASM GIOKYB.ASM GIOLPT.ASM \
	GIOSCN.ASM GIOTBL.ASM GWEVAL.ASM GWLIST.ASM GWMAIN.ASM GWRAM.ASM \
	GWSTS.ASM IBMRES.ASM KANJ86.ASM MACLNG.ASM MATH.ASM NEXT86.ASM \
	SCNDRV.ASM SCNEDT.ASM OEM.ASM OEMCBK.ASM OEMEV.ASM OEMSND.ASM \
	ITSA86.ASM GWINIT.ASM BIBOOT.ASM
INCS =	BINTRP.H IBMRES.H OEM.H GIO86U MSDOSU
OBJS =	$(SRCS:.ASM=.OBJ)

ASRCS =	update/GWDATA.ASM ADVGRP.ASM BIMISC.ASM BIPRTU.ASM BIPTRG.ASM \
	BISTRS.ASM CALL86.ASM DSKCOM.ASM FIVEO.ASM GENGRP.ASM \
	update/GIO86.ASM GIOCAS.ASM GIOCOM.ASM GIOCON.ASM update/GIODSK.ASM \
	update/GIODSX.ASM GIOKYB.ASM GIOLPT.ASM GIOSCN.ASM GIOTBL.ASM \
	GWEVAL.ASM GWLIST.ASM update/GWMAIN.ASM GWRAM.ASM update/GWSTS.ASM \
	update/IBMRES.ASM KANJ86.ASM MACLNG.ASM MATH.ASM NEXT86.ASM \
	SCNDRV.ASM SCNEDT.ASM update/OEMA.ASM OEMCBK.ASM OEMEV.ASM OEMSND.ASM \
	ITSA86.ASM update/GWINIT.ASM update/LSTVAR.ASM
AINCS =	$(INCS) update/MSDOS2U
AOBJS =	$(ASRCS:.ASM=.OBJ)

DEPS = $(sort $(INCS) $(AINCS))
# If we already have JWasm &/or JWlink installed, use those.  Otherwise
# optionally download & build JWasm &/or JWlink.
TAR = tar
GIT = git
ifneq "" "$(shell jwasm '-?' 2>/dev/null)"
    ASM = jwasm
else
    ASM = ./jwasm
    DEPS += $(ASM)
endif
ifneq "" "$(shell jwlink '-?' 2>/dev/null)"
    LINK = jwlink
else
    LINK = ./jwlink
    DEPS += $(LINK)
endif
RM = rm -f

default: GWBASIC.EXE GWBASICA.EXE
.PHONY: default

clean: mostlyclean
	$(RM) -r JWasm.build JWlink.build jwasm jwlink
.PHONY: clean

mostlyclean:
	$(RM) -r *.OBJ GWBASIC.EXE GWBASICA.EXE *.MAP *.TMP *.ERR *.ZIP *~ \
		 update/*.OBJ update/*.TMP update/*.ERR update/*~
.PHONY: mostlyclean

rel: default
	$(RM) -r GWB*.ZIP GWB*.TMP
	mkdir -p GWB$(SHORTVER).TMP/DEVEL/GWBASIC
	cp GWBASIC.EXE GWBASICA.EXE GWB$(SHORTVER).TMP/DEVEL/GWBASIC
	cd GWB$(SHORTVER).TMP && TZ=UTC0 zip -9rkX ../GWB$(SHORTVER).ZIP DEVEL
	$(RM) -r GWB$(SHORTVER).TMP
.PHONY: rel

GWBASIC.EXE: $(OBJS)
	$(LINK) format dos $(+:%=file %) name $@ option dosseg,map=GWBASIC.MAP

GWBASICA.EXE: $(AOBJS)
	$(LINK) format dos $(+:%=file %) name $@ option dosseg,map=GWBASICA.MAP

# For OEM.OBJ, also rope in the other source files --- including this
# makefile --- as dependencies.  This tries to ensure that the version
# information will be updated correctly when any of the other files are
# updated.
OEM.OBJ: OEM.ASM jwasmify.awk $(SRCS) $(DEPS) $(lastword $(MAKEFILE_LIST))
	$(RM) $(@:.OBJ=.ERR)
	awk -f ./jwasmify.awk $< >$(@:.OBJ=.TMP)
	$(ASM) -Zm -fpc -DOEMVER='$(OEMVER)' -Fo$@ -Fw$(@:.OBJ=.ERR) \
	    $(@:.OBJ=.TMP)
	$(RM) $(@:.OBJ=.TMP)

# The "advanced" update/OEMA.OBJ is built similarly as OEM.OBJ, but it uses
# a different version number.
update/OEMA.OBJ: update/OEMA.ASM jwasmify.awk $(ASRCS) $(SRCS) $(DEPS) \
		 $(lastword $(MAKEFILE_LIST))
	$(RM) $(@:.OBJ=.ERR)
	awk -f ./jwasmify.awk $< >$(@:.OBJ=.TMP)
	$(ASM) -Zm -fpc -DOEMVER='A$(OEMVER)' -Fo$@ -Fw$(@:.OBJ=.ERR) \
	    $(@:.OBJ=.TMP)
	$(RM) $(@:.OBJ=.TMP)

%.OBJ: %.ASM jwasmify.awk $(DEPS)
	$(RM) $(@:.OBJ=.ERR)
	awk -f ./jwasmify.awk $< >$(@:.OBJ=.TMP)
	$(ASM) -Zm -fpc -Fo$@ -Fw$(@:.OBJ=.ERR) $(@:.OBJ=.TMP)
	$(RM) $(@:.OBJ=.TMP)

MATH.ASM: MATH1.ASM MATH2.ASM
	cat $^ >$@

./jwasm: $(wildcard JWasm.shallow.tar.xz)
	$(RM) -r JWasm.build
	set -e; \
	if test -n '$<'; then \
		mkdir JWasm.build; \
		$(TAR) -x -v -f '$<' -C JWasm.build --strip-components 1; \
	else \
		$(GIT) clone https://github.com/Baron-von-Riedesel/JWasm.git \
		    JWasm.build; \
	fi
	$(MAKE) -C JWasm.build -f GccUnix.mak
	cp JWasm.build/build/GccUnixR/jwasm $@.tmp
	mv $@.tmp $@

./jwlink: $(wildcard JWlink.shallow.tar.xz)
	$(RM) -r JWlink.build
	set -e; \
	if test -n '$<'; then \
		mkdir JWlink.build; \
		$(TAR) -x -v -f '$<' -C JWlink.build --strip-components 1; \
	else \
		$(GIT) clone https://github.com/JWasm/JWlink.git \
			     JWlink.build; \
	fi
	$(MAKE) -C JWlink.build/dwarf/dw -f GccUnix.mak
	$(MAKE) -C JWlink.build/orl -f GccUnix.mak
	$(MAKE) -C JWlink.build/sdk/rc/wres -f GccUnix.mak
	$(MAKE) -C JWlink.build -f GccUnix.mak
	cp JWlink.build/GccUnixR/jwlink $@.tmp
	mv $@.tmp $@

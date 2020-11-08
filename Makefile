ASM = jwasm
LINK = jwlink
RM = rm -f

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

SRCS =	GWDATA.ASM ADVGRP.ASM BIMISC.ASM BIPRTU.ASM BIPTRG.ASM \
	BISTRS.ASM CALL86.ASM DSKCOM.ASM FIVEO.ASM GENGRP.ASM GIO86.ASM \
	GIOCAS.ASM GIOCOM.ASM GIOCON.ASM GIODSK.ASM GIOKYB.ASM GIOLPT.ASM \
	GIOSCN.ASM GIOTBL.ASM GWEVAL.ASM GWLIST.ASM GWMAIN.ASM GWRAM.ASM \
	GWSTS.ASM IBMRES.ASM KANJ86.ASM MACLNG.ASM MATH.ASM NEXT86.ASM \
	SCNDRV.ASM SCNEDT.ASM OEM.ASM OEMEV.ASM OEMSND.ASM \
	ITSA86.ASM GWINIT.ASM BIBOOT.ASM
INCS =	BINTRP.H IBMRES.H OEM.H GIO86U MSDOSU
OBJS =	$(SRCS:.ASM=.OBJ)

ASRCS =	GWDATA.ASM ADVGRP.ASM BIMISC.ASM BIPRTU.ASM BIPTRG.ASM \
	BISTRS.ASM CALL86.ASM DSKCOM.ASM FIVEO.ASM GENGRP.ASM GIO86.ASM \
	GIOCAS.ASM GIOCOM.ASM GIOCON.ASM GIODSK.ASM GIOKYB.ASM GIOLPT.ASM \
	GIOSCN.ASM GIOTBL.ASM GWEVAL.ASM GWLIST.ASM update/GWMAIN.ASM \
	GWRAM.ASM update/GWSTS.ASM update/IBMRES.ASM KANJ86.ASM MACLNG.ASM \
	MATH.ASM NEXT86.ASM SCNDRV.ASM SCNEDT.ASM update/OEMA.ASM OEMEV.ASM \
	OEMSND.ASM ITSA86.ASM GWINIT.ASM BIBOOT.ASM
AOBJS =	$(ASRCS:.ASM=.OBJ)

default: GWBASIC.EXE GWBASICA.EXE

clean:
	$(RM) *.OBJ GWBASIC.EXE GWBASICA.EXE *.MAP *.TMP *.ERR *~ \
	      update/*.OBJ update/*.TMP update/*.ERR update/*~

GWBASIC.EXE: $(OBJS)
	$(LINK) format dos $(+:%=file %) name $@ option dosseg,map=GWBASIC.MAP

GWBASICA.EXE: $(AOBJS)
	$(LINK) format dos $(+:%=file %) name $@ option dosseg,map=GWBASICA.MAP

# For OEM.OBJ, also rope in the other source files --- including this
# makefile --- as dependencies.  This tries to ensure that the version
# information will be updated correctly when any of the other files are
# updated.
OEM.OBJ: OEM.ASM jwasmify.awk $(SRCS) $(INCS) $(lastword $(MAKEFILE_LIST))
	$(RM) $(@:.OBJ=.ERR)
	awk -f ./jwasmify.awk $< >$(@:.OBJ=.TMP)
	$(ASM) -Zm -fpc -DOEMVER='$(OEMVER)' -Fo$@ -Fw$(@:.OBJ=.ERR) \
	    $(@:.OBJ=.TMP)
	$(RM) $(@:.OBJ=.TMP)

# The "advanced" update/OEMA.OBJ is built similarly as OEM.OBJ, but it uses
# a different version number.
update/OEMA.OBJ: update/OEMA.ASM jwasmify.awk $(ASRCS) $(SRCS) $(INCS) \
		  $(lastword $(MAKEFILE_LIST))
	$(RM) $(@:.OBJ=.ERR)
	awk -f ./jwasmify.awk $< >$(@:.OBJ=.TMP)
	$(ASM) -Zm -fpc -DOEMVER='A$(OEMVER)' -Fo$@ -Fw$(@:.OBJ=.ERR) \
	    $(@:.OBJ=.TMP)
	$(RM) $(@:.OBJ=.TMP)

%.OBJ: %.ASM jwasmify.awk $(INCS)
	$(RM) $(@:.OBJ=.ERR)
	awk -f ./jwasmify.awk $< >$(@:.OBJ=.TMP)
	$(ASM) -Zm -fpc -Fo$@ -Fw$(@:.OBJ=.ERR) $(@:.OBJ=.TMP)
	$(RM) $(@:.OBJ=.TMP)

MATH.ASM: MATH1.ASM MATH2.ASM
	cat $^ >$@

.PHONY: default clean

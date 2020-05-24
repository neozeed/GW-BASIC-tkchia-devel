	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   OEM - Vendor provided code

COMMENT *
Written by:     Stjepan Gros <stjepan.gros@gmail.com>

A lot of screen related rutines use INT 10H services, so much of
data can be inferred by reading documentation for INT 10H.
        *
	.SALL

;; Text screen group of subroutines

; OEM supplied Clear-Screen Routine
PUBLIC	CLRSCN
CLRSCN:
	RET

; OEM supplied screen clear to end of line
; Clear from (DH,DL) to EOL (from GWSTS.ASM)
PUBLIC	CLREOL
CLREOL:
	RET

; OEM supplied SCROLL routine
;
; INPUT
;	AX
; OUTPUT
;
; REGISTERS AFFECTED
;
PUBLIC	SCROLL
SCROLL:			;Dummy function
	RET

; OEM supplied screen input(read character)
;
; INPUT
;	DH,DL		Coordinates, DH->Row, DL->Column
;	CF=0		Indicates call is from Screen Editor
; OUTPUT
;	X=Character at (DH,DL)
; REGISTERS AFFECTED

PUBLIC	SCRINP
SCRINP:			;Dummy function
	RET


; OEM supplied character output
;
; INPUT
;	AL		Character to output
;	DH, DL		Position
; OUTPUT
;
; REGISTERS AFFECTED
;
PUBLIC	SCROUT
SCROUT:
        POP     BX
        RET

PUBLIC	STOREC
STOREC:			;Dummy function
	RET

;Let screen editor set width
;pass Width in AL
;pass Height in CL

PUBLIC	SWIDTH
SWIDTH:			;Dummy function
	RET

PUBLIC	NREAD
NREAD:			;Dummy function
	RET

PUBLIC	RDTRIG
RDTRIG:			;Dummy function
	RET

PUBLIC	NSETCX
NSETCX:			;Dummy function
	RET

PUBLIC	EDTMAP
EDTMAP:			;Dummy function
	RET

PUBLIC	DONOTE
DONOTE:			;Dummy function
	RET

PUBLIC	SNDLPT
SNDLPT:			;Dummy function
	RET

PUBLIC	PEKFLT
PEKFLT:			;Dummy function
	RET

PUBLIC	SETCBF
SETCBF:			;Dummy function
	RET

PUBLIC	LEFTC
LEFTC:			;Dummy function
	RET

PUBLIC	PGINIT
PGINIT:			;Dummy function
	RET

PUBLIC	MAPXYC
MAPXYC:			;Dummy function
	RET

PUBLIC	INKMAP
INKMAP:			;Dummy function
	RET

PUBLIC	SETFBC
SETFBC:			;Dummy function
	RET

PUBLIC	TDOWNC
TDOWNC:			;Dummy function
	RET

PUBLIC	SCANR
SCANR:			;Dummy function
	RET

PUBLIC	INICOM
INICOM:			;Dummy function
	RET

PUBLIC	GETHED
GETHED:			;Dummy function
	RET

PUBLIC	UPC
UPC:			;Dummy function
	RET

PUBLIC	SCANL
SCANL:			;Dummy function
	RET

PUBLIC	FETCHC
FETCHC:			;Dummy function
	RET

PUBLIC	SCALXY
SCALXY:			;Dummy function
	RET

PUBLIC	GETFBC
GETFBC:			;Dummy function
	RET

PUBLIC	SNDCOM
SNDCOM:			;Dummy function
	RET

PUBLIC	STACOM
STACOM:			;Dummy function
	RET

PUBLIC	READC
READC:			;Dummy function
	RET

PUBLIC	INFMAP
INFMAP:			;Dummy function
	RET

PUBLIC	TUPC
TUPC:			;Dummy function
	RET

PUBLIC	RIGHTC
RIGHTC:			;Dummy function
	RET

PUBLIC	SEGINI
SEGINI:			;Dummy function
	RET

PUBLIC	GTASPC
GTASPC:			;Dummy function
	RET

PUBLIC	RECCOM
RECCOM:			;Dummy function
	RET

PUBLIC	SETC
SETC:			;Dummy function
	RET

PUBLIC	PIXSIZ
PIXSIZ:			;Dummy function
	RET

PUBLIC	DOWNC
DOWNC:			;Dummy function
	RET

PUBLIC	LCPY
LCPY:			;Dummy function
	RET

PUBLIC	FKYFMT
FKYFMT:			;Dummy function
	RET

;Do OEM specific termination processing (from GIODSK.ASM)
PUBLIC	GWTERM
GWTERM:			;Dummy function
	RET

PUBLIC	GRPSIZ
GRPSIZ:			;Dummy function
	RET

PUBLIC	FKYADV
FKYADV:			;Dummy function
	RET

;
; RETURN
;	ZF=0 no key available
;	[AX]=next key from keyboard if one exists
PUBLIC	KEYINP
KEYINP:			;Dummy function
	RET

PUBLIC	PRTMAP
PRTMAP:			;Dummy function
	RET

PUBLIC	RDPEN
RDPEN:			;Dummy function
	RET

PUBLIC	CSRATR
CSRATR:			;Dummy function
	RET

PUBLIC	GWINI
GWINI:			;Dummy function
	RET

PUBLIC	NWRITE
NWRITE:			;Dummy function
	RET

PUBLIC	SCRSTT
SCRSTT:			;Dummy function
	RET

PUBLIC	CSRDSP
CSRDSP:
	RET

PUBLIC	SETATR
SETATR:			;Dummy function
	RET

PUBLIC	PNTINI
PNTINI:			;Dummy function
	RET

PUBLIC	SETCLR
SETCLR:			;Dummy function
	RET

PUBLIC	SCRATR
SCRATR:			;Dummy function
	RET

PUBLIC	TRMCOM
TRMCOM:			;Dummy function
	RET

PUBLIC	POLLEV
POLLEV:			;Dummy function
	RET

PUBLIC	POKFLT
POKFLT:			;Dummy function
	RET

PUBLIC	RDSTIK
RDSTIK:			;Dummy function
	RET

PUBLIC	MAPSUP
MAPSUP:			;Dummy function
	RET


CSEG	ENDS
	END


CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG,DS:DSEG

INCLUDE	OEM.H

	TITLE   OEM - Vendor provided code

COMMENT *
Written by:     Stjepan Gros <stjepan.gros@gmail.com>

A lot of screen related rutines use INT 10H services, so much of
data can be inferred by reading documentation for INT 10H.

Some routines written or disassembled by: TK Chia <https://github.com/tkchia>

Many of the routines missing from the GW-BASIC code release are
present in Microsoft's previous release of MS-DOS v1.25 BASICA.COM
(https://github.com/microsoft/MS-DOS/tree/master/v1.25/bin),
though only in binary form.  These are indicated.
        *
	.SALL

	EXTRN	SCNSWI:NEAR,SCNCLR:NEAR,SCNTRM:NEAR

;; Text screen group of subroutines

; OEM supplied Clear-Screen Routine
;
; INPUT
;	AL		Per argument supplied to CLS command, i.e.
;			0 Clear everything
;			1 Clear graphics viewport (not in this version)
;			2 Clear text window
;
PUBLIC	CLRSCN
CLRSCN:	CMP	AL,2
	JZ	CLRWDO
	MOV	CH,WDOTOP
	MOV	CL,WDOLFT
	SUB	CX,0101H
	MOV	DH,WDOBOT
	MOV	DL,WDORGT
	JMP	SHORT CLRALL
CLRWDO:	XOR	CX,CX
	MOV	DH,LINCNT
	MOV	DL,CRTWID
CLRALL:	SUB	DX,0101H
	CALL	FILATR
	MOV	BH,AL
	MOV	AX,0600H
	INT	10H
	JMP	SCNCLR

; Internal routine: return in AL the screen attribute to use for INT 10H
; text blanking operations
;
FILATR:	PUSH	CX
	MOV	AL,1
	MOV	CL,CRTMOD
	SHL	AL,CL
	TEST	AL,01110000B
	MOV	AL,TXTATR
	JZ	FILAT2
	MOV	CL,4
	SHR	AL,CL
FILAT2:	POP	CX
	RET

; OEM supplied screen clear to end of line
; Clear from (DH,DL) to EOL (from GWSTS.ASM)
PUBLIC	CLREOL
CLREOL:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	XCHG	DH,DL
	SUB	DX,0101H
	MOV	CX,DX
	MOV	DL,CRTWID
	DEC	DX
	CALL	FILATR
	MOV	BH,AL
	MOV	AX,0600H
	INT	10H
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET

; OEM supplied SCROLL routine
; Does not blank out parts of screen that are not scrolled into
;
; INPUT
;	AX		(AH, AL) = Top left corner (column, row) of source
;				   region
;	BX		(BH, BL) = Top left corner of destination region
;	CX		(CH, CL) = Dimensions of area to move
; OUTPUT
;
; REGISTERS AFFECTED
;
PUBLIC	SCROLL
SCROLL:	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	BP
	PUSH	DS
	PUSH	ES
	PUSHF
	PUSH	AX
	MOV	DL,CRTMOD
	XOR	DH,DH
	MOV	SI,DX
	SHL	DX,1
	SHL	DX,1
	ADD	DX,SI
	MOV	BP,DX
	ADD	BP,OFFSET CSEG:SCLTAB
	MOV	DX,AX
	CLC
	CALL	POSOFF
	MOV	SI,DX			; SI = starting source offset
	MOV	DX,BX
	CLC
	CALL	POSOFF
	MOV	DI,DX			; DI = starting destination offset
	XOR	AH,AH
	PUSH	CX
	MOV	AL,CH
	XOR	AH,AH
	MOV	CL,CS:3[BP]
	SHL	AX,CL			; AX = bytes to move per graphics row
	POP	CX
	MOV	DL,CS:2[BP]
	XOR	DH,DH			; DX = how much SI and DI should
	SUB	DX,AX			; skip after each row
	CLD
	CMP	SI,DI
	JNB	SCLFWD
	POP	SI			; If moving backwards, recompute
	PUSH	SI			; SI, DI, and DX...
	PUSH	DX
	MOV	DX,SI
	ADD	DX,CX
	SUB	DX,0101H
	STC
	CALL	POSOFF
	MOV	SI,DX
	MOV	DX,BX
	ADD	DX,CX
	SUB	DX,0101H
	STC
	CALL	POSOFF
	MOV	DI,DX
	POP	DX
	NEG	DX
	STD
SCLFWD:	MOV	BL,CL
	XOR	BH,BH
	MOV	CL,CS:4[BP]
	SHL	BX,CL			; BX = count of graphics rows to move
	MOV	CH,CS:0[BP]		; Now move even-numbered graphics rows
	XOR	CL,CL
	MOV	DS,CX
	MOV	ES,CX
	PUSH	SI
	PUSH	DI
	PUSH	BX
SCLOT1:	MOV	CX,AX
 REP	MOVSB
	ADD	SI,DX
	ADD	DI,DX
	DEC	BX
	JNZ	SCLOT1
	POP	BX
	POP	DI
	POP	SI
	MOV	CH,CS:1[BP]		; Move odd-numbered graphics rows if
	JCXZ	SCLFIN			; applicable
	MOV	DS,CX
	MOV	ES,CX
SCLOT2:	MOV	CX,AX
 REP	MOVSB
	ADD	SI,DX
	ADD	DI,DX
	DEC	BX
	JNZ	SCLOT2
SCLFIN:	POP	AX
	POPF
	POP	ES
	POP	DS
	POP	BP
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	RET

; Internal data structure: information for scrolling a portion of the screen,
; used by SCROLL
;
SCLTAB	LABEL	BYTE		; For INT 10H video mode 0:
	DB	0B8H		; * high byte of video memory address, for
				;   even-numbered graphics rows
	DB	0		; * high byte of video memory address, for
				;   odd-numbered graphics rows, or 0 if
				;   video is not interlaced
	DB	80D		; * number of bytes per graphics row
	DB	1		; * shift for number of bytes per text column
	DB	0		; * shift for number of graphics rows per
				;   text row
	DB	0B8H,0,80D,1,0		; For mode 1
	DB	0B8H,0,160D,1,0		; For mode 2
	DB	0B8H,0,160D,1,0		; For mode 3
	DB	0B8H,0BAH,80D,1,2	; For mode 4
	DB	0B8H,0BAH,80D,1,2	; For mode 5
	DB	0B8H,0BAH,80D,0,2	; For mode 6
	DB	0B8H,0,80D,1,0		; For mode 7

; Internal function: convert a text (column, row), in the active display
; page, to an offset into video memory
;
; INPUT
;	CS:[BP]		SCLTAB element for current video mode
;	DX		(DH, DL) = (column, row)
;	FLAGS		CF=0 Return offset of first byte
;			CF=1 Return offset of last byte
;
; OUTPUT
;	DX		Offset into video memory
;
POSOFF:	PUSH	AX
	PUSH	CX
	PUSH	ES
	PUSHF
	SUB	DX,0101H
	XCHG	DH,DL
	MOV	AL,CS:2[BP]
	MUL	DH
	MOV	CL,CS:4[BP]
	SHL	AX,CL
	XOR	DH,DH
	MOV	CL,CS:3[BP]
	SHL	DX,CL
	ADD	DX,AX
	XOR	CX,CX			; Remember to add the page offset...
	MOV	ES,CX
	ADD	DX,ES:044EH
	POPF
	JNC	POSOF2
	MOV	AL,CS:2[BP]
	XOR	AH,AH
	MOV	CL,CS:4[BP]
	SHL	AX,CL
	SUB	AL,CS:2[BP]
	SBB	AH,0
	ADD	DX,AX
	MOV	AX,1
	MOV	CL,CS:3[BP]
	SHL	AX,CL
	DEC	AX
	ADD	DX,AX
POSOF2:	POP	ES
	POP	CX
	POP	AX
	RET

; OEM supplied screen input(read character)
;
; INPUT
;	DH,DL		Coordinates, DH->Column, DL->Row
;	CF=0		Indicates call is from Screen Editor
; OUTPUT
;	X=Character at (DH,DL)
; REGISTERS AFFECTED

PUBLIC	SCRINP
SCRINP:	CALL	CSRHAK
	PUSH	BX
	MOV	AH,08H
	MOV	BH,ACTPAG
	INT	10H
	XOR	AH,AH
	TEST	AL,AL
	JNZ	SCRIN2
	MOV	AL," "
SCRIN2:	POP	BX
	RET

; OEM supplied character output
;
; INPUT
;	AL		Character to output
;	DH, DL		Position
; OUTPUT
;	FLAGS		CF=1 if inside escape sequence (?)
;			CF=0 otherwise
;
; REGISTERS AFFECTED
;
PUBLIC	SCROUT
SCROUT:	PUSH	DX
	PUSH	CX
	PUSH	BX
	PUSH	AX
	CALL	CSRHAK
	MOV	CX,1
	MOV	BH,ACTPAG
	MOV	BL,TXTATR
	MOV	AH,09H
	INT	10H
	POP	AX
	POP	BX
	POP	CX
	POP	DX
	CLC
	RET

; Internal function: pretend to the BIOS that the text output cursor is at
; (DH, DL), but without actually moving the hardware cursor
;
CSRHAK:	PUSH	BX
	PUSH	DX
	PUSH	ES
	XOR	BX,BX
	MOV	ES,BX
	MOV	BL,ACTPAG
	SHR	BX,1
	XCHG	DH,DL
	SUB	DX,0101H
	MOV	ES:0450H[BX],DX
	POP	ES
	POP	DX
	POP	BX
	RET

PUBLIC	STOREC
STOREC:			;Dummy function
	INT	3
	RET
	DB	"STOREC"

;Let screen editor set width
;pass Width in AL
;pass Height in CL

PUBLIC	SWIDTH
SWIDTH:			;Dummy function
	INT	3
	RET
	DB	"SWIDTH"

PUBLIC	NREAD
NREAD:			;Dummy function
	INT	3
	RET
	DB	"NREAD"

PUBLIC	RDTRIG
RDTRIG:			;Dummy function
	INT	3
	RET
	DB	"RDTRIG"

PUBLIC	NSETCX
NSETCX:			;Dummy function
	INT	3
	RET
	DB	"NSETCX"

PUBLIC	DONOTE
DONOTE:			;Dummy function
	INT	3
	RET
	DB	"DONOTE"

PUBLIC	SNDLPT
SNDLPT:			;Dummy function
	INT	3
	RET
	DB	"SNDLPT"

PUBLIC	PEKFLT
PEKFLT:			;Dummy function
	INT	3
	RET
	DB	"PEKFLT"

; Set serial port (COM1, COM2, etc.) buffer location and size
;
; INPUT
;	CX		Segment for COM buffer
;	AL		Character to output
;	DH, DL		Position
; OUTPUT
;	FLAGS		CF=0 OK
;			CF=1 Out of memory
;
; REGISTERS AFFECTED
;
PUBLIC	SETCBF
SETCBF:	JNZ	CBSPEC			; If no buffer size given, use a
	MOV	DX,100H			; default size
CBSPEC:	MOV	CBFSEG,CX		; Record the COM buffer location
	CLC				;
	RET

PUBLIC	LEFTC
LEFTC:			;Dummy function
	INT	3
	RET
	DB	"LEFTC"

PUBLIC	PGINIT
PGINIT:			;Dummy function
	INT	3
	RET
	DB	"PGINIT"

PUBLIC	MAPXYC
MAPXYC:			;Dummy function
	INT	3
	RET
	DB	"MAPXYC"

PUBLIC	INKMAP
INKMAP:			;Dummy function
	INT	3
	RET
	DB	"INKMAP"

; Set foreground and background colours for text or graphics operations
;
; INPUT
;	FLAGS		CF=0 Text colours
;			CF=1 Graphics colours
;	AL		Foreground colour
;	BL		Background colour
;
PUBLIC	SETFBC
SETFBC:	JC	SETFBG
	PUSH	AX
	PUSH	BX
	PUSH	CX
	MOV	CL,4
	SHL	BL,CL
	OR	AL,BL
	MOV	TXTATR,AL
	POP	CX
	POP	BX
	POP	AX
	RET
SETFBG:	MOV	GRPFGC,AL
	MOV	GRPBGC,BL
	RET

PUBLIC	TDOWNC
TDOWNC:			;Dummy function
	INT	3
	RET
	DB	"TDOWNC"

PUBLIC	SCANR
SCANR:			;Dummy function
	INT	3
	RET
	DB	"SCANR"

PUBLIC	INICOM
INICOM:			;Dummy function
	INT	3
	RET
	DB	"INICOM"

; Get OEM specific portion of splash header
;
; INPUT
;
; OUTPUT
;	CS:[BX]		OEM header
;	FLAGS		ZF=1 Only print OEM header for interactive session
;			ZF=0 Always print OEM header
;
PUBLIC	GETHED
GETHED:
	MOV	BX,OFFSET CSEG:OEMHED
	CMP	BX,BX
	RET
OEMHED:	DB	"GW-BASIC",0

PUBLIC	UPC
UPC:			;Dummy function
	INT	3
	RET
	DB	"UPC"

PUBLIC	SCANL
SCANL:			;Dummy function
	INT	3
	RET
	DB	"SCANL"

PUBLIC	FETCHC
FETCHC:			;Dummy function
	INT	3
	RET
	DB	"FETCHC"

PUBLIC	SCALXY
SCALXY:			;Dummy function
	INT	3
	RET
	DB	"SCALXY"

; Get current foreground and background colours for text or graphics
; operations
;
; INPUT
;	FLAGS		CF=0 Text colours
;			CF=1 Graphics colours
; OUTPUT
;	AL		Foreground colour
;	BL		Background colour
;
PUBLIC	GETFBC
GETFBC:	JC	GETFBG
	PUSH	CX
	MOV	AL,TXTATR
	MOV	BL,AL
	MOV	CL,4
	SHR	BL,CL
	AND	AL,0FH
	POP	CX
	RET
GETFBG:	MOV	AL,GRPFGC
	MOV	BL,GRPBGC
	RET

PUBLIC	SNDCOM
SNDCOM:			;Dummy function
	INT	3
	RET
	DB	"SNDCOM"

PUBLIC	STACOM
STACOM:			;Dummy function
	INT	3
	RET
	DB	"STACOM"

PUBLIC	READC
READC:			;Dummy function
	INT	3
	RET
	DB	"READC"

PUBLIC	INFMAP
INFMAP:			;Dummy function
	INT	3
	RET
	DB	"INFMAP"

PUBLIC	TUPC
TUPC:			;Dummy function
	INT	3
	RET
	DB	"TUPC"

PUBLIC	RIGHTC
RIGHTC:			;Dummy function
	INT	3
	RET
	DB	"RIGHTC"

PUBLIC	SEGINI
SEGINI:			;Dummy function
	INT	3
	RET
	DB	"SEGINI"

PUBLIC	GTASPC
GTASPC:			;Dummy function
	INT	3
	RET
	DB	"GTASPC"

PUBLIC	RECCOM
RECCOM:			;Dummy function
	INT	3
	RET
	DB	"RECCOM"

; From BASICA.COM CSEG:2279H
; Sets a pixel on the screen to the current colour
; The desired pixel location and colour should be set first
; using MAPXYC and SETATR
;
; INPUT
;
; OUTPUT
;
; REGISTERS AFFECTED
;	AX, BX, SI, DI
;
PUBLIC	SETC
SETC:	MOV	SI,ES
	MOV	DI,0B800H
	MOV	ES,DI
	MOV	BX,PIXOFS
	MOV	AL,ES:[BX]
	XOR	AL,ATRPAT
	AND	AL,ATRMSK
	XOR	ES:[BX],AL
	MOV	ES,SI
	RET

; From BASICA.COM CSEG:234DH
; Return number of bits per graphics pixel, or 0 if
; graphics not supported for current screen mode
;
; INPUT
;
; OUTPUT
;	AL		bits per pixel
;
PUBLIC	PIXSIZ
PIXSIZ:	MOV	AL,PIXBTS
	RET

PUBLIC	DOWNC
DOWNC:			;Dummy function
	INT	3
	RET
	DB	"DOWNC"

PUBLIC	LCPY
LCPY:			;Dummy function
	INT	3
	RET
	DB	"LCPY"

; Say how to lay out the function key display
;
; INPUT
;
; OUTPUT
;	DS:[BX]		Number of function keys to display; number of
;			characters from each function key macro to display;
;			index of first function key to display
;
PUBLIC	FKYFMT
FKYFMT:	PUSH	AX
	MOV	AL,CRTWID
	MOV	BX,OFFSET FKEY40
	CMP	AL,80D
	JB	FKYFM2
	MOV	BX,OFFSET FKEY80
FKYFM2:	POP	AX
	RET

;Do OEM specific termination processing (from GIODSK.ASM)
;
PUBLIC	GWTERM
GWTERM:	MOV	BH,VISPAG		; Force the visible page to become
	MOV	ACTPAG,BH		; the active page
	JMP	SCNTRM			; Hand over to the platform-
					; -independent callback

; Return graphics dimensions for current screen
;
; INPUT
;
; OUTPUT
;	CX		width (X) in pixels
;	DX		height (Y) in pixels
;
PUBLIC	GRPSIZ
GRPSIZ:	PUSH	AX
	XOR	CX,CX
	XOR	DX,DX
	MOV	AL,CRTMOD
	CMP	AL,4D
	JB	GRPSZ1
	MOV	DX,200D
	CMP	AL,6
	JA	GRPSZ1
	MOV	CX,640D
	JZ	GRPSZ1
	SHR	CX,1
GRPSZ1:	POP	AX
	RET

PUBLIC	FKYADV
FKYADV:			;Dummy function
	INT	3
	RET

;
; RETURN
;	FLAGS		ZF=1 no key available
;			ZF=0, CF=0 one-byte character key or IBM scan code
;			ZF=0, CF=1 special key sequence (e.g. ^Break)
;	AX		Next key from keyboard if one exists
;
PUBLIC	KEYINP
KEYINP:	MOV	AH,01H
	INT	16H
	JNZ	KEYIN2
	HLT
	RET
KEYIN2:	XOR	AH,AH
	INT	16H
	TEST	AX,AX
	RET

; Map control character for editing
;
; INPUT
;	AX		Control character
; OUTPUT
;	FLAGS		ZF=1 ignore character
;			ZF=0 do not ignore
;	AX		Mapped control character to process
;
; REGISTERS AFFECTED
;
PUBLIC	EDTMAP
EDTMAP:	CMP	AX,001FH
	JA	NOEDF
	PUSH	AX
	PUSH	CX
	CMP	AL,0FH
	MOV	CL,AL
	JA	EDTM1X
	MOV	AX,0111111111101100B	; Ask to specially handle ^B, ^C,
	JMP	SHORT TSTEDF		; ^E...^N
EDTM1X:	SUB	CL,10H
	MOV	AX,1111100000000100B	; Ask to specially handle ^R, ^[...^_
	JMP	SHORT TSTEDF

; Map control character for printing
;
; INPUT
;	AX		Control character
; OUTPUT
;	FLAGS		ZF=1 ignore character
;			ZF=0 do not ignore
;	AX		Mapped control character to process
;
; REGISTERS AFFECTED
;
PUBLIC	PRTMAP
PRTMAP:	CMP	AX,001FH
	JA	NOEDF
	PUSH	AX
	PUSH	CX
	CMP	AL,0FH
	MOV	CL,AL
	JA	PRTM1X
	MOV	AX,0011111010000000B	; Ask to specially handle ^G, ^I, ^J,
	JMP	SHORT TSTEDF		; ^K, ^L, ^M
PRTM1X:	SUB	CL,10H
	MOV	AX,1111000000000000B	; Ask to specially handle ^\, ^], ^^,
TSTEDF:	SHR	AX,CL			; ^_
	TEST	AL,1
	POP	CX
	POP	AX
	JZ	NOEDF
MAPEDF:	MOV	AH,0FFH
NOEDF:	TEST	AX,AX
	RET

PUBLIC	RDPEN
RDPEN:			;Dummy function
	INT	3
	RET
	DB	"RDPEN"

PUBLIC	CSRATR
CSRATR:			;Dummy function
	INT	3
	RET
	DB	"CSRATR"

PUBLIC	GWINI
GWINI:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	BP
CRTTRY:	MOV	AH,0FH			; Get current video mode
	INT	10H
	CMP	AL,07H			; If not a mode we know about, force
	JNA	CRTOK			; "standard" text mode
	MOV	AX,0003H
	INT	10H
	JMP	CRTTRY
CRTOK:	MOV	CRTMOD,AL
	MOV	VISPAG,BH
	MOV	ACTPAG,BH
	MOV	BL,07H			; Decide initial text colour to use
	CMP	AL,03H
	JBE	CRTOK2
	CMP	AL,07H
	JZ	CRTOK2
	MOV	BL,03H
	CMP	AL,06H
	JNZ	CRTOK2
	MOV	BL,01H
CRTOK2:	MOV	AL,AH			; INT 10H conveniently gives us the
					; number of character columns
	MOV	CL,25D			; Assume 25 rows
	MOV	TXTATR,BL
	CALL	SCNSWI			; Invoke callback to set screen
					; parameters
	MOV	AL,0			; Now really clear the screen
	CALL	CLRSCN
	POP	BP
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET

PUBLIC	NWRITE
NWRITE:			;Dummy function
	INT	3
	RET
	DB	"NWRITE"

PUBLIC	SCRSTT
SCRSTT:			;Dummy function
	INT	3
	RET
	DB	"SCRSTT"

PUBLIC	CSRDSP
CSRDSP:	PUSH	AX
	PUSH	BX
	PUSH	DX
	MOV	BH,ACTPAG
	MOV	DH,CSRY
	MOV	DL,CSRX
	SUB	DX,0101H
	MOV	AH,2
	INT	10H
	POP	DX
	POP	BX
	POP	AX
	RET

PUBLIC	SETATR
SETATR:			;Dummy function
	INT	3
	RET
	DB	"SETATR"

PUBLIC	PNTINI
PNTINI:			;Dummy function
	INT	3
	RET
	DB	"PNTINI"

PUBLIC	SETCLR
SETCLR:			;Dummy function
	INT	3
	RET
	DB	"SETCLR"

PUBLIC	SCRATR
SCRATR:			;Dummy function
	INT	3
	RET
	DB	"SCRATR"

PUBLIC	TRMCOM
TRMCOM:			;Dummy function
	INT	3
	RET
	DB	"TRMCOM"

PUBLIC	POLLEV
POLLEV:			;Dummy function
	INT	3
	RET
	DB	"POLLEV"

PUBLIC	POKFLT
POKFLT:			;Dummy function
	INT	3
	RET
	DB	"POKFLT"

PUBLIC	RDSTIK
RDSTIK:			;Dummy function
	INT	3
	RET
	DB	"RDSTIK"

PUBLIC	MAPSUP
MAPSUP:			;Dummy function
	INT	3
	RET
	DB	"MAPSUP"

CSEG	ENDS

DSEG	SEGMENT PUBLIC 'DATASG'
	PUBLIC	PIXBTS,PIXOFS,ATRMSK

				; See FKYFMT above
FKEY40	DB	6D,5D,1D	; (?!?) Function key display format for 40x25
FKEY80	DB	6D,10D,1D	; (?!?) Function key display format for 80x25


CRTMOD	DB	?		; (?) Current screen mode
VISPAG	DB	?		; (?) Current visible display page
TXTATR	DB	?		; (?) Current colour attribute for printing
				; text
GRPFGC	DB	?		; (?!?) Current foreground colour for graphics
GRPBGC	DB	?		; (?!?) Current background colour for graphics

PIXBTS	DB	?		; From BASICA.COM DS:0055H
				; Number of bits per pixel; assumed to be 0
				; (not graphics mode), 1, or 2

PIXOFS	DW	?		; From BASICA.COM DS:06F3H
				; Byte offset of current pixel into video
				; memory

ATRMSK	DB	?		; From BASICA.COM DS:06F5H
				; Mask to apply to byte at 0B800H:[PIXOFS]
				; to cover current pixel

ATRPAT	DB	?		; From BASICA.COM DS:06F6H
				; Bit pattern for current graphics
				; attribute, to be masked with ATRMSK

CBFSEG	DW	?		; Segment of COM buffer (i.e. CBFSEG:0)

	EXTRN	ACTPAG:BYTE,CRTWID:BYTE
	EXTRN	WDOTOP:BYTE,WDOLFT:BYTE,WDOBOT:BYTE,WDORGT:BYTE
	EXTRN	CRTWID:BYTE,LINCNT:BYTE
	EXTRN	CSRX:BYTE,CSRY:BYTE
DSEG	ENDS

SSEG	SEGMENT STACK 'STACKSG'
	DB	128D DUP(?)	; (?) Stash a startup stack here
SSEG	ENDS
	END


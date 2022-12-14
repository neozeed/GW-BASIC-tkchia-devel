	.RADIX	8

DGROUP	GROUP	DSEG,SSEG

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

Many other routines are not even in BASICA.COM though, and have to be
written from scratch.
        *
	.SALL

	EXTRN	SCNSWI:NEAR,SCNCLR:NEAR,SCNTRM:NEAR,FCERR:NEAR,SFTOFF:NEAR
	EXTRN	CBKSTA:NEAR,CBKTRM:NEAR,SNDSTA:NEAR,SNDTRM:NEAR
	EXTRN	EVSTA:NEAR,EVTRM:NEAR

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
	XOR	CX,CX
	MOV	DH,LINCNT
	MOV	DL,CRTWID
	JMP	SHORT CLRALL
CLRWDO:	MOV	CH,WDOTOP
	MOV	CL,WDOLFT
	SUB	CX,0101H
	MOV	DH,WDOBOT
	MOV	DL,WDORGT
CLRALL:	SUB	DX,0101H
	CALL	FILATR
	MOV	BH,AL
	MOV	AX,0600H
	INT	10H
	JMP	SCNCLR

; Internal function: return in AL the screen attribute to use for INT 10H
; text blanking operations
;
FILATR:	CALL	TXTMOD
	MOV	AL,TXTATR
	JC	FILAT2
	PUSH	CX
	MOV	CL,4
	SHR	AL,CL
	POP	CX
FILAT2:	RET

; Internal function: say whether the current video mode is a text mode
;
TXTMOD:	PUSH	CX
	MOV	CH,10001111B
	MOV	CL,CRTMOD
	INC	CX
	SHR	CH,CL
	POP	CX
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
	DB	0B0H,0,160D,1,0		; For mode 7

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
	SHL	BX,1
	XCHG	DH,DL
	SUB	DX,0101H
	MOV	ES:0450H[BX],DX
	POP	ES
	POP	DX
	POP	BX
	RET

; From BASICA.COM CSEG:2215H
; Load (BX, AL) with the current pixel's byte offset & mask
; This is likely to have been calculated earlier with MAPXYC
;
PUBLIC	FETCHC
FETCHC:	MOV	BX,PIXOFS
	MOV	AL,ATRMSK
	RET

; From BASICA.COM CSEG:221DH
; Set the current pixel's byte offset & mask to (BX, AL)
; This is likely to have been calculated earlier with MAPXYC & then
; retrieved with FETCHC
;
PUBLIC	STOREC
STOREC:	MOV	PIXOFS,BX
	MOV	ATRMSK,AL
	RET

;Let screen editor set width
;pass Width in AL
;pass Height in CL

PUBLIC	SWIDTH
SWIDTH:	CMP	CL,25D
	JNZ	SWDERR
	MOV	BX,OFFSET CSEG:SMMP40
	CMP	AL,40D
	JZ	SWIDT2
	MOV	BX,OFFSET CSEG:SMMP80
	CMP	AL,80D
	JZ	SWIDT2
SWDERR:	STC
	RET
SWIDT2:	MOV	AL,CRTMOD
	XLAT	CS:[BX]
	TEST	AL,AL
	JS	SWDERR
	CALL	SCNRST
	CLC
	RET

; Internal data structure: how to switch to another BIOS video mode, given
; that we want to change the screen width
SMMP40	DB	0,1,0,1,4,5,4,7
SMMP80	DB	2,3,2,3,6,6,6,7

; Sets a horizontal series of pixels on the screen to the current colour
; The desired pixel location and colour should be set first
; using MAPXYC and SETATR
;
; INPUT
;	BX		Number of pixels to set
; REGISTERS AFFECTED
;	(?)
;
PUBLIC	NSETCX
NSETCX:	TEST	BX,BX
	JZ	NSCZRO
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	ES
	PUSHF
	MOV	AX,0B800H		; Set things up
	MOV	ES,AX
	MOV	CL,PIXBTS
	MOV	DI,PIXOFS
	MOV	DH,ATRPAT
	MOV	DL,ATRMSK
	TEST	DL,DL			; If we are not on a byte boundary,
	JS	NSCBND			; then slowly fill in pixels until
	MOV	AL,ES:[DI]		; we are
NSCLFT:	MOV	AH,DH
	XOR	AH,AL
	AND	AH,DL
	XOR	AL,AH
	DEC	BX
	JZ	NSCFIN
	ROR	DL,CL
	JNC	NSCLFT
	STOSB
NSCBND:	MOV	SI,10H			; Count number of pixels per shortword
	CMP	CL,1
	JZ	NSCPS1
	SHR	SI,1
NSCPS1:	CMP	BX,SI			; Try to quickly draw pixels in the
	JNA	NSCRG1			; middle
	MOV	AH,DH
	MOV	AL,DH
	SUB	BX,SI
NSCMID:	STOSW
	SUB	BX,SI
	JA	NSCMID
	ADD	BX,SI
NSCRG1:	MOV	AL,ES:[DI]		; Fill in pixels on the right
NSCRGT:	MOV	AH,DH
	XOR	AH,AL
	AND	AH,DL
	XOR	AL,AH
	DEC	BX
	JZ	NSCFIN
	ROR	DL,CL
	JNC	NSCRGT
	STOSB
	JMP	SHORT NSCRG1
NSCFIN:	MOV	PIXOFS,DI		; Update PIXOFS and ATRMSK
	MOV	ATRMSK,DL
	STOSB
	POPF
	POP	ES
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
NSCZRO:	RET

; Modified from BASICA.COM CSEG:34F7H
; Send a byte to a printer
;
; INPUT
;	AH		Printer number (0 = LPT1:, 1 = LPT2:, etc.)
;	AL		Byte to send
; OUTPUT
;	AH		0 Success
;			1 Device not available
;			2 Device timeout
;			3 Out of paper
;			> 3 Device I/O error
; REGISTERS AFFECTED
;	AL (?)
;
PUBLIC	SNDLPT
SNDLPT:	PUSH	DX
	XOR	DX,DX			; Send out the character
	XCHG	AH,DL
	PUSH	BX			; RBIL says "BUGS: Some print
	INT	17H			; spoolers trash the BX register on
	POP	BX			; return"
	MOV	AL,AH
	TEST	AL,00100000B		; Test for out-of-paper condition
	JNZ	LPTOTP
	TEST	AL,00000001B		; Test for timeout condition
	JNZ	LPTDTO
	TEST	AL,01000000B		; Test for device-not-available
	JZ	LPTDNA			; condition
	XOR	AL,00010000B
	TEST	AL,00011000B		; Test for general I/O error
	JNZ	LPTDIO
	MOV	AH,0
	POP	DX
	RET
LPTDNA:	MOV	AH,1
	DB	3DH
LPTDTO:	MOV	AH,2
	DB	3DH
LPTOTP:	MOV	AH,3
	DB	3DH
LPTDIO:	MOV	AH,4
	POP	DX
	RET

; Filter a PEEK operation
;
; INPUT
;	ES:BX		Address to peek
; OUTPUT
;	FLAGS		ZF=0 Go ahead and do the actual PEEK
;			ZF=1 Do not do the actual PEEK
;	AL		Value to return for PEEK function if ZF=1
;
PUBLIC	PEKFLT
PEKFLT:	TEST	SP,SP
	RET

; Filter a POKE operation
;
; INPUT
;	ES:DX		Address to poke
;	AL		Value to poke
; OUTPUT
;	FLAGS		ZF=0 Go ahead and do the actual POKE
;			ZF=1 Do not do the actual POKE
; REGISTERS AFFECTED
;	DI (?)
;
PUBLIC	POKFLT
POKFLT:	TEST	AL,AL			; MS-DOS v1.25 DONKEY.BAS uses
	JNZ	POKOK			;	975 DEF SEG: POKE 106,0
	CMP	DX,106D			; to stop any ongoing expansion of
	JNZ	POKOK			; of function keys & Alt- keys ---
	PUSH	AX			; map it to a call to SFTOFF; (?) also
	MOV	AX,ES			; do the actual POKE for good measure
	MOV	DI,DS
	CMP	AX,DI
	POP	AX
	JNZ	POKOK
	CALL	SFTOFF
POKOK:	TEST	SP,SP
	RET

; Set serial port (COM1, COM2, etc.) buffer location and size
;
; INPUT
;	CX		Segment for COM buffer
; OUTPUT
;	FLAGS		CF=0 OK
;			CF=1 Out of memory
; REGISTERS AFFECTED
;
PUBLIC	SETCBF
SETCBF:	JNZ	CBSPEC			; If no buffer size given, use a
	MOV	DX,100H			; default size
CBSPEC:	MOV	CBFSEG,CX		; Record the COM buffer location
	CLC				;
	RET

; From BASICA.COM CSEG:2265H
; Set current pixel to the pixel just to its left
;
PUBLIC	LEFTC
LEFTC:	MOV	AL,CL
	MOV	CL,PIXBTS
	ROL	ATRMSK,CL
	MOV	CL,AL
	JC	LEFTC2
	RET
LEFTC2:	DEC	PIXOFS
	RET

; Set current pixel to the pixel just to its right
; (Not in BASICA.COM (?))
;
PUBLIC	RIGHTC
RIGHTC:	MOV	AL,CL
	MOV	CL,PIXBTS
	ROR	ATRMSK,CL
	MOV	CL,AL
	JC	RGHTC2
	RET
RGHTC2:	INC	PIXOFS
	RET

; From BASICA.COM CSEG:2295H
; Set "current pixel" to given (X, Y) --- map coordinates to a byte offset
; in video memory & a bit mask, & update PIXOFS & ATRMSK
;
; INPUT
;	(CX, DX)	(X, Y) coordinates
; REGISTERS AFFECTED
;	AX, BX, CX, DX, BP
;
PUBLIC	MAPXYC
MAPXYC:	MOV	BP,CX
	SHR	DX,1
	LAHF
	MOV	BX,DX
	MOV	CL,2
	SHL	DX,CL
	ADD	DX,BX
	MOV	CL,4
	SHL	DX,CL
	SAHF
	JNC	MXYEVN
	ADD	DX,2000H		; Add interlace offset
MXYEVN:	MOV	PIXOFS,DX
	MOV	DX,BP
	MOV	CL,DL
	TEST	PIXBTS,1
	JZ	MXYPX2
	MOV	AL,07H
	AND	CL,AL
	MOV	AL,10000000B
	SHR	AL,CL
	MOV	ATRMSK,AL
	MOV	CL,3
	SHR	DX,CL
	ADD	PIXOFS,DX
	RET
MXYPX2:	MOV	AL,03H
	AND	CL,AL
	ADD	CL,CL
	MOV	AL,11000000B
	SHR	AL,CL
	MOV	ATRMSK,AL
	MOV	CL,2
	SHR	DX,CL
	ADD	PIXOFS,DX
	RET

; Map keystrokes to values for INKEY$
;
; INPUT
;	FLAGS		ZF=1 (?) Impossible
;			ZF=0, CF=0 One-byte character key or IBM scan code
;			ZF=0, CF=1 (?) Special key sequence (e.g. ^Break)
;	AX, DX		Keystroke, in format similar to KEYINP output (?)
; OUTPUT
;	FLAGS		ZF=1 Discard keystroke
;			ZF=0 CF=0 Return keystroke as 1 byte
;			ZF=0 CF=1 Return keystroke as 2 bytes
;	AX		Mapped keystroke
;
PUBLIC	INKMAP
INKMAP:	JC	INKZAP
	CMP	AL,0FEH
	CLC
	JNZ	INKSNG
	MOV	AX,DX
	TEST	SP,SP
	STC
	RET
INKZAP:	CMP	SP,SP
INKSNG:	RET

; Map keystrokes to values for (?) purposes other than INKEY$
;
; INPUT
;	FLAGS		ZF=1 (?) Impossible
;			ZF=0, CF=0 One-byte character key or IBM scan code
;			ZF=0, CF=1 (?) Special key sequence (e.g. ^Break)
;	AX, DX		Keystroke, in format similar to KEYINP output (?)
; OUTPUT
;	FLAGS		ZF=1 Discard keystroke
;			ZF=0 CF=0 Return keystroke as 1 byte
;			ZF=0 CF=1 Return keystroke as 2 bytes
;	AX		Mapped keystroke
;
PUBLIC	INFMAP
INFMAP:	CALL	INKMAP
	JNC	INFNDB
	CMP	SP,SP
INFNDB:	RET

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
	CALL	TXTMOD			; Do not try to set text colours in
	JNC	SETFBF			; graphics mode --- doing so will
					; make the function key display text
					; disappear!
	MOV	TXTFGC,AL
	MOV	TXTBGC,BL
	PUSH	AX
	PUSH	BX
	PUSH	CX
	MOV	CL,5
	SHL	BL,CL
	DEC	CX
	SHL	AL,CL			; Handle the "blinking" flag!
	RCR	BL,1
	SHR	AL,CL
	OR	AL,BL
	MOV	TXTATR,AL
	POP	CX
	POP	BX
	POP	AX
	RET
SETFBG:	MOV	FORCLR,AL
	MOV	BAKCLR,BL
SETFBF:	RET

PUBLIC	INICOM
INICOM:			;Dummy function
	INT	3
	MOV	AH,6
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
GETHED:	MOV	BX,OFFSET CSEG:OEMHED
	CMP	BX,BX
	RET
OEMHED:	DB	"GW-BASIC "
IFDEF	OEMVER				; If an OEMVER macro is defined,
	IRPC	X,OEMVER		; assume it gives more detailed
		DB	"&X&"		; version information; use it
	ENDM
ELSE
	DB	"2022"
ENDIF
	DB	" version"
IFDEF	__JWASM__
	DB	" (JWasm)"
ENDIF
	DB	", MIT License"
	ACRLF
	DB	"(C) Copyright D. Spinellis, S. Gros, T.K. Chia 2020--2022"
	DB	0

; From BASICA.COM CSEG:2225H
; Set current pixel to the pixel just above it, unless pixel is already on
; first row, then just return with CF=1
;
PUBLIC	TUPC
TUPC:	MOV	AX,PIXOFS
	CMP	AX,80D
	JNB	UPC1
	STC
	RET

; From BASICA.COM CSEG:222FH
; Set current pixel to the pixel just above it
;
PUBLIC	UPC
UPC:	MOV	AX,PIXOFS
UPC1:	CMP	AH,20H
	JB	UPC2
	SUB	AH,20H
	MOV	PIXOFS,AX
	RET
UPC2:	ADD	AX,2000H-80D
	MOV	PIXOFS,AX
	RET

; From BASICA.COM CSEG:2306H; SXYERR is from CSEG:22FAH
; Clip graphics coordinates to the boundaries of the graphics screen
;
; INPUT
;	(CX, DX)	(X, Y) coordinates
; OUTPUT
;	(CX, DX)	Clipped (X, Y) coordinates
;	FLAGS		CF=1 if coordinates were not clipped
; REGISTERS AFFECTED
;	AX, BX
;
PUBLIC	SCALXY
SCALXY:	MOV	AL,PIXBTS
	OR	AL,AL
	JZ	SXYERR
	OR	CH,CH
	JS	SXYXNG
	MOV	BX,640D
	TEST	AL,1
	JNZ	SXYWID
	SHR	BX,1
SXYWID:	CMP	CX,BX
	LAHF
	JB	SXYXOK
	DEC	BX
	MOV	CX,BX
SXYXOK:	OR	DH,DH
	JS	SXYYNG
	CMP	DX,200D
	JB	SXYYOK
	MOV	DX,199D
	RET
SXYYOK:	SAHF
	RET
SXYYNG:	XOR	DX,DX
	RET
SXYXNG:	XOR	CX,CX
	LAHF
	JMP	SHORT SXYXOK

SXYERR:	JMP	FCERR

; From BASICA.COM CSEG:233AH
; Return the screen's pixel aspect ratio (?)
;
; OUTPUT
;	BX		(?) 100H * (width of 1 pixel) / (height of 1 pixel)
;	DX		(?) 100H * (height of 1 pixel) / (width of 1 pixel)
;
PUBLIC	GTASPC
GTASPC:	MOV	BX,00D5H
	MOV	DX,0133H
	TEST	PIXBTS,1
	JZ	ASPFIN
	SHR	BX,1
	INC	BX
	ADD	DX,DX
ASPFIN:	RET

; From BASICA.COM CSEG:24A3H; added CLC
; Initialize variables for a PAINT operation
;
; INPUT
;	AL		Border colour
;
PUBLIC	PNTINI
PNTINI:	MOV	CH,ATRPAT
	CALL	SETATR
	MOV	BORPAT,AL
	MOV	ATRPAT,CH
	CLC
	RET

; From BASICA.COM CSEG:24B2H
;
SLRCHG:	MOV	AL,BH
	XOR	AL,DL
	AND	AL,CH
	JZ	SLRC1
	MOV	AL,BH
	XOR	AL,DH
	AND	AL,CH
	OR	BL,AL
	XOR	BH,AL
	STC
SLRC1:	RET

; From BASICA.COM CSEG:24C6H
;
SLRL:	MOV	CL,PIXBTS
	ROL	CH,CL
	JNC	SLR4
	MOV	ES:[DI],BH
	CALL	SLR1
	LAHF
	DEC	DI
	MOV	BH,ES:[DI]
	SAHF
	RET
SLRR:	MOV	CL,PIXBTS
	ROR	CH,CL
	JNC	SLR4
	MOV	ES:[DI],BH
	INC	DI
	MOV	BH,ES:[DI]
SLR1:	TEST	DI,000FH
	JNZ	SLR4
	MOV	AX,DI			; Super-complicated way to test if
	MOV	CL,4			; (DI AND 1FFFH) is divisible by 5 (?)
	MOV	SI,BX			; If it is divisible by both 5 & 16,
	MOV	BH,AH			; i.e. by 80, then we have reached
	SHR	AX,CL			; an edge of a graphics row
	AND	AL,0FH
	AND	BH,0FH
	SHR	AH,1
	ADC	AL,BH
	MOV	BX,SI
	INC	CX
	ADD	AL,CL
	CMP	AL,25D
	JB	SLR2
	SUB	AL,25D
SLR2:	JZ	SLR3
	SUB	AL,CL
	JNB	SLR2
SLR3:	CMC
SLR4:	RET

; From BASICA.COM CSEG:2516H
; (?) Initialize state for SCANL & SCANR
;
SLRBEG:	MOV	DI,0B800H		; ES:0 = video memory
	MOV	ES,DI
	MOV	DI,PIXOFS		; (DI, CH) = current pixel position
	MOV	CH,ATRMSK		;	     within scan
	MOV	DL,BORPAT		; DL = border pattern bitmap for PAINT
	MOV	DH,ATRPAT		; DH = current foreground colour
	XOR	BL,BL
	MOV	BH,ES:[DI]		; What is currently at ES:[DI]
	RET

; From BASICA.COM CSEG:2531H
; Scan leftwards from current pixel to flood area with colour to paint (?)
;
PUBLIC	SCANL
SCANL:	PUSH	ES
	MOV	BP,-1
	CALL	SLRBEG
SCL1:	INC	BP
	CALL	SLRL
	JC	SCL2
	CALL	SLRCHG
	JC	SCL1
SCL2:	CALL	SLRR
	MOV	ES:[DI],BH
	MOV	PIXOFS,DI
	MOV	ATRMSK,CH
	MOV	CL,BL
	MOV	BX,BP
	POP	ES
	RET

; From BASICA.COM CSEG:2557H
; Scan rightwards from current pixel to flood area with colour to paint (?)
;
PUBLIC	SCANR
SCANR:	PUSH	ES
	MOV	BP,DX
	CALL	SLRBEG
SCR1:	CALL	SLRCHG
	JC	SCR3
	DEC	BP
	JZ	SCR2
	CALL	SLRR
	JNC	SCR1
	XOR	BP,BP
SCR2:	PUSH	BP
	JMP	SHORT SCR7
SCR3:	MOV	CSAVEA,DI
	MOV	CSAVEM,CH
	PUSH	BP
	XOR	BP,BP
	JMP	SHORT SCR5
SCR4:	CALL	SLRCHG
	JNC	SCR6
SCR5:	INC	BP
	CALL	SLRR
	JNC	SCR4
	CALL	SLRL
SCR6:	MOV	PIXOFS,DI
	MOV	ATRMSK,CH
SCR7:	POP	DX
	MOV	ES:[DI],BH
	MOV	CL,BL
	MOV	BX,BP
	POP	ES
	RET

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
	MOV	AL,TXTFGC
	MOV	BL,TXTBGC
	RET
GETFBG:	MOV	AL,FORCLR
	MOV	BL,BAKCLR
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

; Do OEM-specific initialization of the data segment after it has been moved
; to its final location
;
PUBLIC	SEGINI
SEGINI:	CALL	SNDSTA			; _Really_ start sound support
	CALL	CBKSTA			; Initialize Ctrl-Break handling
	JMP	EVSTA			; Initialize event handling

PUBLIC	RECCOM
RECCOM:			;Dummy function
	INT	3
	RET
	DB	"RECCOM"

; Reads the colour of a screen pixel
; The desired pixel location should be set first using MAPXYC
;
; INPUT
;
; OUTPUT
;	AL		Pixel colour
; REGISTERS AFFECTED
;	BX, CX, SI, DI (?)
;
PUBLIC	READC
READC:	MOV	AL,ATRMSK
	MOV	CL,-1
READC1:	INC	CX
	SHR	AL,1
	JNC	READC1
	RCL	AL,1
	MOV	SI,ES
	MOV	DI,0B800H
	MOV	ES,DI
	MOV	BX,PIXOFS
	MOV	AH,ES:[BX]
	SHR	AH,CL
	AND	AL,AH
	MOV	ES,SI
	RET

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

; From BASICA.COM CSEG:2351H
; Do initialization for a graphics PUT or GET operation
;
; INPUT
;	AL		Action verb to apply to pixels
;			0 OR; 1 AND; 2 PRESET; 3 PSET; 4 XOR
;	DS:[BX]		Byte array to read from or write to
;	CX		Number of bits of graphics data to transfer
; REGISTERS AFFECTED
;	AX, BX, (?) CX, (?) DX
;
PUBLIC	PGINIT
PGINIT:	MOV	PGTARY,BX
	MOV	MAXDEL,CX
	MOV	BL,AL
	LAHF
	MOV	AL,ATRMSK
	XOR	BH,BH
PGISHF:	SHL	AL,1
	JC	PGIACT
	INC	BH
	JMP	SHORT PGISHF
PGIACT:	MOV	PGTSHF,BH
	SAHF
	JNC	PGIFIN
	XOR	BH,BH
	ADD	BX,BX
	MOV	BX,CS:PGTACS[BX]
	MOV	PGTACT,BX
PGIFIN:	RET

PGTACS	DW	OFFSET PGTOR
	DW	OFFSET PGTAND
	DW	OFFSET PGTRST
	DW	OFFSET PGTSET
	DW	OFFSET PGTXOR

PGTRST:	NOT	AL
PGTSET:	XOR	AL,ES:[DI]
	AND	AL,CH
	XOR	ES:[DI],AL
	INC	DI
	RET
PGTAND:	NOT	CH
	OR	AL,CH
	NOT	CH
	AND	ES:[DI],AL
	INC	DI
	RET
PGTOR:	AND	AL,CH
	OR	ES:[DI],AL
	INC	DI
	RET
PGTXOR:	AND	AL,CH
	XOR	ES:[DI],AL
	INC	DI
	RET

; From BASICA.COM CSEG:23ADH
; Read a horizontal series of pixels into a byte array
; MAPXYC and PGINIT should be called earlier to say where on screen to read
; pixels from, where to write pixels to, and how many bits' worth of pixels
;
PUBLIC	NREAD
NREAD:	PUSH	ES
	CALL	NRWBEG
	NEG	CL
	AND	CL,7
	MOV	CH,CL
	JZ	NRD2
	XOR	AH,AH
	MOV	AL,ES:[DI]
	INC	DI
NRD1:	DEC	DX
	JS	NRD4
	STC
	RCR	AH,1
	DEC	CH
	JNZ	NRD1
	ROR	AL,CL
	AND	AH,AL
	MOV	BL,AH
NRD2:	MOV	BP,DX
	AND	DX,7
	SHR	BP,1
	SHR	BP,1
	SHR	BP,1
NRD3:	MOV	AL,ES:[DI]
	INC	DI
	DEC	BP
	JS	NRD5
	CALL	NRDBYT
	JMP	SHORT NRD3

NRDBYT:	XOR	AH,AH
	ROR	AX,CL
	OR	AL,BL
	MOV	[SI],AL
	MOV	BL,AH
	INC	SI
	RET

NRD4:	ROR	AL,CL
	AND	AL,AH
	MOV	BL,AL
	JMP	SHORT NRD7
NRD5:	XCHG	DL,CL
	MOV	AH,11111111B
	SHR	AH,CL
	XOR	AH,11111111B
	MOV	CL,DL
	JZ	NRD6
	AND	AL,AH
	MOV	DH,AL
	XOR	AL,AL
	SHR	AX,CL
	MOV	BH,AL
	MOV	AL,DH
	CALL	NRDBYT
	OR	BH,BH
	JZ	NRWFIN
NRD6:	OR	CL,CL
	JZ	NRWFIN
NRD7:	MOV	[SI],BL
	INC	SI
	JMP	SHORT NRWFIN

; From BASICA.COM CSEG:2425H
; Write a horizontal series of pixels from a byte array onto screen
; MAPXYC and PGINIT should be called earlier to say where on screen to write
; pixels to, where to read pixels from, and how many bits' worth of pixels
;
PUBLIC	NWRITE
NWRITE:	PUSH	ES
	CALL	NRWBEG
	MOV	CH,11111111B
	SHR	CH,CL
	MOV	BP,DX
	MOV	DH,11111111B
	SHR	BP,1
	SHR	BP,1
	SHR	BP,1
	JZ	NWR2
	MOV	DH,CH
NWR1:	CALL	NWRBYT
	MOV	CH,11111111B
	DEC	BP
	JNZ	NWR1
	AND	DL,7
	JZ	NWR4
NWR2:	XCHG	CL,DL
	MOV	AX,1111111100000000B
	SHR	AH,CL
	NOT	AH
	MOV	CL,DL
	SHR	AX,CL
	MOV	BH,AL
	AND	CH,AH
	NOT	DH
	OR	CH,DH
	CALL	NWRBYT
	OR	BH,BH
	JZ	NRWFIN
	MOV	CH,BH
NWR3:	MOV	AL,BL
	CALL	WORD PTR PGTACT
NRWFIN:	MOV	PGTARY,SI
	POP	ES
	RET
NWR4:	XOR	DH,11111111B
	MOV	CH,DH
	JZ	NRWFIN
	JMP	SHORT NWR3

; From BASICA.COM CSEG:247BH
NWRBYT:	LODSB
	XOR	AH,AH
	ROR	AX,CL
	OR	AL,BL
	MOV	BL,AH
	JMP	WORD PTR PGTACT

; From BASICA.COM CSEG:2488H
NRWBEG:	MOV	DX,MAXDEL
	MOV	DI,0B800H
	MOV	ES,DI
	MOV	DI,PIXOFS
	MOV	SI,PGTARY
	MOV	CL,PGTSHF
	XOR	BX,BX
	XOR	CH,CH
	CLD
	RET

; From BASICA.COM CSEG:2245H
; Set current pixel to the pixel just below it, unless pixel is already on
; last row, then just return with CF=1
;
PUBLIC	TDOWNC
TDOWNC:	MOV	AX,PIXOFS
	CMP	AX,8000D+2000H-80D
	JB	DOWNC1
	STC
	RET

; From BASICA.COM CSEG:224FH
; Set current pixel to the pixel just below it
;
PUBLIC	DOWNC
DOWNC:	MOV	AX,PIXOFS
DOWNC1:	CMP	AH,20H
	JB	DOWNC2
	SUB	AX,2000H-80D
	MOV	PIXOFS,AX
	RET
DOWNC2:	ADD	AH,20H
	MOV	PIXOFS,AX
	RET

; Implement (or not) the LCOPY command
; LCOPY [PARAM]
; Apparently this crashes some early versions of GW-BASIC/BASICA, & is a
; no-op in newer versions of GW-BASIC (e.g. 3.23)
; In any case I (tkchia) could not find much information about how it is
; supposed to work
;
; INPUT
;	DL		Parameter to LCOPY (?)
; OUTPUT
;	FLAGS		CF=0 Success
;			CF=1 Failure
;
PUBLIC	LCPY
LCPY:	STC
	RET

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
FKYFMT:	MOV	BX,OFFSET FKEY40
	CMP	CRTWID,80D
	JB	FKYFM2
	MOV	BX,OFFSET FKEY80
FKYFM2:	RET

;Do OEM specific termination processing (from GIODSK.ASM)
;
PUBLIC	GWTERM
GWTERM:	MOV	AL,VISPAG		; Force the visible page to become
	MOV	ACTPAG,AL		; the active page
	CALL	SCNTRM			; Invoke the platform-independent
					; callback
	MOV	AL,CRTINI		; Restore the startup screen mode,
	CMP	AL,CRTMOD		; if needed
	JZ	GWTRMF
	XOR	AH,AH
	INT	10H
GWTRMF:	MOV	AH,01H			; Restore the startup cursor shape
	MOV	CX,CSRINI
	INT	10H
	CALL	SNDTRM			; Clean up the sound module
	CALL	CBKTRM			; Clean up Ctrl-Break handling
	JMP	EVTRM			; Clean up event handling

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

; Switch between modes in the function key display (?)
; This version of GW-BASIC apparently allows a user to do this through ^T
;
; INPUT
;	FLAGS		ZF=0 Function keys currently displayed
;			ZF=1 Not
; OUTPUT
;	FLAGS		ZF=0 Display function keys
;			ZF=1 Do not display function keys
;
PUBLIC	FKYADV
FKYADV:	JZ	LABON
	CMP	CRTWID,80D
	JNB	LABOFF
	XOR	BYTE PTR FKEY40+2,1 XOR 6
	CMP	BYTE PTR FKEY40+2,1
	RET
LABOFF:	CMP	SP,SP
	RET
LABON:	TEST	SP,SP
	RET

; Internal data structure: mapping of IBM scan codes to "soft key" codes
;
	EDCTLK	EQU	"K"-"@"+80H	; "^K"
	EDCTLN	EQU	"N"-"@"+80H	; "^N"
	EDCTLR	EQU	"R"-"@"+80H	; "^R"
	EDCTLS	EQU	"S"-"@"+80H	; "^S"
	EDCTLBS	EQU	"\"-"@"+80H	; "^\"
	EDCTLRB	EQU	"]"-"@"+80H	; "^]"
	EDCTLCA	EQU	"^"-"@"+80H	; "^^"
	EDCTLUS	EQU	"_"-"@"+80H	; "^_"
	EDDEL	EQU	" "+80H		; Special "delete a character" code
	SCCMIN	EQU	10H
SCCMAP:	DB	"Q",	"W",	"E",	"R"		; 10H Alt-Q etc.
	DB	"T",	"Y",	"U",	"I"		; 14H Alt-T etc.
	DB	"O",	"P",	0,	0		; 18H Alt-O, Alt-P
	DB	0,	EDCTLS,	"A",	"S"		; 1CH Ctrl(-NumLock
							;     --- see ISRMSC),
							;     Alt-A, Alt-S
	DB	"D",	"F",	"G",	"H"		; 20H Alt-D etc.
	DB	"J",	"K",	"L",	0		; 24H Alt-J etc.
	DB	0,	0,	0,	0		; 28H Alt-Quote etc.
	DB	"Z",	"X",	"C",	"V"		; 2CH Alt-Z etc.
	DB	"B",	"N",	"M",	0		; 30H Alt-B etc.
	DB	0,	0,	0,	0		; 34H Alt-period etc.
	DB	0,	0,	0,	" "		; 38H F1
	DB	" "+1D,	" "+2D,	" "+3D,	" "+4D		; 3CH F2--F5
	DB	" "+5D,	" "+6D,	" "+7D,	" "+8D		; 40H F6--F9
	DB	" "+9D,	0,	0,	EDCTLK		; 47H F10, Home
	DB	EDCTLCA,0,	0,	EDCTLRB		; 48H Up, [PgUp,] Left
	DB	0,	EDCTLBS,0,	EDCTLN		; 4CH Right, End
	DB	EDCTLUS,0,	EDCTLR,	EDDEL		; 50H Down, [PgDn],
							;     Ins, Del
	SCCMAX	EQU	$-SCCMAP+SCCMIN-1

;
; RETURN
;	FLAGS		ZF=1 no key available
;			ZF=0, CF=0 one-byte character key or IBM scan code
;			ZF=0, CF=1 special key sequence (e.g. ^Break)
;	AX, DX		Next key from keyboard if one exists
;
PUBLIC	KEYINP
KEYINP:	MOV	AH,01H
	INT	16H
	JNZ	KEYIN2
	CMP	F_EDIT,0		; Suspend the CPU a bit --- but only
	JZ	KEYFIN			; if we are actively waiting for a
	HLT				; keystroke & not doing anything else
KEYNON:	CMP	SP,SP
KEYFIN:	RET
KEYIN2:	XOR	AH,AH
	INT	16H
	TEST	AL,AL
	JZ	KEYSCC
	MOV	AH,0			; Normal key with an ASCII code ---
	TEST	SP,SP			; just return
	RET
KEYSCC:	XCHG	AH,AL			; Try to map a special key to GIOKYB's
	MOV	DX,AX			; internal code; if this does not
	CMP	AL,SCCMIN		; work, return key as an IBM scan code
	JB	KEYSC2
	CMP	AL,SCCMAX
	JA	KEYSC2
	PUSH	BX
	MOV	BX,OFFSET CSEG:SCCMAP-SCCMIN
	XLAT	CS:[BX]
	POP	BX
	TEST	AL,AL
	JZ	KEYSC2
	SHL	AL,1			; Convert codes 00H--07FH to 080xxH,
	SBB	AH,AH			;		80H--0FFH to 0FFxxH
	SHR	AL,1
	OR	AH,80H
	TEST	SP,SP
	STC
	RET
KEYSC2:	MOV	AX,0FEH			; IBM scan code
	TEST	SP,SP
	CLC
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
	MOV	AX,1111100000010100B	; Ask to specially handle ^R, ^T,
	JMP	SHORT TSTEDF		; ^[...^_

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
TSTEDF:	INC	CX			; ^_
	SHR	AX,CL
	POP	CX
	POP	AX
	JNC	NOEDF
MAPEDF:	MOV	AH,0FFH
NOEDF:	TEST	SP,SP
	RET

; Set the shape of the cursor
; (?) This will likely be followed shortly by a call to CSRDSP
;
; INPUT
;	AH		Whether the 3rd parameter to LOCATE is given ---
;			-1 means yes, 0 means no
;	AL		3rd parameter to LOCATE (cursor visibility)
;	BH		Whether the 4th parameter to LOCATE is given
;	BL		4th parameter to LOCATE (cursor start scan line)
;	CH		Whether the 5th parameter to LOCATE is given
;	CL		5th parameter to LOCATE (cursor stop scan line)
; OUTPUT
;	FLAGS		CF=0 Success
;			CF=1 Error
; REGISTERS AFFECTED
;	AX, BX, CX, DX (?)
;
PUBLIC	CSRATR
CSRATR:	MOV	DX,CSRSHP
	TEST	AH,AH
	JZ	CSATSL
	CMP	AL,1
	SBB	AL,AL
	AND	AL,00100000B
	AND	DH,10011111B
	OR	DH,AL
CSATSL:	TEST	BH,BH
	JZ	CSABSL
	CMP	BL,00011111B
	JA	CSAERR
	AND	DH,11100000B
	OR	DH,BL
CSABSL:	TEST	CH,CH
	JZ	CSASET
	CMP	CL,00011111B
	JA	CSAERR
	AND	DL,11100000B
	OR	DL,CL
CSASET:	MOV	CSRSHP,DX
	CLC
	RET
CSAERR:	STC
	RET

; From GWINI below.
CRTVES:	XCHG	BX,AX			; If we can get the video mode via
	TEST	AX,7F80H		; VESA & it _is_ a weird mode, then
	JNZ	CRTRST			; force "standard" text mode
	JMP	SHORT CRTGTO

PUBLIC	GWINI
GWINI:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	BP
	XOR	DX,DX			; Initialize printer ports (up to
PRTINI:	MOV	AH,01H			; LPT4:)
	INT	17H
	INC	DX
	CMP	DL,4
	JNZ	PRTINI
	MOV	AH,03H			; Get and save initial screen cursor
	XOR	BH,BH			; shape
	INT	10H
	MOV	CSRINI,CX
	MOV	AX,4F03H		; Get initial video mode using VESA
	INT	10H			; --- useful to do this, in case the
	CMP	AX,004FH		; initial mode is some weird
	JZ	CRTVES			; SuperVGA mode which we cannot
					; easily return to
CRTGTO:	MOV	AH,0FH			; If we cannot get the video mode
	INT	10H			; through VESA, get it through the
					; classical interface
	AND	AL,01111111B		; Remove any "no blanking" bit in
	MOV	CRTINI,AL		; the mode number
	CMP	AL,07H			; If not a mode we know about, force
	JA	CRTRST			; "standard" text mode
	PUSH	AX
	PUSH	BX
	PUSH	ES
	MOV	BP,-1			; EGA & VGA BIOSes may say "screen
	MOV	ES,BP			; mode 03H" but the screen is actually
	MOV	AX,1130H		; in 80x43 or 80x50 mode; check for
	MOV	BH,01H			; this
	INT	10H
	MOV	BP,ES
	POP	ES
	POP	BX
	POP	AX
	INC	BP
	JZ	CRTOK2
	CMP	DL,24D
	JZ	CRTOK2
CRTRST:	MOV	AX,0003H
	INT	10H
CRTOK1:	MOV	AH,0FH
	INT	10H
CRTOK2:	MOV	CRTMOD,AL
	MOV	VISPAG,BH
	MOV	ACTPAG,BH
	MOV	BX,0007H		; Decide initial text colour to use
	CMP	AL,03H			; and the number of bits per pixel
	JBE	CRTOK3
	CMP	AL,07H
	JZ	CRTOK3
	MOV	BX,0203H
	CMP	AL,06H
	JNZ	CRTOK3
	MOV	BX,0101H
CRTOK3:	MOV	AL,AH			; INT 10H conveniently gives us the
					; number of character columns
	MOV	CL,25D			; Assume 25 rows
	MOV	TXTATR,BL
	MOV	TXTFGC,BL
	MOV	FORCLR,BL
	MOV	TXTBGC,0
	MOV	BAKCLR,0
	MOV	PIXBTS,BH
	PUSH	BX			; Save foreground colour, for SETATR
	CALL	SCNSWI			; Invoke callback to set screen
					; parameters
	POP	AX			; Set the colour attribute for
	CALL	SETATR			; graphics operations (not really
					; needed for text modes)
	MOV	AL,0			; Now really clear the screen
	CALL	CLRSCN
	POP	BP
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
CRTOK4:	RET

; Internal function: change the screen mode and reset relevant variables, if
; necessary
;
SCNRST:	CMP	CRTMOD,AL
	JZ	CRTOK4
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	BP
	XOR	AH,AH
	INT	10H
	JMP	CRTOK1

; Implement the SCREEN command
; SCREEN [MODE] [,[COLORSWITCH] [,[APAGE] [,[VPAGE]]]]
;
; INPUT
;	DS:[BX]		Command parameters as laid out by GTPRMS
;			First byte N gives number of parameters specified
;			This is followed by N pairs of bytes
;			1st byte:	0 parameter left blank
;					0FFH last parameter
;					',' parameter specified, not last (?)
;			2nd byte:	parameter value
; OUTPUT
;	FLAGS		CF=0 Success
;			CF=1 Error
;
PUBLIC	SCRSTT
SCRSTT:	MOV	SI,BX
	MOV	CL,[SI]
	XOR	CH,CH
	DEC	CX
	CMP	CL,3			; If < 1 or > 4 parameters, error
	JA	SCRERR
	MOV	AL,2[SI]		; If new MODE given, use it;
	CMP	1[SI],CH		; otherwise use the current mode
	JNZ	SCRMO1
	MOV	AL,CRTMOD		; If current BIOS video mode is 07H,
	CMP	AL,07H			; handle it specially...
	JZ	SCRMO3
	MOV	BX,OFFSET CSEG:SMMAP1
	XLAT	CS:[BX]
SCRMO1:	CMP	AL,2			; New MODE must be 0, 1, or 2
	JA	SCRERR
	MOV	AH,3			; If no COLORSWITCH given, assume
	JCXZ	SCRMO2			; nonzero
	DEC	CX
	CMP	3[SI],CH
	JZ	SCRMO2
	CMP	4[SI],CH
	JNZ	SCRMO2
	CBW
SCRMO2:	ADD	AL,AH
	CMP	CRTWID,80D
	JB	SCRMO3
	ADD	AL,8D
SCRMO3:	PUSH	BX
	MOV	BX,OFFSET CSEG:SMMAP2	; Get the BIOS video mode number
	XLAT	CS:[BX]
	PUSH	AX			; Get the maximum number of pages
	MOV	BX,OFFSET CSEG:TOTPAG	; for the new video mode while at it
	XLAT	CS:[BX]
	MOV	DH,AL
	POP	AX
	POP	BX
	CALL	SCNRST			; If necessary, change the video mode
					; and reset relevant variables
	JCXZ	SCRFIN
	DEC	CX
	MOV	DL,ACTPAG		; Determine the new active video
	CMP	5[SI],CH		; page number
	JZ	SCRACP
	MOV	DL,6[SI]
	CMP	DL,DH
	JAE	SCRERR
SCRACP:	MOV	AL,DL			; Determine the new visible video
	JCXZ	SCRVIP			; page number; this defaults to
	CMP	7[SI],CH		; the active page
	JZ	SCRVIP
	MOV	AL,8D[SI]
	CMP	AL,DH
	JAE	SCRERR
SCRVIP:	MOV	VISPAG,AL
	MOV	ACTPAG,DL
	MOV	AH,05H			; Set the visible page; the BIOS
	INT	10H			; will also change the active page
	CALL	PAGHAK			; Then set the active page
SCRFIN:	CLC				; We are done
	RET
SCRERR:	STC
	RET

; Internal function: pretend to the BIOS that the active video display page
; is ACTPAG, but without actually switching to it
;
PAGHAK:	PUSH	AX
	PUSH	DX
	PUSH	ES
	XOR	DX,DX
	MOV	ES,DX
	MOV	AL,ACTPAG
	CMP	ES:0462H,AL		; If the BIOS's idea of the active
	JZ	PAGHKF			; page is already correct, do nothing
	MOV	ES:0462H,AL
	XOR	AH,AH			; Otherwise, we need to recalculate
	MOV	DX,ES:044CH		; the page's start address in video
	MUL	DX			; memory
	MOV	ES:044EH,AX
PAGHKF:	POP	ES
	POP	DX
	POP	AX
	RET

; Internal data structure: mapping of BIOS video mode numbers to BASIC video
; mode numbers (except for mode 07H)
SMMAP1	DB	0,0,0,0,1,1,2

; Internal data structure: mapping of BASIC video mode numbers to BIOS video
; mode numbers, given current screen width (40 or 80 characters) and
; COLORSWITCH parameter to SCREEN
SMMAP2	DB	1,5,6			; COLORSWITCH = 0, width 40
	DB	0,4,6			; COLORSWITCH <> 0, width 40
	DB	?,7			; Special case
	DB	3,5,6			; COLORSWITCH = 0, width 80
	DB	2,4,6			; COLORSWITCH <> 0, width 80

; Internal data structure: total number of display pages for each video mode
TOTPAG:	DB	8D,8D,4,4,1,1,1,8D

; Display the text cursor
;
; INPUT
;	AL		Cursor type
;			0 Invisible
;			3 User cursor
; REGISTERS AFFECTED
;	BX (?)
;
PUBLIC	CSRDSP
CSRDSP:	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	AX
	MOV	BH,ACTPAG		; Move the cursor
	MOV	DH,CSRY
	MOV	DL,CSRX
	SUB	DX,0101H
	MOV	AH,2
	INT	10H
	POP	AX
	PUSH	AX
	MOV	CX,2100H		; Determine the cursor shape to use:
	TEST	AL,AL			; if asked to be invisible, then
	JZ	CSRDS2			; invisible it shall be
	MOV	CX,CSRSHP
	CMP	F_EDIT,0		; If we are not in edit mode, or if
	JZ	CSRDS2			; we are not in insert mode, then
	CMP	F_INST,0		; just use the user cursor shape
	JZ	CSRDS2
	MOV	AL,CH			; Otherwise (?) tweak the user cursor
	AND	AX,00011111B		; shape to form an "insert mode"
	JZ	CSRDS1			; cursor, by stretching it up 2 scan
	DEC	AX			; lines
	JZ	CSRDS1
	DEC	AX
CSRDS1:	AND	CH,11100000B
	OR	CH,AL
CSRDS2:	MOV	AH,01H
	INT	10H
	POP	AX
	POP	DX
	POP	CX
	POP	BX
	RET

; From BASICA.COM CSEG:22E6H, with a change to set the carry flag correctly
; Set the pixel colour to use for the next graphics operation
;
; INPUT
;	AL		Pixel colour
; OUTPUT
;	FLAGS		CF=0 Colour set successfully
;			CF=1 Error
; REGISTERS AFFECTED
;	AX, CX
;
PUBLIC	SETATR
SETATR:	CMP	AL,4
	JNB	ATRERR
	TEST	PIXBTS,1
	JZ	ATR2BT
	AND	AL,1
	NEG	AL
	MOV	ATRPAT,AL
	CLC
	RET
ATR2BT:	MOV	CL,01010101B
	MUL	CL
	MOV	ATRPAT,AL
	CLC
	RET
ATRERR:	STC
	RET

; Implement the SCREEN command
; COLOR [FOREGROUND [,[BACKGROUND] [,[BORDER]]]]	' under SCREEN 0
; COLOR [BACKGROUND [,[PALETTE]]]			' under SCREEN 1
;
; INPUT
;	DS:[BX]		Command parameters as laid out by GTPRMS
; OUTPUT
;	FLAGS		CF=0 Success
;			CF=1 Error
;
PUBLIC	SETCLR
SETCLR:	PUSHF
	CLD
	MOV	SI,BX			; Test if parameter count is sane
	MOV	AL,CRTMOD		; for the current video mode
	MOV	BX,OFFSET CSEG:CLRPRM
	XLAT	CS:[BX]
	CBW
	XCHG	CX,AX
	LODSB
	TEST	AL,AL
	JZ	CLRERR
	CMP	AL,CL
	JA	CLRERR
	MOV	CL,AL
	CALL	TXTMOD
	JNC	CLRGRP
	LODSW				; We are in SCREEN 0; first get
	TEST	AL,AL			; FOREGROUND
	MOV	AL,AH
	JNZ	CLRFGC
	MOV	AL,TXTFGC
CLRFGC:	XCHG	BX,AX			; Get BACKGROUND
	DEC	CX
	JZ	CLRBG1
	LODSW
	TEST	AL,AL
	MOV	AL,AH
	JNZ	CLRBG2
CLRBG1:	MOV	AL,TXTBGC
CLRBG2:	XCHG	BX,AX			; Check foreground & background
	CMP	AL,1FH			; colours for sanity
	JA	CLRERR
	CMP	BL,0FH
	JA	CLRERR
	CLC				; Set foreground & background
	CALL	SETFBC			; colours for text
	DEC	CX			; Get BORDER if present
	JZ	CLRFIN
	LODSW
	TEST	AL,AL
	JZ	CLRFIN
	MOV	BL,AH			; Set border colour
	XOR	BH,BH
CLRPAL:	MOV	AH,0BH
	INT	10H
CLRFIN:	POPF				; We are done
	CLC
	RET
CLRGRP:	LODSW				; We are in SCREEN 1; get BACKGROUND
	TEST	AL,AL
	JZ	CLRBGC
	PUSH	CX			; If present, set background (&
	MOV	BL,AH			; border) colour
	XOR	BH,BH
	MOV	AH,0BH
	INT	10H
	POP	CX
CLRBGC:	DEC	CX			; Get PALETTE
	JZ	CLRFIN
	LODSW
	TEST	AL,AL
	JZ	CLRFIN
	MOV	BL,AH			; If present, set the palette
	MOV	BH,01H
	AND	BL,BH
	JMP	CLRPAL
CLRERR:	POPF
	STC
	RET

; Internal data structure: maximum argument count to COLOR, for each BIOS
; video mode
CLRPRM:	DB	3,3,3,3,2,2,0,2

; OEM supplied screen input(read colour attributes)
;
; INPUT
;	AX		Column
;	BX		Row
; OUTPUT
;	BX		Colour attributes
; REGISTERS AFFECTED
;	(?)
;
PUBLIC	SCRATR
SCRATR:	PUSH	DX
	MOV	DH,AL
	MOV	DL,BL
	CALL	CSRHAK
	POP	DX
	PUSH	AX
	MOV	AH,08H
	MOV	BH,ACTPAG
	INT	10H
	MOV	BL,AH
	POP	AX
	XOR	BH,BH
	RET

PUBLIC	TRMCOM
TRMCOM:			;Dummy function
	INT	3
	RET
	DB	"TRMCOM"

; Map "super shift key" (Alt-A ... Alt-Z) to a keyword in the keyword table
;
; INPUT
;	AL		(?) The letter for the key ("A" ... "Z")
; OUTPUT
;	CH		Index into GW-BASIC's keyword table for the letter
;
PUBLIC	MAPSUP
MAPSUP:	MOV	CH,1
	RET

CSEG	ENDS

DSEG	SEGMENT PUBLIC 'DATASG'
	PUBLIC	PIXBTS,PIXOFS,ATRMSK

				; See FKYFMT above
FKEY40	DB	6D,5D,1D	; (?!?) Function key display format for 40x25
FKEY80	DB	6D,10D,1D	; (?!?) Function key display format for 80x25


CRTMOD	DB	?		; (?) Current screen mode
CRTINI	DB	?		; (?) Initial screen mode on GW-BASIC start
CSRINI	DW	?		; (?!?) Initial cursor shape on GW-BASIC start
VISPAG	DB	?		; (?) Current visible display page

TXTATR	DB	?		; (?) Current colour attribute for printing
				; text
TXTFGC	DB	?		; (?!?) Current foreground colour for text
TXTBGC	DB	?		; (?!?) Current background colour for text

CSRSHP	DW	0607H		; (?!?) Current shape of user cursor

FORCLR	DB	?		; Current foreground colour for graphics
BAKCLR	DB	?		; Current background colour for graphics
				; The names FORCLR & BAKCLR are mentioned in
				; GENGRP.ASM

PIXBTS	DB	?		; From BASICA.COM DSEG:0055H
				; Number of bits per pixel; assumed to be 0
				; (not graphics mode), 1, or 2

PIXOFS	DW	?		; From BASICA.COM DSEG:06F3H
				; Byte offset of current pixel into video
				; memory

ATRMSK	DB	?		; From BASICA.COM DSEG:06F5H
				; Mask to apply to byte at 0B800H:[PIXOFS]
				; to cover current pixel

ATRPAT	DB	?		; From BASICA.COM DSEG:06F6H
				; Bit pattern for current graphics
				; attribute, to be masked with ATRMSK

BORPAT	DB	?		; From BASICA.COM DSEG:0842H
				; Bit pattern for border attribute for PAINT,
				; to be masked with ATRMSK

PGTSHF	DB	?		; From BASICA.COM DSEG:0857H
				; For PUT or GET, Number of bits to shift
				; graphics data so that layout in GW-BASIC
				; memory aligns with layout in video memory

PGTARY	DW	?		; From BASICA.COM DSEG:0859H
				; For PUT or GET, pointer to byte array to
				; PUT from or GET into

PGTACT	DW	?		; From BASICA.COM DSEG:085BH
				; For PUT or GET, pointer to function to
				; apply action verb (PRESET, XOR, etc.) to
				; pixel data

CBFSEG	DW	?		; Segment of COM buffer (i.e. CBFSEG:0)

	EXTRN	ACTPAG:BYTE,CRTWID:BYTE
	EXTRN	WDOTOP:BYTE,WDOLFT:BYTE,WDOBOT:BYTE,WDORGT:BYTE
	EXTRN	CRTWID:BYTE,LINCNT:BYTE
	EXTRN	CSRX:BYTE,CSRY:BYTE,F_EDIT:BYTE,F_INST:BYTE
	EXTRN	CSAVEA:WORD,CSAVEM:BYTE
	EXTRN	MAXDEL:WORD
DSEG	ENDS

SSEG	SEGMENT STACK 'STACKSG'
	DB	128D DUP(?)	; (?) Stash a startup stack here
SSEG	ENDS
	END

	.RADIX	8

CSEG	SEGMENT PUBLIC 'CODESG'
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   OEMCBK - Ctrl-Break & Pause handling & emulation

COMMENT *
Written by: TK Chia <https://github.com/tkchia>

It is sometimes useful to halt or pause the execution of a running BASIC
program.  On older PCs with a physical "Break"/"Pause" key, a physical "Scroll
Lock" key, or a physical "Numeric Lock" key, one can press
  - Ctrl-Break or Ctrl-ScrLock to halt a program, or
  - Pause or Ctrl-NumLock to pause a program.
However, modern keyboards may lack such keys.

To address this, I arrange to hook INT 15H, function 4FH --- which modern
PCs should support --- to intercept key strokes received by IRQ 1, &
simulate the effects of
  - a Ctrl-Break when Ctrl-Shift-B is pressed, or
  - a Pause or Ctrl-NumLock when Ctrl-Shift-P is pressed.
The INT 15H AH = 4FH hook also converts a physical Ctrl-NumLock into a
special key code which the KEYINP routine can more easily handle.

(I chose Ctrl-Shift-B & Ctrl-Shift-P because reportedly some laptops use Fn-B
& Fn-P to stand for the "Break" & "Pause" keys respectively.  See e.g.
https://forum.thinkpads.com/viewtopic.php?t=105807 .)
        *
	.SALL

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	MSDCCF:BYTE
	EXTRN	EVENT:BYTE
DSEG	ENDS

; Internal function: INT 1BH service routine (for Ctrl-Break handling).
;
ISRCBK:	PUSH	AX
	PUSH	DS
CBKDS:	MOV	AX,0			; This is patched to say DSEG
	MOV	DS,AX
	ASSUME	DS:DSEG
	MOV	MSDCCF,-1		; Record ^Break event
	XOR	AX,AX			; "Reap" ^Break flag from BIOS data
	MOV	DS,AX			; area
	ASSUME	DS:NOTHING
	AND	BYTE PTR DS:0471H,01111111B
	POP	DS
	POP	AX
CBOISR:	DB	0EAH			; Continue to original INT 1BH ISR
	DD	-1

; Internal function: INT 15H service routine (for cassette I/O & various
; miscellaneous services).
;
ISRMSC:	PUSHF
	CMP	AH,4FH			; Are we intercepting a key press or
	JZ	IMKMAP			; key release?
	POPF				; If not, just do a far JMP to the
IMOISR:	DB	0EAH			; original INT 15H ISR
	DD	-1
IMKMAP:	STC				; We are intercepting a key press/
	PUSH	CS			; release: ask the original ISR to
	CALL	IMOISR			; map the key code first
					; (NOTE: flags were already pushed)
	JNC	IMKFN4			; If key stroke is to be ignored,
					; then return immediately
	CMP	AL,30H			; Otherwise... check if we are looking
	JNZ	IMKMP2			; at a "B" key press
	PUSH	DS
	PUSH	AX
	CALL	TSTCS			; "B": Check for Ctrl-Shift
	JB	IMKFN2
	POP	AX
	MOV	AX,DS:041AH		; Ctrl-Shift-B!  Clear keyboard buffer
	MOV	DS:041CH,AX
	PUSH	CX
	MOV	AH,05H			; Stuff "null" key stroke into buffer
	XOR	CX,CX
	INT	16H
	INT	1BH			; Run ^Break handler for good measure
IMKFIN:	POP	CX			; We are done
	POP	DS
	CLC
	STI
	RETF	2
IMKFN2:	POP	AX			; Unrecognized key code; just return
	POP	DS			; system-mapped scan code
IMKFN3:	STC
IMKFN4:	STI
	RETF	2
IMKMP2:	JA	IMKMP3
	CMP	AL,19H			; Check for "P" key press
	JNZ	IMKFN3
	PUSH	DS
	PUSH	AX
	CALL	TSTCS			; "P": Check for Ctrl-Shift
	JB	IMKFN2
IMKPAU:	POP	AX
	PUSH	CX
	MOV	AH,05H			; Ctrl-Shift-P or Ctrl-NumLock!
	MOV	CX,1D00H		; Insert special key code into
	INT	16H			; keyboard buffer --- 1DH is actually
					; scan code for Ctrl, which will
					; normally not go into buffer
IMDS:	MOV	AX,0			; This is patched to say DSEG
	MOV	DS,AX
	ASSUME	DS:DSEG
	MOV	EVENT,1			; Say we have an event to handle
	ASSUME	DS:NOTHING
	JMP	IMKFIN			; We are done
IMKMP3:	CMP	AL,45H			; Check for NumLock
	JNZ	IMKFN3
	PUSH	DS
	PUSH	AX
	CALL	TSTCS			; NumLock: get Ctrl & Shift state
	TEST	AL,00000100B		; Handle this as long as we have Ctrl
	JZ	IMKFN2
	JMP	IMKPAU

TSTCS:	XOR	AX,AX
	MOV	DS,AX
	MOV	AL,DS:0417H		; Retrieve relevant parts of
	AND	AL,00000111B		; shift state
	CMP	AL,00000101B		; Check for Ctrl-Shift --- either
	RET				; left or right Shift will do

; Internal function: start Ctrl-Break & Pause emulation
;
PUBLIC	CBKSTA
CBKSTA:	MOV	WORD PTR CS:CBKDS+1,DS	; Patch our INT 1BH & 15H to set DS
	MOV	WORD PTR CS:IMDS+1,DS
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	MOV	BX,1BH*4		; Store original INT 1BH vector
	MOV	AX,[BX]
	MOV	WORD PTR CS:CBOISR+1,AX
	MOV	AX,2[BX]
	MOV	WORD PTR CS:CBOISR+3,AX
	CLI				; Install our own INT 1BH code
	MOV	WORD PTR [BX],OFFSET ISRCBK
	MOV	WORD PTR 2[BX],CS
	STI
	MOV	BL,15H*4		; Store original INT 15H vector
	MOV	AX,[BX]
	MOV	WORD PTR CS:IMOISR+1,AX
	MOV	AX,2[BX]
	MOV	WORD PTR CS:IMOISR+3,AX
	CLI				; Install our own INT 15H code
	MOV	WORD PTR [BX],OFFSET ISRMSC
	MOV	WORD PTR 2[BX],CS
	STI
CBKTR1:	POP	DS
	RET

; Internal function: do cleanup for Ctrl-Break & Pause handling when we exit
;
PUBLIC	CBKTRM
CBKTRM:	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	MOV	AX,WORD PTR CS:IMOISR+1	; Restore the INT 15H vector, unless
	MOV	DX,WORD PTR CS:IMOISR+3	; there was none saved
	CMP	AX,-1
	JNZ	CBKTR2
	CMP	DX,AX
	JZ	CBKTR1
CBKTR2:	CLI
	MOV	BX,15H*4
	MOV	[BX],AX
	MOV	2[BX],DX
	MOV	AX,WORD PTR CS:CBOISR+1	; Restore the INT 1BH vector too
	MOV	(1BH*4-15H*4)[BX],AX
	MOV	AX,WORD PTR CS:CBOISR+3
	MOV	(1BH*4-15H*4+2)[BX],AX
					; Clear any ^Break flag
	AND	BYTE PTR DS:0471H,01111111B
	STI
	POP	DS
	RET

CSEG	ENDS
	END

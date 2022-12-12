	.RADIX	8

CSEG	SEGMENT PUBLIC 'CODESG'
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   OEMCBK - Ctrl-Break emulation for keyboards without a Break key

COMMENT *
Written by: TK Chia <https://github.com/tkchia>

It is sometimes useful to halt the execution of a running BASIC program.  On
older PCs with a physical "Break"/"Pause" key or a physical "Scroll Lock"
key, one can press Ctrl-Break or Ctrl-ScrLock to do this.  However, modern
keyboards may lack such keys.

To address this, I arrange to hook INT 15H, function 4FH --- which modern
PCs should support --- to intercept key strokes received by IRQ 1, &
simulate the effects of a Ctrl-Break when Ctrl-Shift-B is pressed.

(I chose Ctrl-Shift-B because reportedly some laptops use Fn-B to stand for a
"Break" key.  See e.g. https://forum.thinkpads.com/viewtopic.php?t=105807 .)
        *
	.SALL

; Internal function: INT 15H service routine (for cassette I/O & various
; miscellaneous services).
;
ISRMSC:	PUSHF
	CMP	AX,4F30H		; Are we intercepting pressing of
	JZ	IMKMAP			; "B" key (scan code 30H)?
	POPF				; If not, just do a far JMP to the
IMOISR:	DB	0EAH			; original INT 15H ISR
	DD	-1
IMKMAP:	POPF
	PUSH	DS
	PUSH	AX
	XOR	AX,AX			; Check if Ctrl & Shift are both
	MOV	DS,AX			; pressed --- either left or right
	MOV	AL,DS:0417H		; Shift will do
	AND	AL,00000111B
	SUB	AL,00000101B
	JC	IMOIR2
	POP	AX			; Ctrl-Shift-B!  Clear keyboard buffer
	MOV	AX,DS:041AH
	MOV	DS:041CH,AX
	PUSH	CX
	MOV	AH,05H			; Stuff "null" key stroke into buffer
	XOR	CX,CX
	INT	16H
	POP	CX
	OR	DS:0471H,10000000B	; Signal ^Break in BIOS data area
	POP	DS
	INT	1BH			; Run ^Break handler for good measure
	STI				; We are done
	CLC
	RETF	2
IMOIR2:	POP	AX
	POP	DS			; No Ctrl-Shift-B, continue to
	STC				; original ISR
	JMP	IMOISR

; Internal function: start Ctrl-Break emulation
;
PUBLIC	CBKSTA
CBKSTA:	PUSH	DS
	XOR	AX,AX			; Get & store original INT 15H vector
	MOV	DS,AX
	MOV	BX,15H*4
	MOV	AX,[BX]
	MOV	WORD PTR CS:IMOISR+1,AX
	MOV	AX,2[BX]
	MOV	WORD PTR CS:IMOISR+3,AX
	CLI				; Now install our own INT 15H code
	MOV	WORD PTR [BX],OFFSET ISRMSC
	MOV	WORD PTR 2[BX],CS
	STI
CBKTR1:	POP	DS
	RET

; Internal function: do cleanup for Ctrl-Break emulation when we are exiting
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
	MOV	DS:(15H*4),AX
	MOV	DS:(15H*4)+2,DX
	STI
	POP	DS
	RET

CSEG	ENDS
	END

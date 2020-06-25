	.RADIX	8

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG,DS:DSEG

INCLUDE	OEM.H

	TITLE   OEMEV - Platform code for peripherals that need event handling

COMMENT *
Written by: TK Chia <https://github.com/tkchia>

This currently only handles joysticks.  FIXME: also handle light pen input
and serial port I/O.
        *
	.SALL

; Internal function: initialize event handling
; This should only be called after DSEG has been moved to its final location
;
PUBLIC	EVSTA
EVSTA:	PUSH	ES
	XOR	AX,AX			; Get & store original INT 1CH
	MOV	ES,AX			; (system timer tick) vector
	MOV	BX,1CH*4
	MOV	AX,ES:[BX]
	MOV	WORD PTR OIRTIC,AX
	MOV	AX,ES:2[BX]
	MOV	WORD PTR OIRTIC+2,AX
	MOV	WORD PTR CS:ITICDS+1,DS	; Patch our code to set DS right
	CLI				; Now install our own INT 1CH handler
	MOV	WORD PTR ES:[BX],OFFSET ISRTIC
	MOV	WORD PTR ES:2[BX],CS
	STI
	POP	ES
	RET

; Internal function: do cleanup for event handling when we are exiting
;
PUBLIC	EVTRM
EVTRM:	PUSH	ES
	XOR	AX,AX
	MOV	ES,AX			; Restore the INT 1CH vector
	MOV	AX,WORD PTR OIRTIC
	CLI
	MOV	ES:(1CH*4),AX
	MOV	AX,WORD PTR OIRTIC+2
	MOV	ES:(1CH*4)+2,AX
	STI
	POP	ES
	RET

; Internal function: INT 1CH (system timer tick) service routine.
;
ISRTIC:	PUSH	DS
	PUSH	AX
	PUSH	DX
ITICDS:	MOV	AX,0			; This is patched to say DSEG
	MOV	DS,AX
	MOV	DX,0201H		; Test if any joystick button is
	IN	AL,DX			; pressed; if not, just hand over
	AND	AL,11110000B		; to the original INT 1CH
	CMP	AL,11110000B
	JNZ	TICSTR
TICFWD:	POP	DX
	POP	AX
	PUSHF
	CALL	DWORD PTR OIRTIC
	POP	DS
	IRET
TICSTR:	MOV	EVENT,1			; Otherwise say that an event has
	AND	TRGLAT,AL		; occurred, and also latch the
	JMP	SHORT TICFWD		; buttons pressed

; Poll for events
;
; OUTPUT
;	FLAGS		ZF=1 No events occurred since last call to POLLEV
;			ZF=0 An event occurred
; REGISTERS AFFECTED
;	AL (?)
;
PUBLIC	POLLEV
POLLEV:	SHR	EVENT,1
	SBB	AL,AL
	RET

; Read the current status or latched status of a joystick button ---
; implement STRIG function
;
; INPUT
;	AL		Joystick button (0, 1, ..., NMSTRT - 1 (= 3))
;			0 1st button of joystick A
;			1 2nd button of joystick A
;			2 1st button of joystick B
;			3 2nd button of joystick B
;	AH		0 Get current status
;			1 Get latched status --- say "pressed" if button was
;			  pressed at any time after the last RDTRIG call
;			  with AH = 1
; OUTPUT
;	AL		0 Not pressed
;			1 Pressed
; REGISTERS AFFECTED
;	(?)
;
PUBLIC	RDTRIG
RDTRIG:	CMP	AL,4
	JA	TRGBAD
	PUSH	CX
	PUSH	DX
	MOV	CX,AX
	ADD	CL,5
	MOV	DX,0201H
	IN	AL,DX
	TEST	AH,AH
	JZ	TRGCUR
	CLI				; If we need the latched status,
	AND	AL,TRGLAT		; then things are a bit more
	MOV	AH,10000000B		; complex...
	ROL	AH,CL
	OR	TRGLAT,AH
	STI
TRGCUR:	SHR	AL,CL
	SBB	AL,AL
	INC	AX
	POP	DX
	POP	CX
	RET
TRGBAD:	XOR	AL,AL
	RET

; Read an X or Y coordinate of a joystick --- implement STICK function
;
; INPUT
;	AL		0 X coordinate of joystick A --- this implementation
;			  also retrieves and stores the other coordinates below
;			1 Y coordinate of joystick A
;			2 X coordinate of joystick B
;			3 Y coordinate of joystick B
; OUTPUT
;	BX		Requested coordinate
;	FLAGS		CF=0 OK
;			CF=1 Error
; REGISTERS AFFECTED
;	(?)
;
PUBLIC	RDSTIK
RDSTIK:	CMP	AL,4
	JA	STKBAD
	PUSH	AX
	CBW
	DEC	AX
	JS	STKGXA
	JZ	STKGYA
	DEC	AX
	JZ	STKGXB
	MOV	BX,STIKYB
	JMP	SHORT STKFIN
STKGXB:	MOV	BX,STIKXB
	JMP	SHORT STKFIN
STKGYA:	MOV	BX,STIKYA
STKFIN:	POP	AX
	CLC
	RET
STKGXA:	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	BP
	MOV	DX,0201H
	MOV	CX,7FFFH
	XOR	BX,BX			; BX = X of A
	XOR	SI,SI			; SI = Y of A
	XOR	DI,DI			; DI = X of B
	XOR	BP,BP			; BP = Y of B
	CLI
	; Jim Leonard says (https://github.com/tkchia/GW-BASIC/issues/4):
	; "some adapters won't work unless the one-shot sent to 201h has all
	; bits set."  Luckily, AL is already 11111111B at this point, from
	; the first DEC AX above.
	OUT	DX,AL
STKLOP:	IN	AL,DX
	ROR	AL,1
	ADC	BX,0
	ROR	AL,1
	ADC	SI,0
	ROR	AL,1
	ADC	DI,0
	ROR	AL,1
	ADC	BP,0
	TEST	AL,11110000B
	LOOPNZ	STKLOP
	STI
	MOV	STIKYA,SI
	MOV	STIKXB,DI
	MOV	STIKYB,BP
	POP	BP
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	AX
	CLC
	RET
STKBAD:	STC
	RET

CSEG	ENDS

DSEG	SEGMENT PUBLIC 'DATASG'

OIRTIC	DD	0			; Original INT 1CH vector

STIKYA	DW	0			; Y coordinate for joystick A as
					; stored by STICK(0)
STIKXB	DW	0			; X coordinate for joystick B as
					; stored by STICK(0)
STIKYB	DW	0			; Y coordinate for joystick B as
					; stored by STICK(0)
TRGLAT	DB	11110000B		; Latch of joystick buttons pressed
					; since the last RDTRIG call; this
					; is in the same format as the input
					; from port 0201H

EVENT	DB	0			; Whether an event has occurred
					; since the last time we polled for
					; an event; _only_ the lowest bit
					; of this byte should be set!

DSEG	ENDS
	END

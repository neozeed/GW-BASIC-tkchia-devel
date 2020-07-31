	.RADIX	8

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG,DS:DSEG

INCLUDE	OEM.H

	TITLE   OEMEV - Platform code for peripherals that need event handling

COMMENT *
Written by: TK Chia <https://github.com/tkchia>

This currently only handles joysticks and light pens.  FIXME: (1) also
handle serial port I/O; (2) properly test the joystick and light pen code.

Many of the routines missing from the GW-BASIC code release are
present in Microsoft's previous release of MS-DOS v1.25 BASICA.COM
(https://github.com/microsoft/MS-DOS/tree/master/v1.25/bin),
though only in binary form.  These are indicated.
        *
	.SALL

	EXTRN	FCERR:NEAR

; Internal function: initialize event handling
; This should only be called after DSEG has been moved to its final location
;
PUBLIC	EVSTA
EVSTA:	MOV	CX,5			; Test if we can get the joystick
BIOJY1:	MOV	AH,84H			; status through the BIOS
	MOV	DX,1
	INT	15H
	JC	BIOJY2
	OR	AX,BX			; If the BIOS does not report an
	OR	AX,CX			; error but return all (X, Y)'s as
	OR	AX,DX			; 0, retry a few more times
	JNZ	BIOJY3
	HLT
	LOOP	BIOJY1
BIOJY2:	PUSH	ES
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
BIOJY3:					; If the BIOS returns something
					; interesting for the joystick
					; status, then update our function
					; pointers to use the BIOS
	MOV	RDTRGP,OFFSET CSEG:RDTRG1
	MOV	RDSTKP,OFFSET CSEG:RDSTK1
	JMP	SHORT BIOJY2

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

; Internal function: read joystick buttons via port I/O
;
; OUTPUT
;	AL		State of joystick buttons
;
; REGISTERS AFFECTED
;	AH (?), DX
;
RDTRG0:	MOV	DX,0201H
	IN	AL,DX
	RET

; Internal function: read joystick buttons via BIOS
;
; OUTPUT
;	AL		State of joystick buttons
;
; REGISTERS AFFECTED
;	AH, DX
;
RDTRG1:	MOV	AH,84H
	XOR	DX,DX
	INT	15H
	RET

; Internal function: INT 1CH (system timer tick) service routine
;
ISRTIC:	PUSH	DS
	PUSH	AX
	PUSH	DX
ITICDS:	MOV	AX,0			; This is patched to say DSEG
	MOV	DS,AX
	CALL	WORD PTR RDTRGP		; Test if any joystick buttons are
	AND	AL,11110000B		; pressed; if so, handle them
	CMP	AL,11110000B		; (FIXME: is it actually OK to maybe
	JNZ	TICSTR			; call the BIOS within this ISR?)
TICPN1:	CMP	PENENA,0		; If light pen support is on, then
	JNZ	TICPN2			; handle light pen input
TICFWD:	POP	DX
	POP	AX
	PUSHF
	CALL	DWORD PTR OIRTIC
	POP	DS
	IRET
TICSTR:	MOV	EVENT,1			; Joystick button pressed: say that
	AND	TRGLAT,AL		; an event occurred, and also latch
	JMP	SHORT TICPN1		; the buttons pressed
TICPN2:	CALL	TICPEN
	JMP	SHORT TICFWD

; Modified from BASICA.COM CSEG:16C0H
; Read light pen inputs from within the INT 1CH timer tick handler
;
; REGISTERS AFFECTED
;	AX, DX
;
TICPEN:	PUSH	BX
	PUSH	CX
	MOV	AH,04H
	INT	10H
	OR	AH,AH
	JZ	SHORT NOPEN
	MOV	PEN4V,BX
	MOV	PEN5V,CH
	MOV	PEN98VM,DX
NOPEN:	MOV	AL,PENPRV
	XOR	AL,AH
	JZ	TICPFI
	OR	AH,AH
	MOV	PENPRV,AH
	JZ	TICPFI
	MOV	PEN0V,-1
	MOV	PEN1V,BX
	MOV	PEN2V,CH
	MOV	PEN76VM,DX
	MOV	EVENT,1
TICPFI:	POP	CX
	POP	BX
	RET

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

; Read a light pen status, or enable or disable light pen support
; INPUT
;	AL		0---9 Read status, AL is parameter to PEN function
;			0FEH Enable light pen support (PEN ON)
;			0FFH Disable light pen support (PEN OFF)
; OUTPUT
;	BX		Requested light pen status, if 0 <= AL <= 9
; REGISTERS AFFECTED
;	(?)
;
PUBLIC	RDPEN
RDPEN:	CBW
	INC	AX
	JS	ENAPEN
	JZ	DISPEN
	CMP	PENENA,0
	JZ	PENERR
	MOV	BX,AX
	SHL	BX,1
	JMP	CS:(PENTAB-2)[BX]
PENERR:	JMP	FCERR
ENAPEN:	MOV	PENENA,-1
	RET
DISPEN:	MOV	PENENA,0
	RET
PEN0F:	XOR	AL,AL
	XCHG	PEN0V,AL
	CBW
	XCHG	BX,AX
	RET
PEN1F:	MOV	BX,PEN1V
	RET
PEN2F:	MOV	BL,PEN2V
PENRT1:	XOR	BH,BH
	RET
PEN3F:	PUSH	CX			; Return current pen switch state
	PUSH	DX
	MOV	AH,04H
	INT	10H
	POP	DX
	POP	CX
	ADD	AH,-1
	SBB	BX,BX
	RET
PEN4F:	MOV	BX,PEN4V
	RET
PEN5F:	MOV	BL,PEN5V
	JMP	SHORT PENRT1
PEN6F:	MOV	AL,BYTE PTR PEN76VM+1
PENRT2:	XOR	AH,AH
	INC	AX
	XCHG	BX,AX
	RET
PEN7F:	MOV	AL,BYTE PTR PEN76VM
	JMP	SHORT PENRT2
PEN8F:	MOV	AL,BYTE PTR PEN98VM+1
	JMP	SHORT PENRT2
PEN9F:	MOV	AL,BYTE PTR PEN98VM
	JMP	SHORT PENRT2

PENTAB	DW	OFFSET PEN0F,OFFSET PEN1F,OFFSET PEN2F,OFFSET PEN3F
	DW	OFFSET PEN4F,OFFSET PEN5F,OFFSET PEN6F,OFFSET PEN7F
	DW	OFFSET PEN8F,OFFSET PEN9F

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
	CALL	WORD PTR RDTRGP
	TEST	CH,CH
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

; Internal function: read joystick coordinates via port I/O
;
; OUTPUT
;	BX		X coordinate of joystick A
;	STIKYA, STIKXB, STIKYB are updated
; REGISTERS AFFECTED
;	AX
;
RDSTK0:	PUSH	CX
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
	RET

; Internal function: read joystick coordinates via BIOS
;
; OUTPUT
;	BX		X coordinate of joystick A
;	STIKYA, STIKXB, STIKYB are updated
; REGISTERS AFFECTED
;	AX
;
RDSTK1:	PUSH	CX
	PUSH	DX
	MOV	AH,84H
	MOV	DX,1
	INT	15H
	XCHG	BX,AX
	MOV	STIKYA,AX
	MOV	STIKXB,CX
	MOV	STIKYB,DX
	POP	DX
	POP	CX
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
STKGXA:	CALL	WORD PTR RDSTKP
	POP	AX
	CLC
	RET
STKBAD:	STC
	RET

CSEG	ENDS

DSEG	SEGMENT PUBLIC 'DATASG'

OIRTIC	DD	0			; Original INT 1CH vector

RDTRGP	DW	OFFSET CSEG:RDTRG0	; Pointer to function to read the
					; joystick buttons' state
RDSTKP	DW	OFFSET CSEG:RDSTK0	; Pointer to function to read the
					; joystick coordinates
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

					; From BASICA.COM DSEG:34H--40H
PENENA	DB	0			; Whether light pen support is on
PEN0V	DB	0			; Whether pen was down since last
					; poll --- value to return for PEN(0)
PENPRV	DB	0			; Used internally by TICPEN to track
					; changes in pen activation state
PEN1V	DW	0			; X coordinate when pen was last
					; activated --- PEN(1) value
PEN2V	DB	0			; Y coordinate when pen was last
					; activated --- PEN(2) value
PEN4V	DW	0			; Last known valid X coordinate for
					; pen --- PEN(4) value
PEN5V	DB	0			; Last known valid Y coordinate for
					; pen --- PEN(5) value
PEN76VM	DW	0			; Character column & row when pen was
					; last activated --- PEN(7) value
					; minus 1, PEN(6) value minus 1
PEN98VM	DW	0			; Last known valid character column
					; & row --- PEN(9) value minus 1,
					; PEN(8) value minus 1

EVENT	DB	0			; Whether an event has occurred
					; since the last time we polled for
					; an event; _only_ the lowest bit
					; of this byte should be set!

DSEG	ENDS
	END

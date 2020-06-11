	.RADIX	8

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG,DS:DSEG

INCLUDE	OEM.H

	TITLE   OEMSND - Platform-specific routines for audio support

COMMENT *
(Re-)written by: TK Chia <https://github.com/tkchia>

Many of the sound routines are implemented in Microsoft's release of MS-DOS
v1.25 BASICA.COM (https://github.com/microsoft/MS-DOS/tree/master/v1.25/bin),
in binary form.

However, there are many differences in the internal code and data structures
between BASICA.COM and this GW-BASIC, so the routines cannot simply be copied
here wholesale.
        *
	.SALL

	EXTRN	INITQ:NEAR,NUMQ:NEAR,LFTQ:NEAR,GETQ:NEAR,PUTQ:NEAR

	SNDQSZ	EQU	80H		; Size of the sound queue in bytes
					; Each musical note takes up 4 bytes

	P0PULS	EQU	0BA7H		; Number of PIT counter 0 pulses per
					; IRQ 0 we want for our own IRQ 0
					; handler; the value is 1,193,181 / 400
					; rounded off, which results in a
					; timer that is triggered about 400
					; times per second

; Internal function: really finish initializing sound support
; This should only be called after DSEG has been moved to its final location
;
PUBLIC	SNDSTA
SNDSTA:	PUSH	ES
	XOR	AX,AX			; Get & store original IRQ 0 vector
	MOV	ES,AX
	MOV	BX,08H*4
	MOV	AX,ES:[BX]
	MOV	WORD PTR OIRQ0,AX
	MOV	AX,ES:2[BX]
	MOV	WORD PTR OIRQ0+2,AX
	MOV	WORD PTR CS:IRQ0DS+1,DS	; Patch our IRQ 0 code to set DS right
	CLI				; Now install our own IRQ 0 code
	MOV	WORD PTR ES:[BX],OFFSET IRQ0
	MOV	WORD PTR ES:2[BX],CS
	STI
	POP	ES
	RET

; Internal function: do cleanup for this sound module when we are exiting
;
PUBLIC	SNDTRM
SNDTRM:	MOV	AL,-1			; Immediately turn off sound
	CALL	DONOTE
	PUSH	ES
	XOR	AX,AX
	MOV	ES,AX			; Restore the IRQ 0 vector
	MOV	AX,WORD PTR OIRQ0
	CLI
	MOV	ES:(08H*4),AX
	MOV	AX,WORD PTR OIRQ0+2
	MOV	ES:(08H*4)+2,AX
	STI
	POP	ES
	RET

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	SNDTIC:BYTE		; Cheat a bit: treat SNDTIC as a flag
	EXTRN	SNDBAS:WORD		; saying whether we are running on
					; a slow (18.2 Hz) or a fast
					; (400 Hz) IRQ 0, & SNDOUT as the
					; actual modulo counter for figuring
					; out when to run the original
					; IRQ 0 handler
DSEG	ENDS

; Internal function: IRQ 0 service routine.
;
IRQ0:	PUSH	AX
	PUSH	DS
IRQ0DS:	MOV	AX,0			; This is patched to say DSEG
	MOV	DS,AX
	CMP	SNDTIC,0		; If IRQ 0 is running at the normal
	JZ	I0SND			; rate (18.2 Hz), then just hand
I0FWD:	PUSHF				; over to the original IRQ handler
	CALL	DWORD PTR OIRQ0
I0RET:	POP	DS
	POP	AX
	IRET
I0SND:	MOV	AX,NOTTIC		; If we are in the middle of playing
	TEST	AX,AX			; a note, then keep playing it
	JZ	I0NXT
	DEC	AX
	MOV	NOTTIC,AX
	JZ	I0NXT
I0FWD2:	ADD	SNDBAS,P0PULS		; Hand over to the original IRQ
	JC	I0FWD			; handler about 18.2 times a second;
I0EOI:	MOV	AL,00100000B		; other times, just emit our own EOI
	OUT	20H,AL
	POP	DS
	POP	AX
	IRET
I0NXT:	PUSH	BX			; Nope, we are not playing a note now
	PUSH	SI
	MOV	SI,OFFSET SNDQDS	; Try to get a note from the queue
	CALL	NUMQ			; & play it as the current note
	CMP	AX,4
	JB	I0NON1
	CALL	GETQ			; First get the PIT pulse count &
	OUT	42H,AL			; send it to PIT 2
	MOV	AH,AL
	CALL	GETQ
	OUT	42H,AL
	ADD	AX,-1			; Handle the case where we have a
	SBB	AH,AH			; "rest" note (PIT pulse count = 0)!
	IN	AL,61H
	AND	AX,0000001111111100B
	OR	AL,AH
	OUT	61H,AL
	CALL	GETQ			; Then get the duration --- assumed
	XCHG	AH,AL			; to be non-zero --- & store it
	CALL	GETQ
	XCHG	AH,AL
	MOV	NOTTIC,AX
	POP	SI
	POP	BX
	JMP	I0FWD2			; Dispatch to the original IRQ 0
					; vector if necessary
I0NON1:	POP	SI			; No more notes to play; turn off
	POP	BX			; sound
	IN	AL,61H
	AND	AL,11111100B
	OUT	61H,AL
I0NON2:	ADD	SNDBAS,P0PULS		; Reset PIT 0 to 18.2 Hz once we
	JNC	I0EOI			; reach an INT 1CH timer tick
	MOV	SNDTIC,-1
	XOR	AL,AL
	OUT	40H,AL
	OUT	80H,AL
	OUT	40H,AL
	JMP	I0FWD

; Modified from BASICA.COM CSEG:164BH (SNDRST ?) & CSEG:0FF4H (DOSND ?)
; Either (1) play a note, or (2) queue a note to be played in the
; background, or (3) turn off sound & clear the sound queue
;
; INPUT
;	AL		0 Play note in foreground
;			1 Play note in background
;			-1 Reset sound
;	CX		Note frequency
;	DX		Note duration, in units of 1/400 seconds (2.5 ms)
;			(the GWSTS.ASM comments on the time unit are
;			extremely confusing --- & wrong in many places ---
;			but yes, it is 2.5 ms)
; OUTPUT
;	FLAGS		CF=0 Success
;			CF=1 Error
; REGISTERS AFFECTED
;	(?)
;
PUBLIC	DONOTE
DONOTE:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	TEST	AL,AL
	JNS	HVNOTE
	MOV	SI,OFFSET SNDQDS	; Input AL = -1: reset sound
	MOV	BX,OFFSET SNDQUE
	CLI
	IN	AL,61H			; Turn off the PC speaker
	AND	AL,11111100B
	OUT	61H,AL
	XOR	AL,AL			; Reset IRQ 0 to 18.2 Hz
	OUT	40H,AL
	OUT	80H,AL
	OUT	40H,AL
	MOV	SNDTIC,-1
	MOV	NOTTIC,0
	MOV	AX,SNDQSZ
	CALL	INITQ			; Initialize the sound queue
	STI
	JMP	SHORT FINNOT
HVNOTE:	PUSHF				; Input AL = 0 or 1: play note
	MOV	SI,OFFSET SNDQDS	; If the duration is 0, handle it
	TEST	DX,DX			; specially...
	JZ	MAYFLS
	PUSH	DX			; Duration is not 0!
	PUSH	CX
	CALL	SWAIPQ			; Wait until we can add a new sound
	POP	CX
	MOV	AX,CX
	JCXZ	HVREST
	MOV	AX,34DDH		; Convert frequency (CX) into PIT pulse
	CWD				; count; assume frequency is sane
	MOV	BX,CX
	SHR	BX,1
	ADD	AX,BX
	ADC	DX,0012H
	DIV	CX			; AX = 1,193,181 / CX, rounded off
HVREST:	CLI
	CALL	PUTQ			; Enqueue the PIT pulse count
	MOV	AL,AH
	CALL	PUTQ
	POP	AX			; Enqueue the note duration
	CALL	PUTQ
	MOV	AL,AH
	CALL	PUTQ
	CMP	SNDTIC,-1		; If necessary, reprogram PIT 0 to
	JNZ	MAYFLS			; 400 Hz
	MOV	SNDTIC,0
	MOV	AL,P0PULS AND 0FFH
	OUT	40H,AL
	OUT	80H,AL
	MOV	AL,P0PULS SHR 8D
	OUT	40H,AL
MAYFLS:	POPF
	JNZ	FINNOT			; If input AL = 1, just queue the note
	JMP	SHORT FLUSH2		; Otherwise wait for our new note to
FLUSH1:	HLT				; finish
FLUSH2:	CALL	NUMQ
	TEST	AX,AX
	JNZ	FLUSH1
	JMP	SHORT FLUSH4
FLUSH3:	HLT
FLUSH4:	CMP	NOTTIC,1
	JA	FLUSH3
FINNOT:	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	CLC
	RET

; Wait until we can put a new sound into the sound queue
;
; INPUT
;	DS:[SI]		Sound queue descriptor structure
; REGISTERS AFFECTED
;	AX
;
SWAIPQ:	JMP	SHORT SWLOP2
SWLOP1:	HLT
SWLOP2:	CALL	LFTQ
	CMP	AX,4
	JB	SWLOP1
	RET

CSEG	ENDS

DSEG	SEGMENT PUBLIC 'DATASG'

OIRQ0	DD	?			; Original IRQ 0 vector
SNDQDS	DB	8D DUP(?)		; Descriptor structure for sound queue
SNDQUE	DB	SNDQSZ DUP(?)		; Buffer for sound queue
NOTTIC	DW	0			; Number of fast timer ticks left
					; for currently playing note

DSEG	ENDS
	END

	.RADIX	8

DGROUP	GROUP	DSEG

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG,DS:DSEG

	TITLE   GIODSX - Additional disk I/O routines for MS-DOS 2+

COMMENT *
Written by: TK Chia <https://github.com/tkchia>
        *
	INCLUDE	MSDOS2U

	.SALL

	EXTRN	DERIER:NEAR

; TODO

	PUBLIC	DSKINI
DSKINI:	PUSH	SI
	PUSH	DS
	PUSH	ES
	CALLOS	C_VERS		; Get the MSDOS version (which may be modified
	PUSH	AX		; by SETVER), to get an idea of which
				; variants of List of Lists to probe for
	CALLOS	C_IVAR		; Get the List of Lists
	POP	AX
	CLD
				; Go to the first System File Table &
				; sanity-check it; expect at least 2 entries
				; in the SFT so that we can try to detect
				; the size of each SFT entry
	LDS	SI,ES:[BX+IV_SFT]
	CMP	SI,-1
	JZ	DKIERR
	CMP	WORD PTR [SI+FT_NF],2
	JB	DKIERR
	CMP	AL,4		; See which variants of List of Lists to
	JAE	TRYX		; try, based on the reported version
	CMP	AL,3
	JZ	TRY3X
	MOV	AX,IV_NL2+CDV_DN ; Case: true MSDOS version might be
				; anything >= 2
	CALL	ISNUL		; Check if there is a NUL device driver
				; header at the appropriate offset into the
				; List of Lists
	JNZ	TRY30		; If not, try MSDOS 3+ structures
	MOV	AL,FT_ENT+F2_FN	; Check if the first two SFT entries are for
	CALL	ISSTD		; CON, AUX, or PRN
	JNZ	TRY30
	MOV	AL,FT_ENT+F2SIZ+F2_FN
	CALL	ISSTD
	JZ	OK2X
TRY30:	MOV	AL,FT_ENT+F30_FN ; Check first two SFT entries for DOS 3.0
	CALL	ISSTD
	JNZ	TRY31
	MOV	AL,FT_ENT+F30SIZ+F30_FN
	CALL	ISSTD
	JZ	OK30
TRY31:	MOV	AL,FT_ENT+FX_FN	; Check first SFT entry for DOS 3.1+
	CALL	ISSTD
	JNZ	DKIERR
				; Check second SFT entry for DOS 3.1--3.3x
	MOV	AL,FT_ENT+F3XSIZ+FX_FN
	CALL	ISSTD
	JZ	OK3X
TRYXC:				; Check second SFT entry for DOS 4+
	MOV	AL,FT_ENT+FXSIZ+FX_FN
	CALL	ISSTD
	JNZ	DKIERR
OKX:	; TODO
OK2X:	; TODO
OK30:	; TODO
OK3X:	; TODO
	POP	ES
	POP	DS
	POP	SI
	RET
TRY3X:	PUSH	AX
	MOV	AX,IV_NLX+CDV_DN ; Case: true MSDOS version should be 3+
	CALL	ISNUL		; Check NUL device driver header
	POP	AX
	JNZ	DKIERR		; If check fails, give up
	CMP	AH,10
	JA	TRY30
	JMP	TRY31
TRYX:	MOV	AX,IV_NLX+CDV_DN ; Case: true MSDOS version should be 4+
	CALL	ISNUL		; Check NUL device driver header
	JNZ	DKIERR
	MOV	AL,FT_ENT+FX_FN	; Check first SFT entry
	CALL	ISSTD
	JZ	TRYXC
DKIERR:	POP	ES		; Flag an "internal error" if our auto-
	POP	DS		; -detection fails (FIXME)
	POP	SI
	JMP	DERIER

; Test if ES:[BX+AX] points to a blank-padded "NUL" device name.
;
ISNUL:	PUSH	BX
	ADD	BX,AX
	CMP	WORD PTR ES:[BX],"N"+"U"*100H
	JNZ	NOTNUL
	CMP	WORD PTR ES:2[BX],"L"+" "*100H
	JNZ	NOTNUL
	CMP	WORD PTR ES:4[BX]," "+" "*100H
	JNZ	NOTNUL
	CMP	WORD PTR ES:6[BX]," "+" "*100H
NOTNUL:	POP	BX
	RET

; Test if DS:[SI+AL] points to a space-padded "CON", "AUX", or "PRN" device
; name & a blank extension.  The direction flag (DF) should be clear, & AL
; should be less than 80H.
;
ISSTD:	PUSH	AX
	PUSH	DX
	PUSH	SI
	CBW
	ADD	SI,AX
	LODSW
	XCHG	DX,AX
	LODSB
	CMP	AL,"N"
	JZ	STDXXN
	CMP	AL,"X"
	JNZ	NOTSTD
	CMP	DX,"A"+"U"*100H
	JNZ	NOTSTD
ISSTD1:	PUSH	CX
	MOV	CX,4
ISSTD2:	LODSW
	CMP	AX," "+" "*100H
	LOOPZ	ISSTD2
	POP	CX
NOTSTD:	POP	SI
	POP	DX
	POP	AX
	RET
STDXXN:	CMP	DX,"C"+"O"*100H
	JZ	ISSTD1
	CMP	DX,"P"+"R"*100H
	JNZ	NOTSTD

CSEG	ENDS

DSEG	SEGMENT PUBLIC 'DATASG'

DSEG	ENDS
	END

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

; At startup, try to detect the version of MSDOS's internal data structures.
; This is for use by FDBDID (below) later.
;
	PUBLIC	DSKINI
DSKINI:	PUSH	SI
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
	MOV	SI,ES:[BX+IV_SFT]
	MOV	CX,ES:[BX+IV_SFT+2]
	CMP	SI,-1
	JZ	DKIFIN
	CMP	WORD PTR [SI+FT_NF],2
	JB	DKIFIN
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
	MOV	ES,CX		; Check if the first two SFT entries are for
	MOV	AL,FT_ENT+F2_FN	; CON, AUX, or PRN
	CALL	ISSTD
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
	JNZ	DKIFIN
				; Check second SFT entry for DOS 3.1--3.3x
	MOV	AL,FT_ENT+F3XSIZ+FX_FN
	CALL	ISSTD
	JZ	OK3X
TRYXC:				; Check second SFT entry for DOS 4+
	MOV	AL,FT_ENT+FXSIZ+FX_FN
	CALL	ISSTD
	JNZ	DKIFIN
OKX:	MOV	DIDIMP,DIDX
DKIFIN:	POP	ES
	POP	SI
	RET
OK2X:	MOV	DIDIMP,DID2X
	JMP	DKIFIN
OK30:	MOV	SFSIZ,F30SIZ
OK3XC:	MOV	DIDOFF,FT_ENT+F3_DIR
	JMP	OKX
OK3X:	MOV	SFSIZ,F3XSIZ
	JMP	OK3XC
TRY3X:	PUSH	AX
	MOV	AX,IV_NLX+CDV_DN ; Case: true MSDOS version should be 3+
	CALL	ISNUL		; Check NUL device driver header
	POP	AX
	MOV	ES,CX
	CMP	AH,10
	JA	TRY30
	JMP	TRY31
TRYX:	MOV	AX,IV_NLX+CDV_DN ; Case: true MSDOS version should be 4+
	CALL	ISNUL		; Check NUL device driver header
	JNZ	DKIFIN
	MOV	ES,CX
	MOV	AL,FT_ENT+FX_FN	; Check first SFT entry
	CALL	ISSTD
	JNZ	DKIFIN
	JMP	TRYXC

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

; Test if ES:[SI+AL] points to a space-padded "CON", "AUX", or "PRN" device
; name & a blank extension.  The direction flag (DF) should be clear, & AL
; should be less than 80H.
;
ISSTD:	PUSH	AX
	PUSH	DX
	PUSH	SI
	CBW
	ADD	SI,AX
	LODS	WORD PTR ES:[SI]
	XCHG	DX,AX
	LODS	BYTE PTR ES:[SI]
	CMP	AL,"N"
	JZ	STDXXN
	CMP	AL,"X"
	JNZ	NOTSTD
	CMP	DX,"A"+"U"*100H
	JNZ	NOTSTD
ISSTD1:	PUSH	CX
	MOV	CX,4
ISSTD2:	LODS	WORD PTR ES:[SI]
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

; Given an FDB DS:[SI], return in CX:AX a "directory identifier" to say
; which directory the file resides in.  If the file is a local file, then,
; together with the drive number, filename, and extension, this CX:AX value
; should help to uniquely distinguish (as far as possible) this file from
; all other local files of the same name.
;
; On entry, CF should be 0 if DS:[SI] is a closed file, or 1 if it is an
; open file.  In the former case, the FCB inside the FDB may be opened
; temporarily.
;
	PUBLIC	FDBDID
FDBDID:	JNC	FDICLO
	JMP	WORD PTR DIDIMP
FDICLO:	PUSH	DX
	LEA	DX,[SI+F_FCB]
	CALLOS	C_OPEN
	TEST	AL,AL
	JNZ	FDIERR
	CALL	WORD PTR DIDIMP
	PUSH	AX
	CALLOS	C_CLOS
	POP	AX
	POP	DX
	RET
FDIERR:	POP	DX
	; fall through

; Fallback implementation of FDBDID...
;
DIDFBK:	MOV	AX,-1
	MOV	CX,AX
	RET

; Implement FDBDID for DOS 2.x.
;
DID2X:	TEST	BYTE PTR [SI+FCB_DW],DIW_DV
	JNZ	DIDFBK			; If device special file, return -1
	MOV	AX,[SI+FCB_LC+1]	; Otherwise...
	AND	AL,11110000B		; Mask away remnants of dir. clus. no.
	XOR	CX,CX			; High half of dir. clus. no. is 0
DID2XD:	RET

; Implement FDBDID for DOS 3+.
;
DIDX:	PUSH	ES
	PUSH	BX
	MOV	AL,[SI+FCB_SF]		; Get the file's SFT index
	MOV	AH,0
	PUSH	AX
	CALLOS	C_IVAR			; Get the List of Lists
	POP	AX
	ADD	BX,4
DIDSFT:	LES	BX,ES:[BX]		; Find the SFT containing the file's
					; record...
	CMP	BX,-1			; lolwut?!?
	JZ	DIDNLF
	MOV	CX,ES:[BX+FT_NF]
	SUB	AX,CX
	JNC	DIDSFT
	ADD	AX,CX
	MUL	SFSIZ			; Look for the SFT entry
	ADD	BX,AX
					; If file is remote or device
					; special, then we are done
	TEST	WORD PTR ES:[BX+FT_ENT+FX_DIW],DIW_RM OR DIW_DV
	JNZ	DIDNLF
	MOV	AL,DIDOFF		; Otherwise...
	CBW
	ADD	BX,AX
	MOV	AX,ES:[BX]
	MOV	CX,ES:2[BX]
DIDFIN:	POP	BX
	POP	ES
	RET
DIDNLF:	POP	BX
	POP	ES
	JMP	DIDFBK

CSEG	ENDS

DSEG	SEGMENT PUBLIC 'DATASG'

DIDIMP	DW	DIDFBK			; Implementation of FDBDID to use
SFSIZ	DB	FXSIZ			; Size of each SFT entry (DOS 3+)
DIDOFF	DB	FT_ENT+FX_DIR		; Offset of a "directory identifier"
					; within an SFT entry (DOS 3+);
					; further offset by FT_ENT for
					; convenience

DSEG	ENDS
	END

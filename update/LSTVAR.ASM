	TITLE   LSTVAR - Marker for end of data segment

; Modified from BIBOOT.ASM 2020 by: TK Chia <https://github.com/tkchia>

;
; Last label in data segment.  Is used by BASIC to initialize TXTTAB, etc.
;
DSEG    SEGMENT PUBLIC 'DATASG'
        ASSUME  DS:DSEG
        PUBLIC  LSTVAR
LSTVAR  LABEL   WORD
DSEG    ENDS
	END

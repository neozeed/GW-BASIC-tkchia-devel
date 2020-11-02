	.RADIX	8

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG,DS:DSEG

INCLUDE	OEM.H

	TITLE   OEMA - Vendor provided code for Advanced Basic

COMMENT *
(Re-)written by: TK Chia <https://github.com/tkchia>
        *
	.SALL

CSEG	ENDS

INCLUDE OEM.ASM

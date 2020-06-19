#!/usr/bin/awk -f
#
# Modify an .ASM source file from Microsoft's GW-BASIC source release to
# allow JWasm to assemble it without errors.
#
#	Permission is hereby granted, free of charge, to any person
#	obtaining a copy of this software and associated documentation files
#	(the "Software"), to deal in the Software without restriction,
#	including without limitation the rights to use, copy, modify, merge,
#	publish, distribute, sublicense, and/or sell copies of the Software,
#	and to permit persons to whom the Software is furnished to do so,
#	subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be
#	included in all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#	NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
#	BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
#	ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#	SOFTWARE.

BEGIN {
	# Try to only really munge source code from the original GW-BASIC
	# source files.  For additional modules (such as OEM.ASM), just
	# adding a few extra pseudo-ops for JWasm and JWlink will do.
	really_munge = 0

	# Initialize the table of keywords which we might want JWasm to
	# treat as identifiers.
	id_words["FADD"] = 1
	id_words["FCOMP"] = 1
	id_words["FDIV"] = 1
	id_words["FFREE"] = 1
	id_words["FOR"] = 1
	id_words["FSUB"] = 1
	id_words["GOTO"] = 1
	id_words["IDIV"] = 1
	id_words["INT"] = 1
	id_words["LABEL"] = 1
	id_words["LOOP"] = 1
	id_words["NAME"] = 1
	id_words["NEG"] = 1
	id_words["OPTION"] = 1
	id_words["PUSHF"] = 1
	id_words["WHILE"] = 1

	# Initialize the table of public identifiers for constants.
	cn_words["$ASC"] = 1
	cn_words["$COM"] = 1
	cn_words["$ERDEV"] = 1
	cn_words["$INP"] = 1
	cn_words["$KEY2B"] = 1
	cn_words["$LIST"] = 1
	cn_words["$OFF"] = 1
	cn_words["$ON"] = 1
	cn_words["$PLAY"] = 1
	cn_words["$STOP"] = 1
	cn_words["$STRS"] = 1
	cn_words["EQULTK"] = 1
	cn_words["ERRADV"] = 1
	cn_words["ERRNF"] = 1
	cn_words["ERROD"] = 1
	cn_words["KYBQSZ"] = 1
	cn_words["OPCNT"] = 1
	cn_words["T_ON"] = 1
	cn_words["T_REQ"] = 1

	# Pre-build some regular expressions.  I cheat a bit and treat the
	# double quote `"' as an "identifier" character so that error messages
	# like `"NEXT without FOR"' will not be mangled.
	id_ch_re = "[$?@_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ\"]"
	id_re = "(" id_ch_re "+)"
	ws_re = "([ \\t]+)"
	words_re = "("
	for (word in id_words)
		words_re = words_re word "|"
	words_re = words_re "DB\tOFFSET|\\?CSLAB|PWR2PX=)"

	# Do this for all modules, including the extra OEM.ASM.
	print "; [ Munged by jwasmify.awk " strftime() " ]"
	print "OPTION NOKEYWORD: <LENGTH>"
}

{
	gsub(/\r+$/, "")
}

/\[ This translation created .* \]/ {
	really_munge = 1
	print
	next
}

$0 ~ words_re {
	# JWlink (following the original Watcom Linker) will only place the
	# data segment separate from the code segment, if only the former is
	# in DGROUP, _and_ if `dosseg' is specified to the linker (see
	# Makefile.jw).  And, we might need this hack for OEM.ASM too.  Argh!
	if ($0 ~ /^DSEG SEGMENT /)
		print "DGROUP GROUP DSEG"

	if (!really_munge) {
		print
		next
	}

	# Fix various minor semantics issues.
	gsub(/\tDB\tOFFSET /, "\tDB\tLOW OFFSET ")
	gsub(/ DB\tOFFSET /, " DB\tLOW OFFSET ")
	if ($0 ~ /^PWR2PX=/) {				# ADVGRP.ASM
		print "MELCO=0"
		print "TETRA=0"
		print "MCI=0"
		print "SIRIUS=0"
	}

	if ($0 ~ /^\tMOVS\t\?CSLAB,WORD PTR \?CSLAB/) {	# MATH1.ASM & MATH2.ASM
		gsub(/\?CSLAB,/, "$FACLO,")
		if (/;/) {
			# The fork of JWasm at https://github.com/JWasm/JWasm
			# does not (yet) properly insert a needed CS: segment
			# override for this MOVS operation.
			#
			# Add an assembly-time check for this bug at a
			# convenient spot in MATH1.ASM.  If the bug exists,
			# recommend "mainline" JWasm...
			print "?JWTST:"
			print
			print "IF\t$-?JWTST LT 2"
			print "\t.ERR\t<this assembler is buggy>"
			print "\t.ERR\t<try " \
			      "https://github.com/Baron-von-Riedesel/JWasm " \
			      "instead>"
			print "ENDIF"
			next
		}
	}

	for (word in id_words) {
		# For a word such as PUSHF, we need to spot these cases:
		#		PUSHF		# do not munge PUSHF
		#	LCLEAR:	PUSHF		# do not munge PUSHF
		#	PUSHF:	POP	SI	# yes, munge PUSHF
		#	CURLIN	LABEL	WORD	# do not munge LABEL
		#		LABEL=PC8A	# munge LABEL
		if ($0 !~ "^" word ":") {
			if ($0 ~ "^" ws_re word ws_re ||
			    $0 ~ "^" ws_re word "$" ||
			    $0 ~ "^" id_re ":" ws_re word ws_re ||
			    $0 ~ "^" id_re ":" ws_re word "$")
				continue
			if (word == "LABEL" && $0 !~ /LABEL=/)
				continue
		}

		# Handle	QF	INT
		# and		R	FOR
		if ($0 == "\tQ\t" word ||
		    $0 == "\tQF\t" word ||
		    $0 ~ "^\tR2\t" word ",") {
			print
			next
		}
		if ($0 == "\tR\t" word) {
			print "\tR2\t" word ",`" word "`"
			next
		}

		# Handle the remaining cases, such as
		#		EXTRN	PUSHF:NEAR
		#		PUBLIC	... ,PUSHF, ...
		#	PUSHF:
		# Rewrite these as
		#		EXTRN	`PUSHF`:NEAR
		#		PUBLIC	... ,`PUSHF`, ...
		#	`PUSHF`:
		FS = OFS = word
		$0 = $0
		for (i = 1; i < NF; ++i) {
			if ($i !~ id_ch_re "$" &&
			    $(i + 1) !~ "^" id_ch_re) {
				$i = $i "`"
				$(i + 1) = "`" $(i + 1)
			}
		}
	}
}

/^\tEXTRN\t/ {
	# JWlink does not like it if a module exports ERRADV as an absolute
	# constant, and then another module does a
	#	EXTRN	... ERRADV:WORD
	# Rewrite the import as
	#	EXTRN	... ERRADV:ABS
	for (word in cn_words) {
		FS = OFS = word
		gsub(/\$/, "\\$", FS)
		$0 = $0
		for (i = 2; i <= NF; ++i) {
			if ($(i - 1) !~ id_ch_re "$") {
				sub(/^:NEAR/, ":ABS", $i)
				sub(/^:WORD/, ":ABS", $i)
			}
		}
	}
}

{
	print
}

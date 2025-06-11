start:
	nop
	mov a,#$D9
	or a,#2
	mov 10,a
	mov a,#3
	add 10,a
	mov a,10
	ceqsn a,#$DE
	ldspth
	clear 10
	clear 11
	not 10
	mov a,#2
	add a,10
	addc 11
	dzsn a
	ldspth
	mov a,11
	ceqsn a,#1
	ldspth
	mov a,#$28
	mov ^6,a
	mov a,#$FF
	mov ^17,a
	mov a,#$55
	mov ^16,a
	mov a,#$FF
	xor ^16,a
	xor ^16,a
	xor ^16,a
	xor ^16,a
	xor ^16,a
	mov a,#32
	mov ^2,a
	call a_subroutine
	mov a,#10
	sub a,#3
	ceqsn a,#7
	ldspth
	mov a,^2
	ceqsn a,#32
	ldspth
	nop
	
	ldsptl
	goto start
a_subroutine:
	nop
	nop
	mov a,#33
	pushaf
	mov a,#$FF
	xor ^16,a
	popaf
	ceqsn a,#33
	ldspth
	nop
	ret

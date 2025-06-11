start:
	nop
	nop
	nop
	nop
	nop
	; Clock selection: IHRC/2
	mov a,#%00110110
	mov ^3,a
	nop
	; Setup stack pointer
	mov a,#32
	mov ^2,a
	nop
	nop
	nop
	nop
	nop
	goto main
trupt:
	pushaf
	mov a,2
	mov ^16,a
	; Clear IRQs
	mov a,#0
	mov ^5,a
	popaf
	reti
main:
	; All IOs as inputs with no pull-ups
	mov a,#0
	mov ^18,a
	mov ^17,a
	mov ^16,a
	mov a,^16
	; Initialize part of xorshift state with IO value
	mov 1,a
	; All IOs as outputs
	mov a,#$FF
	mov ^17,a
	mov ^16,a
	; Setup xorshift seed
	mov a,#$4D
	mov 0,a
	;mov a,#$39
	;mov 1,a
	mov a,#$AD
	mov 2,a
	mov a,#$99
	mov 3,a
	; Clear all IRQs and enable timer interrupt
	mov a,#0
	mov ^5,a
	mov a,#4
	mov ^4,a
	; Start timer with interrupt
	;mov a,#$20
	mov a,#$3F
	mov ^6,a
	; Enable interrupts globally
	engint
xorshift_loop:
	wdreset
	
	mov a,0
	mov 10,a
	mov a,1
	mov 11,a
	mov a,2
	mov 12,a
	mov a,#5
	mov 20,a
shift_loop_1:
	set0 ^0.1
	slc 10
	slc 11
	slc 12
	dzsn 20
	goto shift_loop_1
	
	mov a,10
	xor 1,a
	mov a,11
	xor 2,a
	mov a,12
	xor 3,a
	
	mov a,2
	mov 10,a
	mov a,3
	set0 ^0.1
	src 10
	src a
	xor 1,a
	mov a,10
	xor 0,a
	
	mov a,0
	mov 10,a
	mov a,1
	mov 11,a
	mov a,2
	mov 12,a
	mov a,3
	mov 13,a
	
	mov a,#251
shift_loop_2:
	sl 10
	slc 11
	slc 12
	slc 13
	izsn a
	goto shift_loop_2
	
	mov a,10
	xor 0,a
	mov a,11
	xor 1,a
	mov a,12
	xor 2,a
	mov a,13
	xor 3,a
	
	goto xorshift_loop

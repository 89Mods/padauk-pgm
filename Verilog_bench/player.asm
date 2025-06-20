spival	equ	10
spictr	equ	12
counter	equ	5

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
	mov a,#1
	mov ^27,a
	nop
	goto main
trupt:
	nop
	nop
	pushaf
	call spirx
	mov a,spival
	mov ^9,a
	mov a,#1
	add counter,a
	mov a,#0
	addc counter+1,a
	mov a,#0
	addc counter+2,a
	mov a,counter
	mov a,counter+1
	mov a,counter+2
	t0sn counter+2.7
	reset
	; Clear IRQs
	mov a,#0
	mov ^5,a
	popaf
	reti
main:
	mov a,#0
	mov ^18,a
	; PA3 - TM2PWM
	; PA4 - SDIO
	; PA5 - CSb
	; PA6 - SCLK
	mov a,#%01101000
	mov ^17,a
	mov a,#%00100000
	mov ^16,a
	; Start timer2 in PWM mode
	mov a,#%00101010
	mov ^28,a
	mov a,#0
	mov ^9,a
	mov a,#%00000001
	mov ^23,a
	; Reset spiflash
	call spiflash_reset
	; Clear all IRQs and enable timer interrupt
	mov a,#0
	mov ^5,a
	mov a,#4
	mov ^4,a
	; Start timer with interrupt
	;mov a,#$20
	mov a,#%10000001 ; Aprox. 16000 times per second (15625)
	mov ^6,a
	engint
	; Nothing to do here
	mov a,#1
loop:
	nop
	slc a
	nop
	wdreset
	nop
	goto loop

spitx:
	set1 ^17.4
	mov a,#8
	mov spictr,a
spitx_loop:
	set0 ^16.4
	t0sn spival.7
	set1 ^16.4
	sl spival
	set1 ^16.6
	nop
	set0 ^16.6
	dzsn spictr
	goto spitx_loop
	set0 ^17.4
	set0 ^16.4
	ret

spirx:
	mov a,#8
	mov spictr,a
	mov a,#0
	mov spival,a
spirx_loop:
	sl spival
	t0sn ^16.4
	inc spival
	set1 ^16.6
	nop
	set0 ^16.6
	dzsn spictr
	goto spirx_loop
	ret

spiflash_desel:
	set1 ^16.5
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ret

spiflash_reset:
	call spiflash_desel
	set0 ^16.5
	mov a,#$FF
	mov spival,a
	call spitx
	call spiflash_desel
	set0 ^16.5
	mov a,#$AB
	mov spival,a
	call spitx
	mov a,#$00
	mov spival,a
	call spitx
	call spitx
	call spitx
	call spirx
	call spiflash_desel
	set0 ^16.5
	mov a,#$03
	mov spival,a
	call spitx
	mov a,#$00
	mov counter,a
	mov counter+1,a
	mov counter+2,a
	mov spival,a
	call spitx
	call spitx
	call spitx
	ret

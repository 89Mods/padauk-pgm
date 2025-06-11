#include "funconfig.h"

#include <stdint.h>

#include "ch32fun.h"
#include "ch32v003_uart.h"

#include <stdio.h>

#define VCC_ENb PC1
#define GND_EN PC2
#define MOSI PC3
#define MISO PC4
#define SCK PC6
#define VPP_OFF PC7
#define GND_VDD PD4

#define LEVEL_10_8V 0x7E
#define LEVEL_7_5V 0xD4
#define LEVEL_LOWEST 0xFF

const char hexchars[] = "0123456789ABCDEF";

void newl() {
	UART_putc(13);
	UART_putc(10);
}

void puthex8(uint8_t c) {
	UART_putc(hexchars[c >> 4]);
	UART_putc(hexchars[c & 0xf]);
}

void puthex16(uint16_t c) {
	UART_putc(hexchars[c >> 12]);
	UART_putc(hexchars[(c >> 8) & 0xF]);
	UART_putc(hexchars[(c >> 4) & 0xF]);
	UART_putc(hexchars[c & 0xf]);
}

void puthex12(uint16_t c) {
	UART_putc(hexchars[(c >> 8) & 0xF]);
	UART_putc(hexchars[(c >> 4) & 0xF]);
	UART_putc(hexchars[c & 0xf]);
}

void power_target_on() {
	funDigitalWrite(PA1, FUN_HIGH);
	funDigitalWrite(GND_VDD, FUN_LOW);
	funDigitalWrite(VCC_ENb, FUN_LOW);
	funDigitalWrite(GND_EN, FUN_HIGH);
	funPinMode(MOSI, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funPinMode(SCK, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(MOSI, FUN_LOW);
	funDigitalWrite(SCK, FUN_LOW);
}

void float_target_power() {
	funDigitalWrite(GND_VDD, FUN_LOW);
	funDigitalWrite(VCC_ENb, FUN_HIGH);
	funPinMode(MOSI, GPIO_CFGLR_IN_FLOAT);
	funPinMode(SCK, GPIO_CFGLR_IN_FLOAT);
	funDigitalWrite(GND_EN, FUN_LOW);
	funPinMode(MOSI, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(MOSI, FUN_LOW);
	funPinMode(SCK, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(SCK, FUN_LOW);
	Delay_Us(3);
}

void power_target_off() {
	funDigitalWrite(PA1, FUN_LOW);
	TIM2->CH3CVR = LEVEL_LOWEST;
	funDigitalWrite(VPP_OFF, FUN_HIGH);
	Delay_Us(2);
	funDigitalWrite(VCC_ENb, FUN_HIGH);
	funDigitalWrite(GND_EN, FUN_HIGH);
	funDigitalWrite(GND_VDD, FUN_HIGH);
	funDigitalWrite(MOSI, FUN_LOW);
	funDigitalWrite(SCK, FUN_LOW);
	funPinMode(MOSI, GPIO_CFGLR_IN_FLOAT);
	funPinMode(SCK, GPIO_CFGLR_IN_FLOAT);
	Delay_Ms(1);
}

#define SPI_DEL 5

uint8_t spi_tfr(uint8_t val) {
	uint8_t res = 0;
	for(uint8_t i = 0; i < 8; i++) {
		if((val & 128) != 0) {funDigitalWrite(MOSI, FUN_HIGH);}
		else {funDigitalWrite(MOSI, FUN_LOW);}
		Delay_Us(SPI_DEL);
		val <<= 1;
		res <<= 1;
		if(funDigitalRead(MISO)) res |= 1;
		funDigitalWrite(SCK, FUN_HIGH);
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_LOW);
		Delay_Us(SPI_DEL);
	}
	Delay_Us(SPI_DEL);
	return res;
}

uint16_t spi_tx13(uint16_t val) {
	uint16_t res = 0;
	for(uint8_t i = 0; i < 13; i++) {
		if((val & 4096) != 0) {funDigitalWrite(MOSI, FUN_HIGH);}
		else {funDigitalWrite(MOSI, FUN_LOW);}
		res <<= 1;
		val <<= 1;
		Delay_Us(SPI_DEL);
		if(funDigitalRead(MISO)) res |= 1;
		funDigitalWrite(SCK, FUN_HIGH);
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_LOW);
		Delay_Us(SPI_DEL);
	}
	Delay_Us(SPI_DEL);
	return res;
}

uint16_t spi_tx12(uint16_t val) {
	uint16_t res = 0;
	for(uint8_t i = 0; i < 12; i++) {
		if((val & 2048) != 0) {funDigitalWrite(MOSI, FUN_HIGH);}
		else {funDigitalWrite(MOSI, FUN_LOW);}
		val <<= 1;
		res <<= 1;
		Delay_Us(SPI_DEL);
		if(funDigitalRead(MISO)) res |= 1;
		funDigitalWrite(SCK, FUN_HIGH);
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_LOW);
		Delay_Us(SPI_DEL);
	}
	Delay_Us(SPI_DEL);
	return res;
}

void key_sequence(uint8_t write) {
	TIM2->CH3CVR = LEVEL_7_5V;
	float_target_power();
	funDigitalWrite(VPP_OFF, FUN_LOW);
	Delay_Us(100);
	power_target_on();
	Delay_Us(500);
	spi_tfr(0xA5); spi_tfr(0xA5); spi_tfr(0xA5); Delay_Us(1);
	spi_tfr(write ? 0xA7 : 0xA6);
	Delay_Us(10);
	if(write) {
		TIM2->CH3CVR = LEVEL_10_8V;
		Delay_Ms(15);
	}
}

uint8_t check_id(void) {
	key_sequence(1);
	spi_tx13(0x0000); spi_tx13(0x0000);
	uint16_t device_id = 0;
	device_id = spi_tx12(0x000);
	power_target_off();
	Delay_Ms(50);
	if(device_id != 0xA16) {
		UART_printf("Invalid device ID %x\r\n", device_id);
		return 1;
	}
	return 0;
}

uint8_t UART_waitForChar(void) {
	uint16_t i;
	while(1) {
		i = UART_getc();
		if(i == UART_NO_DATA) continue;
		if((i & 0xFF00) != 0) return 0;
		return i & 0xFF;
	}
}

#define CHIP_SIZE 1024
#define CHIP_SIZE_PROGRAMMABLE (1024-16)

uint8_t doDump(void) {
	if(check_id()) return 1;
	key_sequence(0);
	for(uint16_t i = 0; i < CHIP_SIZE; i++) {
		spi_tx12(i);
		funDigitalWrite(SCK, FUN_HIGH);
		uint16_t val = spi_tx13(0);
		if((i & 15) == 0) {
			UART_putc(13);
			UART_putc(10);
			puthex12(i);
		}
		UART_putc(' ');
		puthex16(val);
	}
	UART_putc(13);
	UART_putc(10);
	power_target_off();
	Delay_Ms(50);
	return 0;
}

uint8_t doProgramming(void) {
	if(check_id()) return 2;
	key_sequence(0);
	for(uint16_t i = 0; i < CHIP_SIZE_PROGRAMMABLE; i++) {
		spi_tx12(i);
		funDigitalWrite(SCK, FUN_HIGH);
		uint16_t val = spi_tx13(0);
		if(val != 0x1FFF) {
			power_target_off();
			Delay_Ms(50);
			UART_printf("Chip not blank, programmed word found at address 0x%x\r\n", i);
			return 1;
		}
	}
	power_target_off();
	Delay_Ms(50);
	UART_putc('a');
	uint32_t len = UART_waitForChar() - 'A';
	len |= (uint16_t)(UART_waitForChar() - 'A') << 4;
	len |= (uint16_t)(UART_waitForChar() - 'A') << 8;
	len |= (uint16_t)(UART_waitForChar() - 'A') << 12;
	if(len > CHIP_SIZE_PROGRAMMABLE) {
		UART_printf("THAT’S TOO BIG!\r\n");
		return 1;
	}
	if((len & 1) != 0) {
		UART_printf("Uneven size not permitted\r\n");
		return 1;
	}
	uint8_t uneven = len & 3;
	uint32_t end = len >> 2;
	if(uneven) end++;
	key_sequence(1);
	for(uint32_t i = 0; i < end; i++) {
		UART_putc('n');
		uint16_t val = UART_waitForChar();
		UART_putc('n');
		val |= (uint16_t)UART_waitForChar() << 8;
		uint16_t val2 = 0x1FFF;
		if(!(i == end - 1 && uneven)) {
			UART_putc('n');
			val2 = UART_waitForChar();
			UART_putc('n');
			val2 |= (uint16_t)UART_waitForChar() << 8;
		}
		spi_tx13(val);
		spi_tx13(val2);
		spi_tx12(i << 1);
		//Send 0 bit to initiate write
		funDigitalWrite(MOSI, FUN_LOW);
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_HIGH);
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_LOW);
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_HIGH);
		Delay_Us(SPI_DEL * 2);
		for(uint8_t j = 0; j < 8; j++) {
			funDigitalWrite(MOSI, FUN_HIGH);
			Delay_Us(61);
			funDigitalWrite(MOSI, FUN_LOW);
			Delay_Us(61);
		}
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_LOW);
		//Trailing 0 bit to end write
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_HIGH);
		Delay_Us(SPI_DEL);
		funDigitalWrite(SCK, FUN_LOW);
		Delay_Us(SPI_DEL);
	}
	power_target_off();
	UART_putc('d');
	key_sequence(0);
	for(uint32_t i = 0; i < end; i++) {
		UART_waitForChar();
		spi_tx12(i << 1);
		funDigitalWrite(SCK, FUN_HIGH);
		uint16_t val = spi_tx13(0);
		UART_putc((val & 15) + 48);
		UART_putc(((val >> 4) & 15) + 48);
		UART_waitForChar();
		val >>= 8;
		UART_putc((val & 15) + 48);
		UART_putc(((val >> 4) & 15) + 48);
		if(!(i == end - 1 && uneven)) {
			UART_waitForChar();
			spi_tx12((i << 1) | 1);
			funDigitalWrite(SCK, FUN_HIGH);
			val = spi_tx13(0);
			UART_putc((val & 15) + 48);
			UART_putc(((val >> 4) & 15) + 48);
			UART_waitForChar();
			val >>= 8;
			UART_putc((val & 15) + 48);
			UART_putc(((val >> 4) & 15) + 48);
		}
	}
	power_target_off();
	return 0;
}

int main() {
	SystemInit();
	AFIO->PCFR1 &= ~(1 << 15);
	RCC->CTLR &= ~(1 << 16);
	funGpioInitAll();
	UART_init();
	funPinMode( PC0,     GPIO_Speed_10MHz | GPIO_CNF_OUT_PP_AF );
	funPinMode( PD5,     GPIO_Speed_10MHz | GPIO_CNF_OUT_PP_AF );
	
	RCC->APB1PCENR |= RCC_APB1Periph_TIM2;
	RCC->APB1PRSTR |= RCC_APB1Periph_TIM2;
	RCC->APB1PRSTR &= ~RCC_APB1Periph_TIM2;
	TIM2->PSC = 0x0000;
	TIM2->ATRLR = 255;
	TIM2->CHCTLR2 |= TIM_OC3M_2 | TIM_OC3M_1 | TIM_OC3PE;
	TIM2->CTLR1 |= TIM_ARPE;
	TIM2->CCER |= TIM_CC3E | (TIM_CC3P & 0xff);
	TIM2->SWEVGR |= TIM_UG;
	TIM2->CTLR1 |= TIM_CEN;
	TIM2->CH3CVR = LEVEL_LOWEST;
	
	funPinMode(VCC_ENb, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(VCC_ENb, FUN_HIGH);
	funPinMode(GND_EN, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(GND_EN, FUN_HIGH);
	funPinMode(MOSI, GPIO_CFGLR_IN_FLOAT);
	funPinMode(SCK, GPIO_CFGLR_IN_FLOAT);
	
	funPinMode(MISO, GPIO_CFGLR_IN_PUPD);
	funPinMode(VPP_OFF, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(VPP_OFF, FUN_HIGH);
	funPinMode(GND_VDD, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(GND_VDD, FUN_HIGH);
	
	funPinMode(PA2, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(PA2, FUN_HIGH);
	funPinMode(PA1, GPIO_Speed_10MHz | GPIO_CNF_OUT_PP);
	funDigitalWrite(PA1, FUN_LOW);
	
	while(1) {
		power_target_off();
		UART_printf("\r\nPress 9 to continue\r\n");
		Delay_Ms(50);
		uint8_t mode = 0;
		while(1) {
			mode = UART_getc();
			if(mode == '9') break;
			Delay_Ms(1);
		}
		UART_printf("Press r to dump ROM\r\n");
		while(1) {
			mode = UART_getc();
			if(mode == 'r') {
				doDump();
				break;
			}
			if(mode == 'p') {
				doProgramming();
				break;
			}
			Delay_Ms(1);
		}
		
		Delay_Ms(509);
	}
}

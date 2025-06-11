all : flash

PREFIX_DEFAULT:=/home/tholin/riscv/bin/riscv32-unknown-elf
TARGET:=main
TARGET_MCU?=CH32V003
MINICHLINK=../ch32fun/minichlink

include ../ch32fun/ch32fun/ch32fun.mk

flash : cv_flash
clean : cv_clean



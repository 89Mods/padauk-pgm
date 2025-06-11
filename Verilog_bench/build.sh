#!/bin/bash

set -e

ASL_ROOT="/run/media/tholin/8a6b8802-051e-45a8-8492-771202e4c08a/asl-avalonsemi/"
TRACE_FLAGS="--trace-depth 3 --trace -DTRACE_ON -CFLAGS '-DTRACE_ON'"
verilator -DBENCH -Wno-fatal --timing --top-module tb -cc -exe ${TRACE_FLAGS} bench.cpp tb.v pmc150.v
cd obj_dir
make -f Vtb.mk
cd ..
${ASL_ROOT}/asl -cpu PDK13 xorshift.asm && ${ASL_ROOT}/p2bin xorshift.p && java ToVerilogHex.java xorshift.bin pgm.txt

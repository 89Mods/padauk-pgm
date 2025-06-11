#include "Vtb.h"
#include "verilated.h"
#include <iostream>

static Vtb top;

double sc_time_stamp() { return 0; }

int main(int argc, char** argv, char** env) {
#ifdef TRACE_ON
	std::cout << "Warning: tracing is ON!" << std::endl;
	Verilated::traceEverOn(true);
#endif
	top.clk = 0;
	int counter = 0;
	while(!Verilated::gotFinish() && counter < 20200) {
		Verilated::timeInc(1);
		top.clk = !top.clk;
		top.eval();
		counter++;
	}
	if(!Verilated::gotFinish()) std::cout << "Timeout" << std::endl;
	top.final();
	return 0;
}

`default_nettype none
`timescale 1ns/10ps

module tb(
	input clk
);

reg [12:0] ROM [1023:0];

initial begin
	for(integer i = 0; i < 1024; i=i+1) begin
		ROM[i] = 0;
	end
	$readmemh("../pgm.txt", ROM);
end

wire [7:0] pa;
wire [7:0] pa_out;
wire [7:0] pa_oeb;
wire [9:0] rom_addr;
assign pa[0] = pa_oeb[0] ? 1'bz : pa_out[0];
assign pa[1] = pa_oeb[1] ? 1'bz : pa_out[1];
assign pa[2] = pa_oeb[2] ? 1'bz : pa_out[2];
assign pa[3] = pa_oeb[3] ? 1'bz : pa_out[3];
assign pa[4] = pa_oeb[4] ? 1'bz : pa_out[4];
assign pa[5] = pa_oeb[5] ? 1'bz : pa_out[5];
assign pa[6] = pa_oeb[6] ? 1'bz : pa_out[6];
assign pa[7] = pa_oeb[7] ? 1'bz : pa_out[7];

pmc150 pmc150(
	.clk(clk),
	.pa_out(pa_out),
	.pa_in(pa),
	.pa_oeb(pa_oeb),
	.rom_addr(rom_addr),
	.rom_val(ROM[rom_addr])
);

wire PA4 = pa[4];
wire PA3 = pa[3];
wire PA6 = pa[6];
wire PA5 = pa[5];

`ifdef TRACE_ON
initial begin
	$dumpfile("tb.vcd");
	$dumpvars();
end
`endif

endmodule

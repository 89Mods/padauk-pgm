`default_nettype none

`define CLKMD_RESET 8'b11110110

/*
 * Unimplemented:
 * AC flag
 * OV flag
 * LDSPTL
 * LDSPTH
 * Sleep modes
 * Clock modes
 * Pin interrupt
 * Timer interrupt
 */

module pmc150(
	input clk,
	output [7:0] pa_out,
	input [7:0] pa_in,
	output [7:0] pa_oeb,
	output [9:0] rom_addr,
	input [12:0] rom_val
);

reg [15:0] RAM [31:0];

reg [8:0] slow_clk_gen = 0;
wire slow_clk = slow_clk_gen == 420;
reg [9:0] PC = 10'h3FF;
assign rom_addr = interrupting ? 10'h010 : next_PC;
wire [9:0] next_PC = interrupting ? 10'h011 : (br_instr ? br_targ : (instr == 13'h0017 ? PC + {2'b00, A} : (return_instr ? stack_word[9:0] : PC + 1)));
reg [12:0] instr = 0;

wire bit_instr = instr[12:9] == 4'h1 || instr[12:10] == 3'h3;
wire op16_instr = instr[12:6] == 7'h03;
wire [5:0] mem_addr = bit_instr ? {2'b00, instr[3:0]} : (op16_instr ? {instr[5:1], 1'b0} : instr[5:0]);
wire [4:0] io_addr = instr[4:0];
wire [7:0] imm = instr[7:0];
wire [9:0] br_targ = instr[9:0];
wire retk_instr = instr[12:8] == 5'h01;
wire return_instr = retk_instr || instr[12:1] == 12'h01D;
wire br_instr = instr[12:11] == 2'b11;

wire special = instr[12:4] == 9'h003;
wire [3:0] special_op = instr[3:0];

wire [15:0] RAM_word = RAM[mem_addr[5:1]];
wire [7:0] RAM_byte = mem_addr[0] ? RAM_word[15:8] : RAM_word[7:0];
wire [15:0] stack_word = RAM[SPm2[5:1]];

wire bittest_type = instr[12:10] == 3'h3 ? instr[9] : instr[8];
wire bittest_polarity = instr[12:10] == 3'h3 ? instr[8] : instr[4];
wire [7:0] bitop_in = instr[12:10] == 3'h3 ? io_rval : RAM_byte;
wire [2:0] bitpos = instr[7:5];
wire bitt = bitop_in[bitpos];
reg [7:0] bitmask;
always @(*) begin
	case(bitpos)
		0: bitmask = {7'h00, 1'b1};
		1: bitmask = {6'h00, 1'b1, 1'b0};
		2: bitmask = {5'h00, 1'b1, 2'h0};
		3: bitmask = {4'h0, 1'b1, 3'h0};
		4: bitmask = {3'h0, 1'b1, 4'h0};
		5: bitmask = {2'h0, 1'b1, 5'h00};
		6: bitmask = {1'b0, 1'b1, 6'h00};
		7: bitmask = {1'b1, 7'h00};
	endcase
end
wire bittest_skip = bittest_polarity ? bitt != 0 : bitt == 0;
wire [7:0] bitop_res = bittest_polarity ? (bitop_in | bitmask) : (bitop_in & (~bitmask));

wire ari_instr = instr[12:10] == 3'b001;
wire imm_instr = instr[12:11] == 2'b10;
wire [7:0] ari_op0 = instr[9] || imm_instr ? A : RAM_byte;
wire [7:0] ari_op1 = imm_instr ? imm : (instr[9] ? RAM_byte : A);
wire [2:0] alu_op = imm_instr ? instr[10:8] : instr[8:6];

reg [8:0] alu_out;
always @(*) begin
	case(alu_op)
		0: alu_out = {1'b0, ari_op0} + {1'b0, ari_op1};
		1: alu_out = {1'b0, ari_op0} - {1'b0, ari_op1};
		2: alu_out = {1'b0, ari_op0} + {1'b0, ari_op1} + {8'h00, C};
		3: alu_out = {1'b0, ari_op0} - {1'b0, ari_op1} - {8'h00, C};
		4: alu_out = {C, ari_op0 & ari_op1};
		5: alu_out = {C, ari_op0 | ari_op1};
		6: alu_out = {C, ari_op0 ^ ari_op1};
		7: alu_out = {C, ari_op1};
	endcase
end

wire misc_A_instr = instr[12:4] == 9'h001;
wire misc_M_instr = instr[12:10] == 3'b010;
wire [3:0] misc_op = misc_M_instr ? instr[9:6] : instr[3:0];

wire [8:0] addc = {1'b0, misc_M_instr ? RAM_byte : A} + {8'h00, C};
wire [8:0] subc = {1'b0, misc_M_instr ? RAM_byte : A} - {8'h00, C};
wire [8:0] inc = misc_M_instr ? RAM_byte + 1 : A + 1;
wire [8:0] dec = misc_M_instr ? RAM_byte - 1 : A - 1;
wire [7:0] neg = (misc_M_instr ? ~RAM_byte : ~A) + {7'h00, instr[0]};
wire [7:0] swap = {A[3:0], A[7:4]};
wire [7:0] sr = {instr[1] ? 1'b0 : C, misc_M_instr ? RAM_byte[7:1] : A[7:1]};
wire [7:0] sl = {misc_M_instr ? RAM_byte[6:0] : A[6:0], instr[1] ? 1'b0 : C};

wire ram_write = (instr[12:9] == 4'h1 && bittest_type) || (ari_instr && !instr[9]) || (misc_M_instr);
wire io_write = (instr[12:10] == 3'h3 && bittest_type) || instr[12:5] == 8'h05 || instr[12:5] == 8'h04 || instr[12:5] == 8'h03;
wire skip = (bit_instr && !bittest_type && bittest_skip) || ((misc_A_instr || misc_M_instr) && misc_op == 2 && inc[7:0] == 0) || ((misc_A_instr || misc_M_instr) && misc_op == 3 && dec[7:0] == 0) || (instr[12:8] == 5'h12 && A == imm) || (instr[12:6] == 7'h2E && A == RAM_byte);

reg [7:0] misc_wval;
always @(*) begin
	case(misc_op)
		0: misc_wval = addc[7:0];
		1: misc_wval = subc[7:0];
		2: misc_wval = inc[7:0];
		3: misc_wval = dec[7:0];
		4: misc_wval = inc[7:0];
		5: misc_wval = dec[7:0];
		default: misc_wval = 0;
		7: misc_wval = A;
		8: misc_wval = neg;
		9: misc_wval = neg;
		10: misc_wval = sr;
		11: misc_wval = sl;
		12: misc_wval = sr;
		13: misc_wval = sl;
		14: misc_wval = RAM_byte;
	endcase
end

reg [7:0] misc_newA;
always @(*) begin
	case(misc_op)
		default: misc_newA = A;
		0: misc_newA = addc[7:0];
		1: misc_newA = subc[7:0];
		2: misc_newA = inc[7:0];
		3: misc_newA = dec[7:0];
		8: misc_newA = neg;
		9: misc_newA = neg;
		10: misc_newA = sr;
		11: misc_newA = sl;
		12: misc_newA = sr;
		13: misc_newA = sl;
		14: misc_newA = swap;
	endcase
end

wire [7:0] io_op_wval = instr[12:5] == 8'h03 ? (io_rval ^ A) : A;
wire [7:0] wval = bit_instr ? bitop_res : (ari_instr ? alu_out[7:0] : (misc_M_instr ? misc_wval : io_op_wval));

reg OV = 0;
reg AC = 0;
reg C = 0;
reg Z = 1;
reg [7:0] A = 0;
reg [7:0] SP = 0;
wire [7:0] SPm2 = SP - 2;
reg [7:0] clkmd = `CLKMD_RESET;
reg timer_inten = 0;
reg pa0_inten = 0;
reg timer_irq = 0;
reg pa0_irq = 0;
reg [7:0] t16m = 0;
reg [7:0] integs = 0;
reg [7:0] padier = 255;
reg [7:0] pa = 0;
reg [7:0] pac = 0;
reg [7:0] paph = 0;
reg [7:0] misc = 0;
reg ie = 0;

reg [7:0] tm2c;
reg [7:0] tm2ct;
reg [7:0] tm2b;
reg [7:0] tm2s;

reg [13:0] wdt = 0;
reg [13:0] wdt_timeout;
always @(*) begin
	case(misc[1:0])
		0: wdt_timeout = 2047;
		1: wdt_timeout = 4095;
		2: wdt_timeout = 16383;
		3: wdt_timeout = 255;
	endcase
end

assign pa_out = pa;
assign pa_oeb = ~pac;

reg [7:0] io_rval;
always @(*) begin
	case(io_addr)
		default: io_rval = 255;
		0: io_rval = {4'hF, OV, AC, C, Z};
		2: io_rval = SP;
		3: io_rval = clkmd;
		4: io_rval = {5'h00, timer_inten, 1'b0, pa0_inten};
		5: io_rval = {5'h00, timer_irq, 1'b0, pa0_irq};
		6: io_rval = t16m;
		9: io_rval = tm2b;
		12: io_rval = integs;
		13: io_rval = padier;
		16: io_rval = (pa_in & ~pac) | (pa & pac);
		17: io_rval = pac;
		18: io_rval = paph;
		23: io_rval = tm2s;
		27: io_rval = misc;
		28: io_rval = tm2c;
		29: io_rval = tm2ct;
	endcase
end

reg [15:0] timer = 0;
wire [15:0] timer_inc = timer + 1;
reg [5:0] tclkdiv = 0;
wire [5:0] tclkdiv_inc = tclkdiv + 1;
reg tintbit_edge = 0;
wire tintbit = timer[{1'b1, t16m[2:0]}];

reg pa4_edge = 0;
reg pa0_edge = 0;

wire interrupting = ie && (timer_irq || pa0_irq);

always @(posedge clk) begin
	if(slow_clk) slow_clk_gen <= 0;
	else slow_clk_gen <= slow_clk_gen + 1;
	pa4_edge <= pa_in[4];
	pa0_edge <= pa_in[0];
	
`ifdef BENCH
	if(instr == 13'h0006) $finish();
	if(instr == 13'h0007) begin
		$display("fail");
		$finish();
	end
`endif
	
	if(slow_clk) wdt <= wdt + 1;
	else if(!clkmd[1]) wdt <= 0;
	
	case(t16m[7:5])
		1: begin
			tclkdiv <= t16m[4:3] == 0 ? tclkdiv : tclkdiv_inc;
			timer <= t16m[4:3] == 0 ? timer_inc : timer;
		end
		3: if(!pa_in[4] && pa4_edge) begin
			tclkdiv <= t16m[4:3] == 0 ? tclkdiv : tclkdiv_inc;
			timer <= t16m[4:3] == 0 ? timer_inc : timer;
		end
		4: begin
			tclkdiv <= t16m[4:3] == 0 ? tclkdiv : tclkdiv_inc;
			timer <= t16m[4:3] == 0 ? timer_inc : timer;
		end
		6: if(slow_clk) begin
			tclkdiv <= t16m[4:3] == 0 ? tclkdiv : tclkdiv_inc;
			timer <= t16m[4:3] == 0 ? timer_inc : timer;
		end
		7: if(!pa_in[0] && pa0_edge) begin
			tclkdiv <= t16m[4:3] == 0 ? tclkdiv : tclkdiv_inc;
			timer <= t16m[4:3] == 0 ? timer_inc : timer;
		end
	endcase
	
	if((t16m[4:3] == 1 && tclkdiv == 3) || (t16m[4:3] == 2 && tclkdiv == 15) || (t16m[4:3] == 3 && tclkdiv == 63)) begin
		timer <= timer_inc;
		tclkdiv <= 0;
	end
	tintbit_edge <= tintbit;
	
	if(timer_inten) begin
		if((integs[4] && !tintbit && tintbit_edge) || (!integs[4] && !tintbit_edge && tintbit)) begin
			timer_irq <= 1;
		end
	end
	
	if(interrupting) begin
		ie <= 0;
		RAM[SP[5:1]] <= PC;
		SP <= SP + 2;
		PC <= next_PC;
		instr <= rom_val;
	end else begin
		if(special) begin
			case(special_op)
				0: begin
					//WDRESET
					wdt <= 0;
				end
				2: begin
					//PUSHAF
					RAM[SP[5:1]] <= {4'hF, OV, AC, C, Z, A};
					SP <= SP + 2;
				end
				3: begin
					//POPAF
					A <= stack_word[7:0];
					SP <= SPm2;
					OV <= stack_word[11];
					AC <= stack_word[10];
					C <= stack_word[9];
					Z <= stack_word[8];
				end
				5: begin
					//RESET
					PC <= 10'h3FF;
					clkmd <= `CLKMD_RESET;
					timer_inten <= 0;
					pa0_inten <= 0;
					t16m <= 0;
					integs <= 0;
					padier <= 255;
					pa <= 0;
					pac <= 0;
					paph <= 0;
					misc <= 0;
					wdt <= 0;
					ie <= 0;
					tclkdiv <= 0;
					tm2c <= 0;
					tm2ct <= 0;
					tm2b <= 0;
					tm2s <= 0;
				end
				6: begin
					//STOPSYS
				end
				7: begin
					//STOPEXE
				end
				8: begin
					//ENGINT
					ie <= 1;
				end
				9: begin
					//DISGINT
					ie <= 0;
				end
				10: begin
					//RET
				end
				11: begin
					//RETI
					ie <= 1;
				end
			endcase
		end
		
		if(return_instr) begin
			SP <= SPm2;
			if(retk_instr) A <= imm;
		end
		
		if(br_instr && instr[10]) begin
			RAM[SP[5:1]] <= PC + 1;
			SP <= SP + 2;
		end
		
		if(ari_instr) begin
			if(instr[9]) A <= alu_out[7:0];
			C <= alu_out[8];
			Z <= alu_out[7:0] == 0;
		end
		
		if(misc_M_instr) begin
			if(misc_op == 0) C <= addc[8];
			if(misc_op == 1) C <= subc[8];
			if(misc_op == 2 || misc_op == 4) C <= inc[8];
			if(misc_op == 3 || misc_op == 5) C <= dec[8];
			if(misc_op == 10 || misc_op == 12) C <= RAM_byte[0];
			if(misc_op == 11 || misc_op == 13) C <= RAM_byte[7];
			if(misc_op != 6 && misc_op != 7 && misc_op < 10) begin
				Z <= wval == 0;
			end
			if(misc_op == 7) A <= RAM_byte;
		end
		
		if(misc_A_instr) begin
			A <= misc_newA;
			if(misc_op == 0) C <= addc[8];
			if(misc_op == 1) C <= subc[8];
			if(misc_op == 2) C <= inc[8];
			if(misc_op == 3) C <= dec[8];
			if(misc_op == 10 || misc_op == 12) C <= A[0];
			if(misc_op == 11 || misc_op == 13) C <= A[7];
			if(misc_op < 4 || misc_op == 8 || misc_op == 9) Z <= misc_newA == 0;
		end
		
		if(op16_instr) begin
			if(instr[5]) begin
				if(instr[0]) begin
					if(RAM_word[0]) A <= RAM[RAM_word[5:1]][15:8];
					else A <= RAM[RAM_word[5:1]][7:0];
				end else begin
					if(RAM_word[0]) RAM[RAM_word[5:1]][15:8] <= A;
					else RAM[RAM_word[5:1]][7:0] <= A;
				end
			end else begin
				if(instr[0]) RAM[mem_addr[5:1]] <= timer;
				else timer <= RAM_word;
			end
		end
		
		if(instr[12:5] == 8'h05) begin
			Z <= io_rval == 0;
			A <= io_rval;
		end
		
		if(imm_instr && instr[12:8] != 5'h12) begin
			A <= alu_out[7:0];
			C <= alu_out[8];
			if(alu_op != 7) Z <= alu_out[7:0] == 0;
		end
		
		instr <= (wdt == wdt_timeout && clkmd[1]) || (clkmd[0] && !pa_in[5]) ? 13'h0035 /*RESET*/ : (skip ? 13'h0000 : rom_val);
		PC <= next_PC;
		
		if(ram_write) begin
			if(mem_addr[0]) RAM[mem_addr[5:1]][15:8] <= wval;
			else RAM[mem_addr[5:1]][7:0] <= wval;
		end
		
		if(io_write) begin
			case(io_addr)
				0: begin
					OV <= wval[3];
					AC <= wval[2];
					C <= wval[1];
					Z <= wval[0];
				end
				2: SP <= wval;
				3: clkmd <= wval;
				4: begin
					timer_inten <= wval[2];
					pa0_inten <= wval[0];
				end
				5: begin
					timer_irq <= wval[2];
					pa0_irq <= wval[0];
				end
				6: t16m <= wval;
				9: tm2b <= wval;
				12: integs <= wval;
				13: padier <= wval;
				16: pa <= wval;
				17: pac <= wval;
				18: paph <= wval;
				23: tm2s <= wval;
				27: misc <= wval;
				28: tm2c <= wval;
				29: tm2ct <= wval;
			endcase
		end
	end
end

endmodule

/*
 * Copyright (c) 2024 Grupo de Aplicaciones en Sistemas Embebidos - UTN FRH
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
// just a stub to keep the Tiny Tapeout tools happy
module tt_um_devmonk_stopwatch (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

// List all unused inputs to prevent warnings
wire _unused = ena; 
wire _unused = ui_in[7:4]; 
wire _unused = uio_in; 
wire _unused = rst_n;

// 7 segment control line bus
wire [7:0] seven_segment;
wire CLK;
wire BTN0;
wire BTN1;
wire BTN2;
wire BTN3;

// Assign 7 segment control line bus to Pmod pins
assign { uo_out[0], uo_out[1], uo_out[2], uo_out[3], uo_out[4], uo_out[5], uo_out[6], uo_out[7] } = seven_segment;
assign CLK = clk;
assign BTN0 = ui_in[0];
assign BTN1 = ui_in[1];
assign BTN2 = ui_in[2];

// Display value register and increment bus
reg [7:0] display_value = 0;
wire [7:0] display_value_inc;

// Clock divider and pulse registers
reg [20:0] clkdiv = 0;
reg clkdiv_pulse = 0;
reg running = 0;

// Synchronous logic
always @(posedge CLK) begin
	// Clock divider pulse generator
	if (clkdiv == 1200000) begin
		clkdiv <= 0;
		clkdiv_pulse <= 1;
	end else begin
		clkdiv <= clkdiv + 1;
		clkdiv_pulse <= 0;
	end


	// Timer counter
	if (clkdiv_pulse) begin
    if (running) begin
		  display_value <= display_value_inc;
    end;  
	end

	// Button controls
	if (BTN0) begin
		display_value <= 0;
		running <= 0;
	end

	if (BTN1) begin
		running <= 1;
	end

	if (BTN2) begin
		running <= 0;
	end

end

// BCD counter
bcd8_increment bot_inc (
	.din(display_value),
	.dout(display_value_inc)
);

// 7 segment display control
seven_seg_ctrl seven_segment_ctrl (
	.CLK(CLK),
	.din(display_value[7:0]),
	.dout(seven_segment)
);

endmodule

// BCD (Binary Coded Decimal) counter
module bcd8_increment (
	input [7:0] din,
	output reg [7:0] dout
);
	always @* begin
		case (1'b1)
			din[7:0] == 8'h 99:
				dout = 0;
			din[3:0] == 4'h 9:
				dout = {din[7:4] + 4'd 1, 4'h 0};
			default:
				dout = {din[7:4], din[3:0] + 4'd 1};
		endcase
	end
endmodule

// Seven segment controller
// Switches quickly between the two parts of the display
// to create the illusion of both halfs being illuminated
// at the same time.
module seven_seg_ctrl (
	input CLK,
	input [7:0] din,
	output reg [7:0] dout
);
	wire [6:0] lsb_digit;
	wire [6:0] msb_digit;

	seven_seg_hex msb_nibble (
		.din(din[7:4]),
		.dout(msb_digit)
	);

	seven_seg_hex lsb_nibble (
		.din(din[3:0]),
		.dout(lsb_digit)
	);

	reg [9:0] clkdiv = 0;
	reg clkdiv_pulse = 0;
	reg msb_not_lsb = 0;

	always @(posedge CLK) begin
		clkdiv <= clkdiv + 1;
		clkdiv_pulse <= &clkdiv;
		msb_not_lsb <= msb_not_lsb ^ clkdiv_pulse;

		if (clkdiv_pulse) begin
			if (msb_not_lsb) begin
				dout[6:0] <= ~msb_digit;
				dout[7] <= 0;
			end else begin
				dout[6:0] <= ~lsb_digit;
				dout[7] <= 1;
			end
		end
	end
endmodule

// Convert 4bit numbers to 7 segments
module seven_seg_hex (
	input [3:0] din,
	output reg [6:0] dout
);
	always @*
		case (din)
			4'h0: dout = 7'b 0111111;
			4'h1: dout = 7'b 0000110;
			4'h2: dout = 7'b 1011011;
			4'h3: dout = 7'b 1001111;
			4'h4: dout = 7'b 1100110;
			4'h5: dout = 7'b 1101101;
			4'h6: dout = 7'b 1111101;
			4'h7: dout = 7'b 0000111;
			4'h8: dout = 7'b 1111111;
			4'h9: dout = 7'b 1101111;
			4'hA: dout = 7'b 1110111;
			4'hB: dout = 7'b 1111100;
			4'hC: dout = 7'b 0111001;
			4'hD: dout = 7'b 1011110;
			4'hE: dout = 7'b 1111001;
			4'hF: dout = 7'b 1110001;
			default: dout = 7'b 1000000;
		endcase

endmodule

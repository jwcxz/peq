/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * ram.v                   *
 * dual port block RAM     *
 * *********************** */

/* 
 * block RAM module (modified from lab 4)
 *
 * gain curve calculations:
 *    with a 8192-FFT, we need 8192 locations:
 *        LOGSIZE=13
 *
 *    we'll use an 8 bit value for the gain curve display:
 *        WIDTH=8
 *
 *    and a 12 bit value for the curve itself
 *        WIDTH=12
*/

///////////////////////////////////////////////////////////////////////////////
//
// Verilog equivalent to a BRAM, tools will infer the right thing!
// number of locations = 1<<LOGSIZE, width in bits = WIDTH.
// default is a 16K x 1 memory.
//
///////////////////////////////////////////////////////////////////////////////

module blockram
    #(parameter LOGSIZE=14, WIDTH=1)
    (input wire [LOGSIZE-1:0] addr,
        input wire clk,
        input wire [WIDTH-1:0] din,
        output reg [WIDTH-1:0] dout,
        input wire we,

        input wire clkb,
        input wire [LOGSIZE-1:0] addrb,
        output reg [WIDTH-1:0] doutb
    );

    // let the tools infer the right number of BRAMs
    (* ram_style = "block" *)
    reg [WIDTH-1:0] mem[(1<<LOGSIZE)-1:0];
    always @(posedge clk) begin
      if (we) mem[addr] <= din;
      dout <= mem[addr];
    end

    always @(posedge clkb) begin
        doutb <= mem[addrb];
    end

endmodule

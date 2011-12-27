/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * gcdisplay.v             *
 * gain curve display      *
 * *********************** */

module gcdisplay #(parameter LOGFFTSIZE=0, AUDIOWIDTH=0, DISPLWIDTH=0)
    (
        input wire clk,
        input wire rst,

        input wire [10:0] hcount,
        input wire [ 9:0] vcount,
        input wire hsync, vsync, blank,

        output reg [2:0] pixel,

        output wire [9:0] addr,
        input wire [DISPLWIDTH-1:0] data
    );

    assign addr = hcount[9:0];

    always @ (posedge clk) begin
        if ( hcount <= 1023 && vcount <= 255 - data || vcount >= 255 ) begin
            pixel <= 0;
        end else begin
            pixel <= 3;
        end
    end

endmodule

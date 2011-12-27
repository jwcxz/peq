/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * fftdisplay.v            *
 * display fft output      *
 * *********************** */

module fftdisplay #(parameter LOGFFTSIZE=0, LOGDSPSIZE=0, AUDIOWIDTH=0, DISPLWIDTH=0)
        (
            input wire clk,
            input wire rst,

            output wire [2:0] pixel,
            input wire [10:0] hcount,
            input wire [9:0] vcount,
            input wire hsync, vsync, blank,

            output wire [LOGDSPSIZE-1:0] addr,
            input wire [2*DISPLWIDTH-1:0] data
        );

    assign addr = hcount;

    reg [2:0] pxl1, pxl2;
    assign pixel = pxl1 | pxl2;

    always @ (posedge clk) begin
        if ( hcount <= 1023 && vcount >= 256 && vcount - 256 >= 255 - data[15:8] && vcount <= 511 )
            pxl1 <= 3'b001;
        else if ( vcount >= 256 && vcount <= 511 )
            pxl1 <= 3'b110;
        else
            pxl1 <= 3'b000;

        if ( hcount <= 1023 && vcount >= 512 && vcount - 512 >= 255 - data[7:0] && vcount <= 767 )
            pxl2 <= 3'b010;
        else if ( vcount >= 512 && vcount <= 767 )
            pxl2 <= 3'b101;
        else
            pxl2 <= 3'b000;

    end

endmodule

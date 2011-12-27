/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * gcreset.v               *
 * reset gain curve        *
 * *********************** */

module gcreset #(parameter LOGFFTSIZE=0, AUDIOWIDTH=0, DISPLWIDTH=0)
    (
        input wire clk,
        input wire rst,

        // controls
        input wire do_reset,
        output reg reset_done,

        output wire [LOGFFTSIZE-1:0] gcurve_addr,
        output wire [9:0] gcdisp_addr,
        output reg [AUDIOWIDTH-1:0] gcurve_din,
        output reg [DISPLWIDTH-1:0] gcdisp_din,
        output reg gcurve_we, gcdisp_we
    );

    reg [LOGFFTSIZE-1:0] index;

    assign gcurve_addr = index;
    assign gcdisp_addr = index >> (LOGFFTSIZE-10); // divide by 8 -> 8192/8 = 1024;

    always @ (posedge clk) begin
        if (rst) begin
            reset_done <= 1;
            gcurve_we <= 0;
            gcdisp_we <= 0;
            index <= 0;
        end else if (do_reset) begin
            reset_done <= 0;
            gcurve_we <= 1;
            gcdisp_we <= 1;
            index <= 0;
        end else if (!reset_done) begin 
            gcurve_we <= 1;
            gcdisp_we <= 1;

            gcurve_din <= 1<<AUDIOWIDTH - 1;
            gcdisp_din <= 0;

            if ( index == (1<<LOGFFTSIZE)-1 ) begin
                reset_done <= 1;
            end else begin
                index <= index + 1;
            end
        end
    end

endmodule

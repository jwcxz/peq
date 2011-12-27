/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * gcserinp.v              *
 * get gain curve from ser *
 * *********************** */

module gcserinp #(parameter LOGFFTSIZE=0, LOGDSPSIZE=0, AUDIOWIDTH=0, DISPLWIDTH=0, GCRVEWIDTH=0)
    (   input clk,
        input rst,

        input run,
        input rxd,

        output wire [LOGFFTSIZE-1:0] gcurve_addr,
        output wire [LOGDSPSIZE-1:0] gcdisp_addr,
        output reg [GCRVEWIDTH-1:0] gcurve_din,
        output reg [DISPLWIDTH-1:0] gcdisp_din,
        output reg gcurve_we,
        output reg gcdisp_we,

        output wire [15:0] debug
    );

    reg [LOGFFTSIZE-1:0] index;
    reg working;

    assign gcurve_addr = index;
    assign gcdisp_addr = index >> (LOGFFTSIZE-LOGDSPSIZE);

    reg [7:0] serdata;
    reg rda;

    parameter ST_DATA = 0;
    parameter ST_DONE = 1;
    reg smcur, smnxt;

    wire rd;
    assign rd = ( smcur == ST_DATA ) ? 0 : ( smcur == ST_DONE ) ? 1 : 0;

    reg [7:0] dbout;
    reg txd, pe, fe, oe;
    wire tbe;

    Rs232RefComp rs232 (
        .RXD(rxd),
        .CLK(clk),
        .RST(rst),
        .DBOUT(serdata),
        .RDA(rda),
        .RD(rd),

        .TXD(txd),
        .DBIN(dbout),
        .TBE(tbe),
        .WR(1'b0),
        .PE(pe),
        .FE(fe),
        .OE(oe)
    );

    assign debug[7:0] = serdata;
    assign debug[15] = smcur;
    assign debug[14] = rda;
    assign debug[13] = rd;
    assign debug[12:8] = 0;

    always @ (posedge clk) begin
        if (rst) begin
            gcurve_we <= 0;
            gcdisp_we <= 0;
            index <= 0;
        end else begin
            if (!run) begin
                index <= 0;
                gcurve_we <= 0;
                gcdisp_we <= 0;
                working <= 1;
                smcur <= ST_DATA;
            end else if (!working) begin
                gcurve_we <= 0;
                gcdisp_we <= 0;
            end else begin
                gcurve_we <= 1;
                gcdisp_we <= 1;
                smcur <= smnxt;

                if ( smcur == ST_DATA ) begin
                    gcurve_din <= serdata;
                    gcdisp_din <= serdata;
                end

                if ( smcur == ST_DONE ) begin
                    if ( index == (1<<LOGFFTSIZE) - 1 ) begin
                        working <= 0;
                        smcur <= ST_DATA;
                    end else begin
                        index <= index + 1;
                    end
                end
            end
        end
    end

    always @ (*) begin
        case (smcur)
            ST_DATA:
               if (rda) smnxt = ST_DONE;
               else     smnxt = ST_DATA;

            ST_DONE:
               smnxt = ST_DATA;
        endcase
    end
    
endmodule

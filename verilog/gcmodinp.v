/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * gcmodinp.v              *
 * gain curve modifier     *
 *   input method (not     *
 *   working)              *
 * *********************** */

module gcmodinp #(parameter LOGFFTSIZE=0, AUDIOWIDTH=0, DISPLWIDTH=0)
    (
        input wire clk,
        input wire rst,

        input wire btn_rst, btn_add, btn_a, btn_b, btn_c, btn_up, btn_down,

        output wire [15:0] hex,

        input wire [AUDIOWIDTH-1:0] gcurve_dout,
        input wire [DISPLWIDTH-1:0] gcdisp_dout,

        output wire [LOGFFTSIZE-1:0] gcurve_addr,
        output wire [9:0] gcdisp_addr,
        output wire [AUDIOWIDTH-1:0] gcurve_din,
        output wire [DISPLWIDTH-1:0] gcdisp_din,
        output wire gcurve_we, gcdisp_we,

        output wire busy
    );

    parameter ST_BINN = 0;
    parameter ST_WDTH = 1;
    parameter ST_GAIN = 2;
    parameter ST_RCMP_ST = 3;
    parameter ST_RCMP_WT = 4;
    parameter ST_RSET_ST = 5;
    parameter ST_RSET_WT = 6;
    parameter ST_DONE = 7;
    reg [2:0] smcur, smnxt;
    
    // controls
    wire do_recompute, do_reset;
    wire recompute_done, reset_done;

    // storage elements to hold parameters
    reg [LOGFFTSIZE-1:0] bin_num;
    reg [LOGFFTSIZE-1-1:0] bin_width;
    reg [AUDIOWIDTH-1:0] bin_gain;

    //////////////////////////////////
    // HEX DISPLAY
    //////////////////////////////////
        assign hex = ( smcur == ST_BINN ) ? {3'b000,  bin_num} :
                     ( smcur == ST_WDTH ) ? {4'b1010, bin_width} :
                     ( smcur == ST_GAIN ) ? {4'b1011, bin_gain} :
                     16'hFFFF;

    //////////////////////////////////
    // BUSY SIGNAL
    //////////////////////////////////
        assign busy = ( smcur == ST_RCMP_ST || ST_RCMP_WT || ST_RSET_ST || ST_RSET_WT || ST_DONE ) ? 1 : 0;

        wire [LOGFFTSIZE-1:0] gcurve_addr_rs, gcurve_addr_rc;
        wire [DISPLWIDTH:0] gcdisp_addr_rs, gcdisp_addr_rc;
        wire [AUDIOWIDTH-1:0] gcurve_din_rs, gcurve_din_rc;
        wire [DISPLWIDTH-1:0] gcdisp_din_rs, gcdisp_din_rc;
        wire gcurve_we_rc, gcurve_we_rs, gcdisp_we_rc, gcdisp_we_rs;

        assign gcurve_addr = ( smcur == ST_RSET_ST || smcur == ST_RSET_WT ) ? gcurve_addr_rs : 
                             ( smcur == ST_RCMP_ST || smcur == ST_RCMP_WT ) ? gcurve_addr_rc : 0;
        assign gcdisp_addr = ( smcur == ST_RSET_ST || smcur == ST_RSET_WT ) ? gcdisp_addr_rs : 
                             ( smcur == ST_RCMP_ST || smcur == ST_RCMP_WT ) ? gcdisp_addr_rc : 0;
        assign gcurve_din = ( smcur == ST_RSET_ST || smcur == ST_RSET_WT ) ? gcurve_din_rs : 
                             ( smcur == ST_RCMP_ST || smcur == ST_RCMP_WT ) ? gcurve_din_rc : 0;
        assign gcdisp_din = ( smcur == ST_RSET_ST || smcur == ST_RSET_WT ) ? gcdisp_din_rs : 
                             ( smcur == ST_RCMP_ST || smcur == ST_RCMP_WT ) ? gcdisp_din_rc : 0;
        assign gcurve_we = ( smcur == ST_RSET_ST || smcur == ST_RSET_WT ) ? gcurve_we_rs : 
                             ( smcur == ST_RCMP_ST || smcur == ST_RCMP_WT ) ? gcurve_we_rc : 0;
        assign gcdisp_we = ( smcur == ST_RSET_ST || smcur == ST_RSET_WT ) ? gcdisp_we_rs : 
                             ( smcur == ST_RCMP_ST || smcur == ST_RCMP_WT ) ? gcdisp_we_rc : 0;

        assign do_recompute = ( smcur == ST_RCMP_ST );
        assign do_reset = ( smcur == ST_RSET_ST );

    //////////////////////////////////
    // GAIN CURVE RESET MODULE
    //////////////////////////////////
        gcreset #(.LOGFFTSIZE(LOGFFTSIZE), .AUDIOWIDTH(AUDIOWIDTH), .DISPLWIDTH(DISPLWIDTH)) rs1
            (
                .clk(clk),
                .rst(rst),

                .do_reset(do_reset),
                .reset_done(reset_done),

                .gcurve_addr(gcurve_addr_rs),
                .gcdisp_addr(gcdisp_addr_rs),
                .gcurve_din(gcurve_din_rs),
                .gcdisp_din(gcdisp_din_rs),
                .gcurve_we(gcurve_we_rs),
                .gcdisp_we(gcdisp_we_rs)
            );


    //////////////////////////////////
    // RECOMPUTATION MODULE
    //////////////////////////////////
        gcrecomp #(.LOGFFTSIZE(LOGFFTSIZE), .AUDIOWIDTH(AUDIOWIDTH), .DISPLWIDTH(DISPLWIDTH)) rc1
            (
                .clk(clk),
                .rst(rst),

                .do_recompute(do_recompute),
                .recompute_done(recompute_done),

                .bin_num(bin_num),
                .bin_width(bin_width),
                .bin_gain(bin_gain),

                .gcurve_addr(gcurve_addr_rc),
                .gcdisp_addr(gcdisp_addr_rc),
                .gcurve_din(gcurve_din_rc),
                .gcdisp_din(gcdisp_din_rc),
                .gcurve_dout(gcurve_dout),
                .gcdisp_dout(gcdisp_dout),
                .gcurve_we(gcurve_we_rc),
                .gcdisp_we(gcdisp_we_rc)
            );

    //////////////////////////////////
    // MASTER STATE MACHINE
    // 0 BINN bin #
    // 1 WDTH bin width
    // 2 GAIN gain step
    // 3 RCMP perform recomputation of gain curve
    // 4 DONE reset values, return back to 0
    //////////////////////////////////
        always @ (posedge clk)
        begin
            if (rst) begin
                smcur <= ST_BINN;
                bin_num <= 0;
                bin_width <= 0;
                bin_gain <= 0;
            end else begin
                 if ( smcur == ST_DONE ) begin
                     bin_num <= 0;
                     bin_width <= 0;
                     bin_gain <= 0;
                 end else if ( btn_up ) begin
                     case (smcur)
                        ST_BINN:
                            bin_num <= bin_num + 1;
                        ST_WDTH:
                            bin_width <= bin_width + 1;
                        ST_GAIN:
                            bin_gain <= 8;
                    endcase
                 end else if ( btn_down ) begin
                     case (smcur)
                        ST_BINN:
                            bin_num <= bin_num - 1;
                        ST_WDTH:
                            bin_width <= bin_width - 1;
                        ST_GAIN:
                            bin_gain <= 16;
                     endcase
                end
                smcur <= smnxt;
           end
        end

        always @ (*)
        begin
           case (smcur)
               ST_RCMP_ST:
                   smnxt = ST_RCMP_WT;

               ST_RCMP_WT:
                   if (recompute_done) smnxt = ST_DONE;
                   else smnxt = ST_RCMP_WT;

               ST_RSET_ST:
                   smnxt = ST_RSET_WT;

               ST_RSET_WT:
                   if (reset_done) smnxt = ST_DONE;
                   else smnxt = ST_RSET_WT;

               ST_DONE:
                   smnxt = ST_BINN;

               default:
                   if ( btn_a ) smnxt = ST_BINN;
                   else if ( btn_b ) smnxt = ST_WDTH;
                   else if ( btn_c ) smnxt = ST_GAIN;
                   else if ( btn_add ) smnxt = ST_RCMP_ST;
                   else if ( btn_rst ) smnxt = ST_RSET_ST;
                   else smnxt = smcur;
           endcase
        end

endmodule

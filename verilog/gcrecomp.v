/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * gcrecomp.v              *
 * recurve gain curve (not *
 *   working)              *
 * *********************** */

module gcrecomp #(parameter LOGFFTSIZE=0, AUDIOWIDTH=0, DISPLWIDTH=0)
    (
        input wire clk,
        input wire rst,

        // controls
        input wire do_recompute,
        output reg recompute_done,

        input wire [LOGFFTSIZE-1:0] bin_num,
        input wire [LOGFFTSIZE-1-1:0] bin_width,
        input wire [AUDIOWIDTH-1:0] bin_gain,

        output wire [LOGFFTSIZE-1:0] gcurve_addr,
        output wire [9:0] gcdisp_addr,
        output reg [AUDIOWIDTH-1:0] gcurve_din,
        output reg [DISPLWIDTH-1:0] gcdisp_din,
        input wire [AUDIOWIDTH-1:0] gcurve_dout,
        input wire [DISPLWIDTH-1:0] gcdisp_dout,
        output reg gcurve_we, gcdisp_we
    );

    reg [LOGFFTSIZE-1:0] index;
    reg [LOGFFTSIZE-1:0] bin_lo, bin_hi, bin_lo1, bin_hi1, bin_lo2, bin_hi2;

    assign gcurve_addr = index;
    assign gcdisp_addr = index >> (LOGFFTSIZE-10);

    reg [AUDIOWIDTH-1:0] newwav;
    reg [AUDIOWIDTH-1:0] gcurve_cur;

    always @ (posedge clk) begin
        if (rst) begin
            recompute_done <= 1;
            gcurve_we <= 0;
            gcdisp_we <= 0;
            index <= 0;
            newwav <= 0;
        end else if (do_recompute) begin
            recompute_done <= 0;
            gcurve_we <= 0;
            gcdisp_we <= 0;
            index <= 0;
            newwav <= 1<<DISPLWIDTH - 1;
        end else if (!recompute_done) begin
            if ( index == 0 && gcurve_we == 0 ) begin
                // new gain curve update
                // -> set bin_lo and bin_hi (bin_hi > bin_lo or we don't proceed)

                if ( bin_num <= bin_width>>2 ) bin_lo2 <= 0;
                else bin_lo2 <= bin_num - bin_width>>2;

                if ( bin_num <= bin_width>>1 ) bin_lo1 <= 0;
                else bin_lo1 <= bin_num - bin_width>>1;

                if ( bin_num <= bin_width ) bin_lo <= 0;
                else bin_lo <= bin_num - bin_width;


                if ( (1<<LOGFFTSIZE)-1 - bin_width>>2 >= bin_num ) bin_hi2 <= (1<<LOGFFTSIZE)-1;
                else bin_hi2 <= bin_num + bin_width>>2;

                if ( (1<<LOGFFTSIZE)-1 - bin_width>>1 >= bin_num ) bin_hi1 <= (1<<LOGFFTSIZE)-1;
                else bin_hi1 <= bin_num + bin_width>>1;

                if ( (1<<LOGFFTSIZE)-1 - bin_width >= bin_num ) bin_hi <= (1<<LOGFFTSIZE)-1;
                else bin_hi <= bin_num + bin_width;

                gcurve_we <= 1;
                gcdisp_we <= 1;
                gcurve_cur <= gcurve_dout;

            end else begin
                // in active mode

                if ( !gcurve_we ) begin
                    // in read phase, update gcurve_cur
                    gcurve_cur <= gcurve_dout;
                    gcurve_we <= 1;
                    gcdisp_we <= 1;
                    
                end else begin
                    // in write mode, update the RAM

                    /*
                        ||  |   |     |   |  ||  
                    ____||__|___|_____|___|__||____
                        lo lo1 lo2   hi2 hi1 hi
                    */

                    if ( index > bin_lo && index < bin_num ) begin
                        newwav <= newwav - bin_gain;
                    end else if ( index > bin_num && index < bin_hi ) begin
                        newwav <= newwav + bin_gain;
                    end

                    /*
                    if ( index < bin_lo ) begin
                        gcurve_din <= gcurve_cur;
                        gcdisp_din <= (1<<DISPLWIDTH)-1 - ((gcurve_cur) >> (AUDIOWIDTH-DISPLWIDTH));
                    end else if ( index < bin_lo1 ) begin
                        gcurve_din <= gcurve_cur >> 1 + newwav >> 1;
                        gcdisp_din <= (1<<DISPLWIDTH)-1 - ((gcurve_cur >> 1 + newwav >> 1) >> (AUDIOWIDTH-DISPLWIDTH));
                    end else if ( index < bin_lo2 ) begin
                        gcurve_din <= gcurve_cur >> 2 + newwav >> 1 + newwav >> 2;
                        gcdisp_din <= (1<<DISPLWIDTH)-1 - ((gcurve_cur >> 2 + newwav >> 1 + newwav >> 2) >> (AUDIOWIDTH-DISPLWIDTH));
                    end else if ( index < bin_hi2 ) begin
                        gcurve_din <= newwav;
                        gcdisp_din <= (1<<DISPLWIDTH)-1 - ((newwav) >> (AUDIOWIDTH-DISPLWIDTH));

                    end else if ( index < bin_hi1 ) begin
                        gcurve_din <= gcurve_cur >> 2 + newwav >> 1 + newwav >> 2;
                        gcdisp_din <= (1<<DISPLWIDTH)-1 - ((gcurve_cur >> 2 + newwav >> 1 + newwav >> 2) >> (AUDIOWIDTH-DISPLWIDTH));
                    end else if ( index < bin_hi ) begin
                        gcurve_din <= gcurve_cur >> 1 + newwav >> 1;
                        gcdisp_din <= (1<<DISPLWIDTH)-1 - ((gcurve_cur >> 1 + newwav >> 1) >> (AUDIOWIDTH-DISPLWIDTH));
                    end else begin
                        gcurve_din <= gcurve_cur;
                        gcdisp_din <= (1<<DISPLWIDTH)-1 - ((gcurve_cur) >> (AUDIOWIDTH-DISPLWIDTH));
                    end
                    */

                   gcurve_din <= newwav;
                   //gcdisp_din <= (newwav) >> (AUDIOWIDTH-DISPLWIDTH);
                   gcdisp_din <= newwav;

                    gcurve_we <= 0;
                    gcdisp_we <= 0;

                    if ( index == (1<<LOGFFTSIZE)-1 ) begin
                        recompute_done <= 1;
                        bin_lo <= 0;
                        bin_hi <= 0;
                        index <= 0;
                    end else begin
                        index <= index + 1;
                    end
                end
            end
        end
    end

endmodule

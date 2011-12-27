`default_nettype none

/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * peq.v                   *
 * main equalizer module   *
 * *********************** */

module pequalizer( // {{{
    input wire clk, clk65,
    input wire rst,

    // serial com
    input wire rs232_rxd,

    // buttons
    //input wire btn_rst, btn_add, btn_left, btn_up, btn_right, btn_down,
    input wire btn_rst, btn_add, btn_a, btn_b, btn_c, btn_up, btn_down,
    input wire [1:0] sw_inpmtd,

    // vga
    input wire [10:0] hcount,
    input wire [9:0] vcount,
    input wire hsync, vsync, blank,
    output wire [2:0] pixel,
    output wire phsync, pvsync, pblank,

    // hex
    output wire [15:0] hex,

    // ac97
    input wire  [11:0] from_ac97_data,
    output wire [11:0] to_ac97_data,
    input wire audio_ready,

    // controls
    input wire ifft_select,
    input wire [2:0] fft_delay,
    input wire ifft_reg,

    // debug
    //   (to hex display)
    output wire [15:0] debug,
    output wire [15:0] debug2,

    //   (to logic analyzer)
    output wire [15:0] dbg_fftdone,
    output wire [15:0] dbg_fftidx, dbg_ifftidx,
    output wire [15:0] dbg_fftout
); // }}}

    parameter LOGFFTSIZE = 10;      // 1024-point FFT
    parameter LOGDSPSIZE = 10;      // 1024-wide display

    parameter AUDIOWIDTH = 12;      // 12-bit audio
    parameter GCRVEWIDTH =  8;
    parameter DISPLWIDTH =  8;      // 8-bit gain curve display

    parameter FFTOUTSIZE = LOGFFTSIZE + AUDIOWIDTH + 1;      // size of fft output

    //////////////////////////////////
    // BLOCK RAMS (dual port)
    // instantiate RAM according to calculations in ram.v
    // gcurve is the gain curve RAM and gcdisp is the RAM for the display
    // fftram holds the current FFT
    // these RAMs have a read-only B port in addition to a read-write A port
    ////////////////////////////////// {{{
        wire [LOGFFTSIZE-1:0] gcurve_addr_in, gcurve_addr_out;
        wire [LOGDSPSIZE-1:0] gcdisp_addr_in, gcdisp_addr_out;

        wire [GCRVEWIDTH-1:0] gcurve_din, gcurve_dout, gcurve_doutb;
        wire [DISPLWIDTH-1:0] gcdisp_din, gcdisp_dout, gcdisp_doutb;
        wire gcurve_we, gcdisp_we;

        blockram #(.LOGSIZE(LOGFFTSIZE), .WIDTH(GCRVEWIDTH)) gcurveram1 
            (.clk(clk), .addr(gcurve_addr_in), .din(gcurve_din),
                .dout(gcurve_dout), .we(gcurve_we), 
                .clkb(clk), .addrb(gcurve_addr_out), .doutb(gcurve_doutb));

        blockram #(.LOGSIZE(LOGDSPSIZE), .WIDTH(DISPLWIDTH)) gcdispram1 
            (.clk(clk), .addr(gcdisp_addr_in), .din(gcdisp_din),
                .dout(gcdisp_dout), .we(gcdisp_we), 
                .clkb(clk65), .addrb(gcdisp_addr_out), .doutb(gcdisp_doutb));

        ////////////////////
        // FFT DISPLAY RAM
        ////////////////////
        wire [LOGDSPSIZE-1:0] fftram_addr_in, fftram_addr_out;
        wire [2*DISPLWIDTH-1:0] fftram_din, fftram_dout, fftram_doutb;
        wire fftram_we;

        blockram #(.LOGSIZE(LOGDSPSIZE), .WIDTH(2*DISPLWIDTH)) fftram1 
            (.clk(clk), .addr(fftram_addr_in), .din(fftram_din),
                .dout(fftram_dout), .we(fftram_we), 
                .clkb(clk65), .addrb(fftram_addr_out), .doutb(fftram_doutb));
    // }}}


    //////////////////////////////////
    // AUDIO IN -> FFT
    // here, we take a pipelined, streaming FFT of from_ac97_data and place
    // the output on fft_out_re and fft_out_im.  the fft is run only when
    // audio_ready is high, since we shouldn't be doing anything when the ac97
    // isn't sending out valid data
    //
    // fft_index is used to specify the location of the block ram to store the
    // appropriate bin.  it's also sent out to a debug signal.
    //
    // fft_dv tells us when fft_out_* becomes valid and therefore is used to
    // start the IFFT.  fft_done is asserted every N cycles and is used for
    // debugging.
    //
    // lastly, we need to delay output of the FFT by 3 cycles when feeding it
    // into the IFFT.
    ////////////////////////////////// {{{
        wire signed [FFTOUTSIZE-1:0] fft_out_im, fft_out_re;

        reg signed [FFTOUTSIZE-1:0] fft_out_re_1, fft_out_re_2, fft_out_re_3,
            fft_out_re_4, fft_out_re_5, fft_out_re_6, fft_out_re_7;
        reg signed [FFTOUTSIZE-1:0] fft_out_im_1, fft_out_im_2, fft_out_im_3,
            fft_out_im_4, fft_out_im_5, fft_out_im_6, fft_out_im_7;

        wire signed [FFTOUTSIZE-1:0] fft_out_re_final, fft_out_im_final;

        wire [LOGFFTSIZE-1:0] fft_index, ifft_index;

        reg [LOGFFTSIZE-1:0] fft_index_1, fft_index_2, fft_index_3,
            fft_index_4, fft_index_5, fft_index_6, fft_index_7;

        wire [LOGFFTSIZE-1:0] fft_index_final;

        wire fft_done, fft_dv;

        reg [AUDIOWIDTH-1:0] from_ac97_data_reg;
        always @ (posedge clk) begin
            if ( audio_ready || ifft_reg ) begin
                audio_ready_reg <= audio_ready;
                from_ac97_data_reg <= from_ac97_data;
            end
        end

        fft1024un fft(.clk(clk), .ce(rst | audio_ready),
            .xn_re(from_ac97_data_reg), .xn_im(12'b0), .start(1'b1),
            .fwd_inv(1'b1), .fwd_inv_we(rst), .xk_re(fft_out_re),
            .xk_im(fft_out_im), .xk_index(fft_index), .done(fft_done),
            .dv(fft_dv));

        // stupid debug tool to get the 3 cycles right
        always @ (posedge clk) begin
            // only change when audio_ready goes high
            if (audio_ready) begin
                // delay by 1
                    fft_out_re_1 <= fft_out_re;
                    fft_out_im_1 <= fft_out_im;
                    fft_index_1 <= fft_index;
                // delay by 2
                    fft_out_re_2 <= fft_out_re_1;
                    fft_out_im_2 <= fft_out_im_1;
                    fft_index_2 <= fft_index_1;
                // delay by 3
                    fft_out_re_3 <= fft_out_re_2;
                    fft_out_im_3 <= fft_out_im_2;
                    fft_index_3 <= fft_index_2;
                // delay by 4
                    fft_out_re_4 <= fft_out_re_3;
                    fft_out_im_4 <= fft_out_im_3;
                    fft_index_4 <= fft_index_3;
                // delay by 5
                    fft_out_re_5 <= fft_out_re_4;
                    fft_out_im_5 <= fft_out_im_4;
                    fft_index_5 <= fft_index_4;
                // delay by 6
                    fft_out_re_6 <= fft_out_re_5;
                    fft_out_im_6 <= fft_out_im_5;
                    fft_index_6 <= fft_index_5;
                // delay by 7
                    fft_out_re_7 <= fft_out_re_6;
                    fft_out_im_7 <= fft_out_im_6;
                    fft_index_7 <= fft_index_6;
            end
        end

        // set the delay based on the fft_delay input
        assign fft_out_re_final = (fft_delay == 0) ? fft_out_re   :
                                  (fft_delay == 1) ? fft_out_re_1 :
                                  (fft_delay == 2) ? fft_out_re_2 :
                                  (fft_delay == 3) ? fft_out_re_3 :
                                  (fft_delay == 4) ? fft_out_re_4 :
                                  (fft_delay == 5) ? fft_out_re_5 :
                                  (fft_delay == 6) ? fft_out_re_6 :
                                  (fft_delay == 7) ? fft_out_re_7 : 0;

        assign fft_out_im_final = (fft_delay == 0) ? fft_out_im   :
                                  (fft_delay == 1) ? fft_out_im_1 :
                                  (fft_delay == 2) ? fft_out_im_2 :
                                  (fft_delay == 3) ? fft_out_im_3 :
                                  (fft_delay == 4) ? fft_out_im_4 :
                                  (fft_delay == 5) ? fft_out_im_5 :
                                  (fft_delay == 6) ? fft_out_im_6 :
                                  (fft_delay == 7) ? fft_out_im_7 : 0;

        assign fft_index_final =  (fft_delay == 0) ? fft_index   :
                                  (fft_delay == 1) ? fft_index_1 :
                                  (fft_delay == 2) ? fft_index_2 :
                                  (fft_delay == 3) ? fft_index_3 :
                                  (fft_delay == 4) ? fft_index_4 :
                                  (fft_delay == 5) ? fft_index_5 :
                                  (fft_delay == 6) ? fft_index_6 :
                                  (fft_delay == 7) ? fft_index_7 : 0;
    // }}}


    //////////////////////////////////
    // GAIN CURVE APPLICATION
    // multiply each component of the fft by the associated value in the gain
    // curve.  this takes one clock cycle, which won't affect the overall
    // delay requirement of the IFFT input since audio_ready is asserted much
    // more slowly than clk_27mhz
    // 
    // after multiplying by the gain curve value, divide by the maximum gain
    // curve value (2^GCRVEWIDTH)
    //
    // finally, the IFFT mandates that its input must be scaled down by the
    // number of points in the FFT
    //      since the IFFT and the FFT have the same number of points and the
    //      output of the FFT has width W+N+1 where W is the input width and
    //      N is lg(number of points), the IFFT should take 
    //          fft[W+N+1:0] >> N
    //      however, note that we are in the special case where the number of
    //      points of the FFT and the IFFT are equal, so we can just take the
    //      top AUDIOWIDTH (i.e. the input size of the IFFT) points since that
    //      will include both the N scaling factor (which alone will generate
    //      an output width of AUDIOWIDTH+1) and the correction for the
    //      disparity in input size (the extra bit)
    //
    //      the N scaling factor only becomes important if the IFFT has more
    //      points than the FFT, but we aren't doing that here
    ////////////////////////////////// {{{
        reg signed [FFTOUTSIZE+GCRVEWIDTH-1:0] mult_re, mult_im;
        wire signed [FFTOUTSIZE-1:0] mult_re_shifted, mult_im_shifted;
        wire signed [AUDIOWIDTH-1:0] mult_re_out, mult_im_out;

        assign gcurve_addr_out = fft_index_final;

        always @ (posedge clk) begin
            mult_re <= fft_out_re_final * $unsigned(gcurve_doutb);
            mult_im <= fft_out_im_final * $unsigned(gcurve_doutb);
        end

        assign mult_re_shifted = mult_re >>> GCRVEWIDTH;
        assign mult_im_shifted = mult_im >>> GCRVEWIDTH;

        // ifft_select selects whether to use the just the output of the FFT
        // (1) or the value multiplied by the gain curve (0)
        assign mult_re_out = (ifft_select) ?
            fft_out_re_final[FFTOUTSIZE-1:FFTOUTSIZE-AUDIOWIDTH] :
                mult_re_shifted[FFTOUTSIZE-1:FFTOUTSIZE-AUDIOWIDTH];

        assign mult_im_out = (ifft_select) ?
            fft_out_im_final[FFTOUTSIZE-1:FFTOUTSIZE-AUDIOWIDTH] :
                mult_im_shifted[FFTOUTSIZE-1:FFTOUTSIZE-AUDIOWIDTH];
    // }}}

    
    //////////////////////////////////
    // AUDIO OUT
    // we take the 12-bit, delayed mult_re_out and feed it into the IFFT with
    // the appropriate control signal to start the module (data valid of the
    // FFT)
    ////////////////////////////////// {{{
        wire signed [FFTOUTSIZE-1:0] ifft_out_re, ifft_out_im;
        wire ifft_done;

        fft1024un ifft(.clk(clk), .ce(rst | audio_ready),
            .xn_re(mult_re_out),
            .xn_im(mult_im_out),
            .start(fft_dv), .fwd_inv(1'b0),
            .fwd_inv_we(rst), .xk_re(ifft_out_re), .xk_im(ifft_out_im),
            .xk_index(ifft_index), .done(ifft_done));

        reg [AUDIOWIDTH-1:0] to_ac97_data_reg;

        assign to_ac97_data = to_ac97_data_reg;

        always @ (posedge clk) begin
            if ( audio_ready || ifft_reg ) begin
                to_ac97_data_reg <= ifft_out_re;
            end
        end
    // }}}

        
    //////////////////////////////////
    // FFT DISPLAY
    // we store the absolute values of the real and imaginary components of
    // the FFT output to a block RAM for display with the fftdisplay module.
    ////////////////////////////////// {{{
        reg fftram_we_reg;
        reg [LOGDSPSIZE-1:0] fftram_addr_in_reg;
        reg [2*DISPLWIDTH-1:0] fftram_din_reg;

        // just a stupid refactoring -- can be optimized out safely
        assign fftram_we = fftram_we_reg;
        assign fftram_addr_in = fftram_addr_in_reg;
        assign fftram_din = fftram_din_reg;

        always @ (posedge clk) begin
            fftram_we_reg <= 1;
            fftram_addr_in_reg <= fft_index[LOGFFTSIZE-1:LOGFFTSIZE-LOGDSPSIZE];

            // store the absolute value of each signal
            case ({fft_out_re[FFTOUTSIZE-1], fft_out_im[FFTOUTSIZE-1]})
                2'b00:
                    fftram_din_reg <=
                    { fft_out_re[FFTOUTSIZE-1:FFTOUTSIZE-DISPLWIDTH],
                      fft_out_im[FFTOUTSIZE-1:FFTOUTSIZE-DISPLWIDTH] };
                2'b01:
                    fftram_din_reg <=
                    { fft_out_re[FFTOUTSIZE-1:FFTOUTSIZE-DISPLWIDTH],
                      ~fft_out_im[FFTOUTSIZE-1:FFTOUTSIZE-DISPLWIDTH] + 1 };
                2'b10:
                    fftram_din_reg <=
                    { ~fft_out_re[FFTOUTSIZE-1:FFTOUTSIZE-DISPLWIDTH] + 1,
                      fft_out_im[FFTOUTSIZE-1:FFTOUTSIZE-DISPLWIDTH] };
                2'b11:
                    fftram_din_reg <=
                    { ~fft_out_re[FFTOUTSIZE-1:FFTOUTSIZE-DISPLWIDTH] + 1,
                      ~fft_out_im[FFTOUTSIZE-1:FFTOUTSIZE-DISPLWIDTH] + 1 };
            endcase
        end
    // }}}


    //////////////////////////////////
    // FFT DEBUG SIGNALS
    // these can be used by the logic analyzer
    ////////////////////////////////// {{{
        assign dbg_fftidx = fft_index;
        assign dbg_ifftidx = ifft_index;
        assign dbg_fftdone = {ifft_done, fft_dv, fft_done};
        assign dbg_fftout = fft_out_re[FFTOUTSIZE-1:FFTOUTSIZE-8];
    // }}}


    //////////////////////////////////
    // INPUT METHOD 0: RS-232 GAIN CURVE INPUT
    // sw_inpmtd = 2 || 3
    // switch sw_inpmtd off and then on two enter a new gain curve
    ////////////////////////////////// {{{
        wire [LOGFFTSIZE-1:0] gcurve_addr_ser;
        wire [LOGDSPSIZE-1:0] gcdisp_addr_ser;
        wire [GCRVEWIDTH-1:0] gcurve_din_ser;
        wire [DISPLWIDTH-1:0] gcdisp_din_ser;
        wire gcurve_we_ser, gcdisp_we_ser;

        gcserinp #(.LOGFFTSIZE(LOGFFTSIZE), .LOGDSPSIZE(LOGDSPSIZE),
            .AUDIOWIDTH(AUDIOWIDTH), .DISPLWIDTH(DISPLWIDTH),
            .GCRVEWIDTH(GCRVEWIDTH)) inp0
            (   .clk(clk),
                .rst(rst),

                .run(sw_inpmtd[1]),
                .rxd(rs232_rxd),

                .gcurve_addr(gcurve_addr_ser),
                .gcdisp_addr(gcdisp_addr_ser),
                .gcurve_din(gcurve_din_ser),
                .gcdisp_din(gcdisp_din_ser),
                .gcurve_we(gcurve_we_ser),
                .gcdisp_we(gcdisp_we_ser)
            );
    // }}}


    //////////////////////////////////
    // INPUT METHOD 1: GAIN CURVE MODIFIERS
    // sw_inpmtd = 0
    //
    // this doesn't work correctly, so I had to scrap it for the time being
    ////////////////////////////////// {{{
        wire [LOGFFTSIZE-1:0] gcurve_addr_mod;
        wire [LOGDSPSIZE-1:0] gcdisp_addr_mod;
        wire [AUDIOWIDTH-1:0] gcurve_din_mod;
        wire [DISPLWIDTH-1:0] gcdisp_din_mod;
        wire gcurve_we_mod, gcdisp_we_mod;

        gcmodinp #(.LOGFFTSIZE(LOGFFTSIZE), .AUDIOWIDTH(AUDIOWIDTH), .DISPLWIDTH(DISPLWIDTH)) inp1
            (   .clk(clk),
                .rst(rst),
                .btn_rst(btn_rst),
                .btn_add(btn_add),
                //.btn_left(btn_left),
                .btn_up(btn_up),
                //.btn_right(btn_right),
                .btn_down(btn_down),
                .btn_a(btn_a),
                .btn_b(btn_b),
                .btn_c(btn_c),

                .hex(hex),

                .gcurve_addr(gcurve_addr_mod),
                .gcdisp_addr(gcdisp_addr_mod),
                .gcurve_din(gcurve_din_mod),
                .gcdisp_din(gcdisp_din_mod),
                .gcurve_dout(gcurve_dout),
                .gcdisp_dout(gcdisp_dout),      // not used
                .gcurve_we(gcurve_we_mod),
                .gcdisp_we(gcdisp_we_mod)
            );
    // }}}


    //////////////////////////////////
    // INPUT METHOD 2: MOUSE INPUT
    // sw_inpmtd = 1
    //
    // this wasn't implemented yet
    ////////////////////////////////// {{{
        wire [LOGFFTSIZE-1:0] gcurve_addr_mse;
        wire [LOGDSPSIZE-1:0] gcdisp_addr_mse;
        wire [AUDIOWIDTH-1:0] gcurve_din_mse;
        wire [DISPLWIDTH-1:0] gcdisp_din_mse;
        wire gcurve_we_mse, gcdisp_we_mse;

        /*
        gcmseinp #(.LOGFFTSIZE(LOGFFTSIZE), .AUDIOWIDTH(AUDIOWIDTH), .DISPLWIDTH(DISPLWIDTH)) inp2 
            (   .clk(clk),
                .rst(rst),

                // mouse events go here
                
                .gcurve_addr(gcurve_addr_mse),
                .gcdisp_addr(gcdisp_addr_mse),
                .gcurve_din(gcurve_din_mse),
                .gcdisp_din(gcdisp_din_mse),
                .gcurve_dout(gcurve_dout),
                .gcdisp_dout(gcdisp_dout),      // not used
                .gcurve_we(gcurve_we_mse),
                .gcdisp_we(gcdisp_we_mse),
            );
        */
    // }}}


    //////////////////////////////////
    // INPUT METHOD SELECTION
    // suffix ser => input method 0 (serial)
    // suffix mod => input method 1 (gain curve modifiers)
    // suffix mse => input method 2 (mouse)
    ////////////////////////////////// {{{
        assign gcurve_addr_in = (sw_inpmtd == 0) ? gcurve_addr_mod :
                                (sw_inpmtd == 1) ? gcurve_addr_mse : gcurve_addr_ser;
        assign gcdisp_addr_in = (sw_inpmtd == 0) ? gcdisp_addr_mod :
                                (sw_inpmtd == 1) ? gcdisp_addr_mse : gcdisp_addr_ser;

        assign gcurve_din = (sw_inpmtd == 0) ? gcurve_din_mod :
                            (sw_inpmtd == 1) ? gcurve_din_mse : gcurve_din_ser;
        assign gcdisp_din = (sw_inpmtd == 0) ? gcdisp_din_mod :
                            (sw_inpmtd == 1) ? gcdisp_din_mse : gcdisp_din_ser;

        assign gcurve_we = (sw_inpmtd == 0) ? gcurve_we_mod :
                           (sw_inpmtd == 1) ? gcurve_we_mse : gcurve_we_ser;
        assign gcdisp_we = (sw_inpmtd == 0) ? gcdisp_we_mod :
                           (sw_inpmtd == 1) ? gcdisp_we_mse : gcdisp_we_ser;
    // }}}


    //////////////////////////////////
    // VGA CONTROL
    // two modules write to the display: the gain curve display and the FFT
    // display
    ////////////////////////////////// {{{

    wire [2:0] gcpxl, fftpxl;
    assign pixel = gcpxl | fftpxl;

    // no pipelining necessary right now
    assign phsync = hsync;
    assign pvsync = vsync;
    assign pblank = blank;

    gcdisplay #(.LOGFFTSIZE(LOGFFTSIZE), .AUDIOWIDTH(AUDIOWIDTH), .DISPLWIDTH(DISPLWIDTH)) gcdisp1 
        (
            .clk(clk65),
            .rst(rst),

            .hcount(hcount),
            .vcount(vcount),
            .hsync(phsync),
            .vsync(pvsync),
            .blank(pblank),

            .pixel(gcpxl),

            .addr(gcdisp_addr_out),
            .data(gcdisp_doutb)
        );


    fftdisplay #(.LOGFFTSIZE(LOGFFTSIZE), .LOGDSPSIZE(LOGDSPSIZE), .AUDIOWIDTH(AUDIOWIDTH), .DISPLWIDTH(DISPLWIDTH)) fftdisp1
        (
            .clk(clk65),
            .rst(rst),

            .pixel(fftpxl),
            .hcount(hcount),
            .vcount(vcount),
            .hsync(phsync),
            .vsync(pvsync),
            .blank(pblank),

            .addr(fftram_addr_out),
            .data(fftram_doutb)
        );
    // }}}

    //////////////////////////////////
    // OTHER DEBUG SIGNALS
    ////////////////////////////////// {{{
        // send gain curve RAM addresses to the hex display
        assign debug = gcurve_addr_in;
        assign debug2 = gcdisp_addr_in;
    // }}}

endmodule

// vim: fdm=marker

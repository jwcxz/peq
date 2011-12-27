module audio (reset, clock_27mhz, audio_reset_b, ac97_sdata_out, ac97_sdata_in,
	      ac97_synch, ac97_bit_clock, mode, volume, source);

   input reset, clock_27mhz;
   output audio_reset_b;
   output ac97_sdata_out;
   input ac97_sdata_in;
   output ac97_synch;
   input ac97_bit_clock;
   input [1:0] mode;
   input [4:0] volume;
   input source;
   
   wire ready;
   wire [7:0] command_address;
   wire [15:0] command_data;
   wire command_valid;
   reg [19:0] left_out_data, right_out_data;
   wire [19:0] left_in_data, right_in_data, sine_data, square_data;

   //
   // Reset controller
   //
   
   reg audio_reset_b;
   reg [9:0] reset_count;

   always @(posedge clock_27mhz) begin
      if (reset)
	begin
	   audio_reset_b = 1'b0;
	   reset_count = 0;
	end
      else if (reset_count == 1023)
	audio_reset_b = 1'b1;
      else
	reset_count = reset_count+1;
   end
   
   ac97 ac97(ready, command_address, command_data, command_valid,
	     left_out_data, 1'b1, right_out_data, 1'b1, left_in_data, 
	     right_in_data, ac97_sdata_out, ac97_sdata_in, ac97_synch,
	     ac97_bit_clock);
   
   ac97commands cmds(clock_27mhz, ready, command_address, command_data,
		     command_valid, volume, source);

   sinewave sine(clock_27mhz, ready, sine_data);
   
   squarewave square(clock_27mhz, ready, square_data);

   always @(mode or left_in_data or right_in_data or sine_data or square_data)
     case (mode)
       2'd0: begin
	  left_out_data = left_in_data;
	  right_out_data = right_in_data;
       end
       2'd1: begin
	  left_out_data = 20'h00000;
	  right_out_data = 20'h00000;
       end
       2'd2: begin
	  left_out_data = sine_data;
	  right_out_data = sine_data;
       end
       2'd3: begin
	  left_out_data = square_data;
	  right_out_data = square_data;
       end
     endcase
   
endmodule
		 
module beeper (reset, clock_27mhz, beep, enable);

   input reset, clock_27mhz, enable;
   output beep;

   reg [15:0] count;
   reg clock_1khz;
   
   always @(posedge clock_27mhz)
     if (reset)
       begin
	  count <= 0;
	  clock_1khz <= 0;
       end
     else if (count == 13499)
       begin
	  clock_1khz <= ~clock_1khz;
	  count <= 0;
      end
     else
       count <= count+1;
   
   assign beep = enable && clock_1khz;
   
endmodule

module volume (reset, clock, up, down, vol, disp);
   
   input reset, clock, up, down;
   output [3:0] vol;
   output [39:0] disp;

   reg [3:0] vol;
   reg [39:0] disp;
   reg old_up, old_down;

   always @(posedge clock)
     if (reset)
       begin
	  vol <= 0;
	  old_up <= 0;
	  old_down <= 0;
       end
     else
       begin
	  if ((up == 1) && (old_up == 0) && (vol < 15))
	    vol <= vol+1;
	  else if ((down == 1) && (old_down == 0) && (vol > 0))
	    vol <= vol-1;
	  old_up <= up;
	  old_down <= down;
       end
   
   always @(vol)
     case (vol[3:1])
       0: disp <= { 5{8'b00000000}};
       1: disp <= { 5{8'b01000000}};
       2: disp <= { 5{8'b01100000}};
       3: disp <= { 5{8'b01110000}};
       4: disp <= { 5{8'b01111000}};
       5: disp <= { 5{8'b01111100}};
       6: disp <= { 5{8'b01111110}};
       7: disp <= { 5{8'b01111111}};
     endcase
   
endmodule

module ac97 (ready,
	     command_address, command_data, command_valid,
	     left_data, left_valid,
	     right_data, right_valid,
	     left_in_data, right_in_data,
	     ac97_sdata_out, ac97_sdata_in, ac97_synch, ac97_bit_clock);

   output ready;
   input [7:0] command_address;
   input [15:0] command_data;
   input command_valid;
   input [19:0] left_data, right_data;
   input left_valid, right_valid;
   output [19:0] left_in_data, right_in_data;
   
   input ac97_sdata_in;
   input ac97_bit_clock;
   output ac97_sdata_out;
   output ac97_synch;
   
   reg ready;

   reg ac97_sdata_out;
   reg ac97_synch;

   reg [7:0] bit_count;

   reg [19:0] l_cmd_addr;
   reg [19:0] l_cmd_data;
   reg [19:0] l_left_data, l_right_data;
   reg l_cmd_v, l_left_v, l_right_v;
   reg [19:0] left_in_data, right_in_data;
   
   initial begin
      ready <= 1'b0;
      // synthesis attribute init of ready is "0";
      ac97_sdata_out <= 1'b0;
      // synthesis attribute init of ac97_sdata_out is "0";
      ac97_synch <= 1'b0;
      // synthesis attribute init of ac97_synch is "0";
      
      bit_count <= 8'h00;
      // synthesis attribute init of bit_count is "0000";
      l_cmd_v <= 1'b0;
      // synthesis attribute init of l_cmd_v is "0";
      l_left_v <= 1'b0;
      // synthesis attribute init of l_left_v is "0";
      l_right_v <= 1'b0;
      // synthesis attribute init of l_right_v is "0";

      left_in_data <= 20'h00000;
      // synthesis attribute init of left_in_data is "00000";
      right_in_data <= 20'h00000;
      // synthesis attribute init of right_in_data is "00000";
   end
   
   always @(posedge ac97_bit_clock) begin
      // Generate the sync signal
      if (bit_count == 255)
	ac97_synch <= 1'b1;
      if (bit_count == 15)
	ac97_synch <= 1'b0;

      // Generate the ready signal
      if (bit_count == 128)
	ready <= 1'b1;
      if (bit_count == 2)
	ready <= 1'b0;
      
      // Latch user data at the end of each frame. This ensures that the
      // first frame after reset will be empty.
      if (bit_count == 255)
	begin
	   l_cmd_addr <= {command_address, 12'h000};
	   l_cmd_data <= {command_data, 4'h0};
	   l_cmd_v <= command_valid;
	   l_left_data <= left_data;
	   l_left_v <= left_valid;
	   l_right_data <= right_data;
	   l_right_v <= right_valid;
	end
      
      if ((bit_count >= 0) && (bit_count <= 15))
	// Slot 0: Tags
	case (bit_count[3:0])
	  4'h0: ac97_sdata_out <= 1'b1;      // Frame valid
	  4'h1: ac97_sdata_out <= l_cmd_v;   // Command address valid
	  4'h2: ac97_sdata_out <= l_cmd_v;   // Command data valid
	  4'h3: ac97_sdata_out <= l_left_v;  // Left data valid
	  4'h4: ac97_sdata_out <= l_right_v; // Right data valid
	  default: ac97_sdata_out <= 1'b0;
	endcase
	  
      else if ((bit_count >= 16) && (bit_count <= 35))
	// Slot 1: Command address (8-bits, left justified)
	ac97_sdata_out <= l_cmd_v ? l_cmd_addr[35-bit_count] : 1'b0;
      
      else if ((bit_count >= 36) && (bit_count <= 55))
	// Slot 2: Command data (16-bits, left justified)
	ac97_sdata_out <= l_cmd_v ? l_cmd_data[55-bit_count] : 1'b0;
      
      else if ((bit_count >= 56) && (bit_count <= 75))
	begin
	   // Slot 3: Left channel
	   ac97_sdata_out <= l_left_v ? l_left_data[19] : 1'b0;
	   l_left_data <= { l_left_data[18:0], l_left_data[19] };
	end
      else if ((bit_count >= 76) && (bit_count <= 95))
	// Slot 4: Right channel
	   ac97_sdata_out <= l_right_v ? l_right_data[95-bit_count] : 1'b0;
      else 
	ac97_sdata_out <= 1'b0;
      
      bit_count <= bit_count+1;
      
   end // always @ (posedge ac97_bit_clock)

   always @(negedge ac97_bit_clock) begin
      if ((bit_count >= 57) && (bit_count <= 76))
	// Slot 3: Left channel
	left_in_data <= { left_in_data[18:0], ac97_sdata_in };
      else if ((bit_count >= 77) && (bit_count <= 96))
	// Slot 4: Right channel
	right_in_data <= { right_in_data[18:0], ac97_sdata_in };
   end
   
endmodule

///////////////////////////////////////////////////////////////////////////////

module ac97commands (clock, ready, command_address, command_data, 
		     command_valid, volume, source);
   
   input clock;
   input ready;
   output [7:0] command_address;
   output [15:0] command_data;
   output command_valid;
   input [4:0] volume;
   input source;
      
   reg [23:0] command;
   reg command_valid;

   reg old_ready;
   reg done;
   reg [3:0] state;

   initial begin
      command <= 4'h0;
      // synthesis attribute init of command is "0";
      command_valid <= 1'b0;
      // synthesis attribute init of command_valid is "0";
      done <= 1'b0;
      // synthesis attribute init of done is "0";
      old_ready <= 1'b0;
      // synthesis attribute init of old_ready is "0";
      state <= 16'h0000;
      // synthesis attribute init of state is "0000";
   end
      
   assign command_address = command[23:16];
   assign command_data = command[15:0];

   wire [4:0] vol;
   assign vol = 31-volume;
   	      
   always @(posedge clock) begin
      if (ready && (!old_ready))
	state <= state+1;
      
      case (state)
	4'h0: // Read ID
	  begin
	     command <= 24'h80_0000;
	     command_valid <= 1'b1;
	  end
      	4'h1: // Read ID
	  command <= 24'h80_0000;
	4'h2: // Master volume
	  command <= { 8'h02, 3'b000, vol, 3'b000, vol };
	4'h3: // Aux volume
	  command <= { 8'h04, 3'b000, vol, 3'b000, vol };
	4'h4: // Mono volume
	  command <= 24'h06_8000;
	4'h5: // PCM volume
	  command <= 24'h18_0808;
	4'h6: // Record source select
	  if (source)
	    command <= 24'h1A_0000; // microphone
	  else
	    command <= 24'h1A_0404; // line-in
	4'h7: // Record gain
	  command <= 24'h1C_0000;
	4'h8: // Line in gain
	  command <= 24'h10_8000;
	//4'h9: // Set jack sense pins
	  //command <= 24'h72_3F00;
	4'hA: // Set beep volume
	  command <= 24'h0A_0000;
	//4'hF: // Misc control bits
	  //command <= 24'h76_8000;
	default:
	  command <= 24'h80_0000;
      endcase // case(state)

      old_ready <= ready;
      
   end // always @ (posedge clock)

endmodule // ac97commands


module sinewave (clock, ready, pcm_data);

   input clock;
   input ready;
   output [19:0] pcm_data;
   
   reg rdy, old_ready;
   reg [8:0] index;
   reg [19:0] pcm_data;

   initial begin
      old_ready <= 1'b0;
      // synthesis attribute init of old_ready is "0";
      index <= 8'h00;
      // synthesis attribute init of index is "00";
      pcm_data <= 20'h00000;
      // synthesis attribute init of pcm_data is "00000";
   end
   
   always @(posedge clock) begin
      if (rdy && ~old_ready)
	index <= index+1;
      old_ready <= rdy;
      rdy <= ready;
   end
   
   always @(index) begin
      case (index[5:0])
        6'h00: pcm_data <= 20'h00000;
        6'h01: pcm_data <= 20'h0C8BD;
        6'h02: pcm_data <= 20'h18F8B;
        6'h03: pcm_data <= 20'h25280;
        6'h04: pcm_data <= 20'h30FBC;
        6'h05: pcm_data <= 20'h3C56B;
        6'h06: pcm_data <= 20'h471CE;
        6'h07: pcm_data <= 20'h5133C;
        6'h08: pcm_data <= 20'h5A827;
        6'h09: pcm_data <= 20'h62F20;
        6'h0A: pcm_data <= 20'h6A6D9;
        6'h0B: pcm_data <= 20'h70E2C;
        6'h0C: pcm_data <= 20'h7641A;
        6'h0D: pcm_data <= 20'h7A7D0;
        6'h0E: pcm_data <= 20'h7D8A5;
        6'h0F: pcm_data <= 20'h7F623;
        6'h10: pcm_data <= 20'h7FFFF;
        6'h11: pcm_data <= 20'h7F623;
        6'h12: pcm_data <= 20'h7D8A5;
        6'h13: pcm_data <= 20'h7A7D0;
        6'h14: pcm_data <= 20'h7641A;
        6'h15: pcm_data <= 20'h70E2C;
        6'h16: pcm_data <= 20'h6A6D9;
        6'h17: pcm_data <= 20'h62F20;
        6'h18: pcm_data <= 20'h5A827;
        6'h19: pcm_data <= 20'h5133C;
        6'h1A: pcm_data <= 20'h471CE;
        6'h1B: pcm_data <= 20'h3C56B;
        6'h1C: pcm_data <= 20'h30FBC;
        6'h1D: pcm_data <= 20'h25280;
        6'h1E: pcm_data <= 20'h18F8B;
        6'h1F: pcm_data <= 20'h0C8BD;
        6'h20: pcm_data <= 20'h00000;
        6'h21: pcm_data <= 20'hF3743;
        6'h22: pcm_data <= 20'hE7075;
        6'h23: pcm_data <= 20'hDAD80;
        6'h24: pcm_data <= 20'hCF044;
        6'h25: pcm_data <= 20'hC3A95;
        6'h26: pcm_data <= 20'hB8E32;
        6'h27: pcm_data <= 20'hAECC4;
        6'h28: pcm_data <= 20'hA57D9;
        6'h29: pcm_data <= 20'h9D0E0;
        6'h2A: pcm_data <= 20'h95927;
        6'h2B: pcm_data <= 20'h8F1D4;
        6'h2C: pcm_data <= 20'h89BE6;
        6'h2D: pcm_data <= 20'h85830;
        6'h2E: pcm_data <= 20'h8275B;
        6'h2F: pcm_data <= 20'h809DD;
        6'h30: pcm_data <= 20'h80000;
        6'h31: pcm_data <= 20'h809DD;
        6'h32: pcm_data <= 20'h8275B;
        6'h33: pcm_data <= 20'h85830;
        6'h34: pcm_data <= 20'h89BE6;
        6'h35: pcm_data <= 20'h8F1D4;
        6'h36: pcm_data <= 20'h95927;
        6'h37: pcm_data <= 20'h9D0E0;
        6'h38: pcm_data <= 20'hA57D9;
        6'h39: pcm_data <= 20'hAECC4;
        6'h3A: pcm_data <= 20'hB8E32;
        6'h3B: pcm_data <= 20'hC3A95;
        6'h3C: pcm_data <= 20'hCF044;
        6'h3D: pcm_data <= 20'hDAD80;
        6'h3E: pcm_data <= 20'hE7075;
        6'h3F: pcm_data <= 20'hF3743;
      endcase // case(index[8:2])
   end // always @ (index)
   
endmodule


	  
module squarewave (clock, ready, pcm_data);

   input clock;
   input ready;
   output [19:0] pcm_data;

   reg old_ready;
   reg [6:0] index;
   reg [19:0] pcm_data;

   initial begin
      old_ready <= 1'b0;
      // synthesis attribute init of old_ready is "0";
      index <= 7'h00;
      // synthesis attribute init of index is "00";
      pcm_data <= 20'h00000;
      // synthesis attribute init of pcm_data is "00000";
   end
   
   always @(posedge clock) begin
      if (ready && ~old_ready)
	index <= index+1;
      old_ready <= ready;
   end

   always @(index) begin
      if (index[6])
	pcm_data <= 20'hF0F00;
      else
	pcm_data <= 20'h05555;
   end // always @ (index)
   
endmodule

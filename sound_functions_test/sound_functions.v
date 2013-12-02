/**
 * sound_functions.v
 * 18-545
 * eob
 * 
 * Creates modules for dealing with the various sound functions
 * e.g. frequency sweep, volume envelope, waveforms and white noise
 * 
 */


/**
 * WaveformPlayer
 * 
 * Plays 32 4-bit samples stored in "memory"
 * Calculates length of sound from 256Hz timer "length_cntrl_clk"
 * Calculates the frequency of samples using "ch3_freq_cntrl_clk"
 * 
 */
module WaveformPlayer (input clk,
		       input ch3_enable,
		       input [7:0] ch3_length_data,
		       input [1:0] ch3_output_level,
		       input ch3_reset, //initializer
		       input ch3_dont_loop,
		       input [10:0] ch3_frequency_data,
		       input [127:0] ch3_samples,
		       input length_cntrl_clk,
		       input ch3_freq_cntrl_clk,
		       output reg [3:0] level
		       );
   reg [7:0] 	       index_hi = 8'd7; //MSB of current sample pair
   reg                 upper_half; //whether to play MSBs of sample pair
   wire [8:0] 	       true_len; //# of length_cntrl_clk edges before reset
   reg [8:0] 	       len_counter = 0;
   wire [11:0] 	       true_freq; //# of freq clks before next sample
   reg [11:0] 	       freq_counter = 0;
   reg [3:0] 	       reg_level; //synchronous level

   // The following numbers are specific to the Gameboy CH 3
   assign true_len = 9'd256 - ch3_length_data;
   assign true_freq = 12'd2048 - ch3_frequency_data;

   always@(posedge length_cntrl_clk) begin //play for specified length
      if (~ch3_reset) begin
	 len_counter <= 0;
      end
      //even if ch3_enable not asserted, still count up
      else if (len_counter <= true_len+1) begin //just past true_len
	 len_counter <= len_counter + 1;
      end
   end

   always@(posedge ch3_freq_cntrl_clk) begin
      if (~ch3_reset || ~ch3_enable) begin
	 reg_level <= 0;
	 index_hi <= 8'd7;
	 upper_half <= 1;
	 freq_counter <= 0;
      end
      else begin
	 // Change samples at specified frequency
	 if (freq_counter == true_freq) begin
	    if (~upper_half) begin
	       index_hi <= index_hi + 8'd8; //play next sample pair
	    end
	    upper_half <= ~upper_half;
	    freq_counter <= 12'b1; //true_freq always >= 1
	 end
	 else begin
	    freq_counter <= freq_counter + 12'b1;
	 end
	 // Play only for specified length
	 if ((ch3_dont_loop && (len_counter <= true_len)) ||
	     ~ch3_dont_loop) begin
	       if (index_hi <= 8'd127) begin
		  if (upper_half) begin
		     reg_level <= ch3_samples[index_hi -: 3]; //4 bits at a time
		  end
		  else begin
		     reg_level <= ch3_samples[index_hi-4 -: 3];
		  end
	       end
	    else begin
	       index_hi <= 8'd7; //back to first sample
	    end
	 end
	 else if (len_counter > true_len) begin //stop output
	    reg_level <= 0;
	 end
      end // else: !if(ch3_reset)
   end // always@ (posedge clk)

   always@(*) begin
      //adjust volume
      if (ch3_output_level != 2'b0) begin
	 level = (reg_level >> (ch3_output_level - 1));
      end
      else begin
	 level = 0;
      end
   end
endmodule // WaveformPlayer


/**
 * Square Wave Generator
 * 
 * Generates a square wave at a given frequency for channel 1 and channel 2
 * 
 */
module SquareWave(
//                  input        ac97_bitclk,
//                  input        ac97_strobe,
		  input        length_cntrl_clk,
		  input        sweep_cntrl_clk,
		  input        env_cntrl_clk,
		  input        freq_cntrl_clk,
                  input [2:0]  sweep_time,
                  input        sweep_decreasing,
                  input [2:0]  num_sweep_shifts,
                  input [1:0]  wave_duty,
                  input [5:0]  length_data,
                  input [3:0]  initial_volume,
                  input        envelope_increasing,
                  input [2:0]  num_envelope_sweeps,
                  input        initialize,
                  input        dont_loop,
                  input [10:0] frequency_data,
		  output wire [3:0] level
                  );
   
   /*                  input [19:0]       freq,
    input [3:0]        level,
    output wire [19:0] sample*/

//   parameter strobe_rate = 20'd47940;
   wire [8:0] 	       true_len; //# of length_cntrl_clk edges before reset
   reg [8:0] 	       len_counter = 0;
   reg [11:0] 	       true_freq; //rate at which square wave completes cycles
   reg [11:0] 	       freq_counter = 0;
   reg [3:0] 	       reg_level; //controlled by freq controller
   reg [4:0] 	       env_counter = 1;
   reg [3:0] 	       reg_vol; // controlled by volume envelope	       
   reg [3:0] 	       sweep_counter, num_sweeps_done;
   
   assign true_len = 7'd64 - length_data;
   assign level = ~initialize? 4'b0 : reg_level;
      
   always@(posedge length_cntrl_clk) begin //play for specified length
      if (~initialize) begin
	 len_counter <= 0;
      end
      else if (len_counter <= true_len+1) begin //just past true_len
	 len_counter <= len_counter + 1;
      end
   end

   always@(posedge freq_cntrl_clk) begin
      if (~initialize) begin
	 reg_level <= initial_volume;
	 freq_counter <= 0;
      end
      // Play only for specified length
      else if ((dont_loop && (len_counter <= true_len)) || ~dont_loop &&
	       true_freq != 0) begin
	 case (wave_duty)
	   /** NOTE: The PAN Docs are confusing on this point. They seem to
	    *  imply that the % duty cycle is the amount of time the wave
	    *  is LOW. This doesn't make logical sense but I've implemented
	    *  it this way anyway. It may need to change later.
	    */
	   2'd0: begin
	      if (freq_counter == (true_freq>>3)) begin //12.5% duty cycle
		 reg_level <= reg_vol;
		 freq_counter <= freq_counter + 12'd1;
	      end
	      else if (freq_counter >= true_freq) begin
		 reg_level <= 4'h0;
		 freq_counter <= 0;
	      end
	      else begin
		 freq_counter <= freq_counter + 12'b1;
	      end
	   end // case: 2'b0
	   2'd1: begin
	      if (freq_counter == (true_freq>>2)) begin //25% duty cycle
		 reg_level <= reg_vol;
		 freq_counter <= freq_counter + 12'd1;
	      end
	      else if (freq_counter >= true_freq) begin
		 reg_level <= 4'h0;
		 freq_counter <= 0;
	      end
	      else begin
		 freq_counter <= freq_counter + 12'b1;
	      end
	   end // case: 2'b1
	   2'd2: begin
	      if (freq_counter == (true_freq>>1)) begin //50% duty cycle
		 reg_level <= reg_vol;
		 freq_counter <= freq_counter + 12'd1;
	      end
	      else if (freq_counter >= true_freq) begin
		 reg_level <= 4'h0;
		 freq_counter <= 0;
	      end
	      else begin
		 freq_counter <= freq_counter + 12'b1;
	      end
	   end // case: 2'b2
	   2'd3: begin
	      if (freq_counter == (true_freq>>2)) begin //75% duty cycle
		 reg_level <= 4'h0;
		 freq_counter <= freq_counter + 12'd1;
	      end
	      else if (freq_counter >= true_freq) begin
		 reg_level <= reg_vol;
		 freq_counter <= 0;
	      end
	      else begin
		 freq_counter <= freq_counter + 12'b1;
	      end
	   end // case: 2'b3
	 endcase
      end
      else begin //stop output
	 reg_level <= 4'h0;
      end
   end // always@ (posedge freq_cntrl_clk)

   always@ (posedge sweep_cntrl_clk) begin
      if (~initialize) begin
	 true_freq <= 12'd2048 - frequency_data;//Gameboy specific
	 sweep_counter <= 4'b1;
	 num_sweeps_done <= 4'b0;
      end
      else begin
	 if (sweep_time==0) begin
	    true_freq <= 12'd2048 - frequency_data;
	 end
	 else begin
	    if (sweep_counter==sweep_time &&
		num_sweeps_done<num_sweep_shifts) begin
	       /** NOTE: This is backwards from what I would expect. The sound
		*  increases in frequency when I subtract from true_freq
		*  and decreases when I add. This is strange, but it seems
		*  to work otherwise.
		*/
	       if (~sweep_decreasing) begin
		  true_freq <= true_freq - (true_freq>>num_sweep_shifts);
	       end
	       else begin
		  if ((true_freq+(true_freq>>num_sweep_shifts))<12'd2048) begin
		    true_freq <= true_freq + (true_freq>>num_sweep_shifts);
		  end
		  else begin
		     true_freq <= 12'd0;
		  end
	       end // else: !if(~sweep_decreasing)
	       sweep_counter <= 4'b1;
	       num_sweeps_done <= num_sweeps_done + 4'b1;
	    end
	    else if (num_sweeps_done >= num_sweep_shifts) begin
	       true_freq <= 12'd0;
	    end
	    else begin
	       sweep_counter <= sweep_counter + 4'b1;
	    end
	 end // else: !if(sweep_time==0)
      end // else: !if(initialize)
   end // always@ (posedge sweep_cntrl_clk)
   
   always @(posedge env_cntrl_clk) begin
      if (~initialize) begin
	 reg_vol <= initial_volume;
	 env_counter <= 1;
      end
      else begin
	 /** NOTE: num_envelope_sweeps is the name given to this signal in
	  *  the PAN Docs, but it is not the number of envelope sweeps.
	  *  Instead it is the number of clocks before we perform another
	  *  sweep. Basically the frequency. Except if it's zero we stop
	  *  the envelope operation, so we only check if it's 1 or greater.
	  */
	 if (env_counter == num_envelope_sweeps) begin
	    if (envelope_increasing && reg_vol < 4'hF) begin
	       reg_vol <= reg_vol + 4'b1;
	    end
	    else if (~envelope_increasing && reg_vol > 4'd0) begin
	       reg_vol <= reg_vol - 4'b1;
	    end
	    env_counter <= 1;
	 end // if (env_counter == num_envelope_sweeps)
	 else begin
	    env_counter <= env_counter + 5'b1;
	 end
      end // else: !if(initialize)
   end // always @ (posedge env_cntrl_clk)
	 
/*   reg [19:0] 			   strobe_counter = 20'b0;
   
   always @(posedge ac97_strobe) begin
      //essentially divide ac97_strobe by freq
      strobe_counter = strobe_counter + freq;
      if (strobe_counter >= strobe_rate) begin
	 strobe_counter = 20'b0;
      end
//      end
//      else begin
//	 bitclk_counter = bitclk_counter + 1;
//      end
   end

   // amplitude is set as signed 20 bit value.
   // beware of clipping when adding signals together.
   assign sample = ((strobe_counter >= strobe_rate/2) ? 
                    20'b0 : {2'd0, level[3:0], 14'h0});// {1'b1, ~level[3:0], 15'h0}*/
endmodule // SquareWave


/**
 * White Noise Generator
 * 
 * Generates white noise using a random number generator
 * 
 */
/*module WhiteNoise(
//                  input        ac97_bitclk,
//                  input        ac97_strobe,
		  input [5:0]   ch4_length_data,
		  input [3:0]   ch4_initial_volume,
		  input         ch4_envelope_increasing,
		  input [2:0]   ch4_num_envelope_sweeps,
		  input [3:0]   ch4_shift_clock_freq_data,
		  input         ch4_counter_width,
		  input [2:0]   ch4_freq_dividing_ratio,
		  input         ch4_reset,
		  input         ch4_dont_loop,
		  input         length_cntrl_clk,
		  input         env_cntrl_clk,
		  input         freq_cntrl_clk,
		  output wire [3:0] level
                  );
   wire [8:0] 	       true_len; //# of length_cntrl_clk edges before reset
   reg [8:0] 	       len_counter = 0;
   reg [11:0] 	       true_freq; //rate at which square wave completes cycles
   reg [11:0] 	       freq_counter = 0;
   reg [3:0] 	       reg_level; //controlled by freq controller
   reg [4:0] 	       env_counter = 1;
   reg [3:0] 	       reg_vol; // controlled by volume envelope	       
   reg [3:0] 	       sweep_counter, num_sweeps_done, num_env_done;
   
   assign true_len = 7'd64 - ch4_length_data;
   assign level = ch4_reset ? 4'b0 : reg_level;
      
   always@(posedge length_cntrl_clk) begin //play for specified length
      if (ch4_reset) begin
	 len_counter <= 0;
      end
      else if (len_counter <= true_len+1) begin //just past true_len
	 len_counter <= len_counter + 1;
      end
   end

   always@ (posedge freq_cntrl_clk) begin
      if (ch4_reset) begin
	 reg_level <= ch4_initial_volume;
	 freq_counter <= 0;
      end
      // Play only for specified length
      else if ((ch4_dont_loop && (len_counter <= true_len)) || ~ch4_dont_loop &&
	       true_freq != 0) begin
	 
      end
      else begin //stop output
	 reg_level <= 4'h0;
      end
   end // always@ (posedge freq_cntrl_clk)
*/
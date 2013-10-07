module tb;
   reg sw_enable;
   reg sample_no;
   reg bitclk;
   reg sdata_in;

   wire sdata_out;
   wire sync;
   wire reset;
   wire [23:0] flash_a;
   wire flash_adv_n;
   wire flash_ce_n;
   wire flash_clk;
   wire flash_oe_n;
   wire flash_we_n;
   wire [19:0] square_sample;
   wire        strobe;
   

   AC97 ac(/*AUTOINST*/
           // Outputs
           .ac97_sdata_out              (sdata_out),
           .ac97_sync                   (sync),
           .ac97_reset_b                (reset),
           .flash_a                     (flash_a[23:0]),
           .flash_adv_n                 (flash_adv_n),
           .flash_ce_n                  (flash_ce_n),
           .flash_clk                   (flash_clk),
           .flash_oe_n                  (flash_oe_n),
           .flash_we_n                  (flash_we_n),
           .square_sample  (square_sample),
           .strobe (strobe),
           // Inputs
           .square_wave_enable          (sw_enable),
           .sample_no                   (sample_no),
           .ac97_bitclk                 (bitclk),
           .ac97_sdata_in               (1'h0),
           .flash_wait                  (1'h0),
           .flash_d                     (16'h0));

   initial begin
      bitclk=0;
      sample_no=0;
      sw_enable=1;
   end
   always #5 bitclk = ~bitclk;
   
   endmodule
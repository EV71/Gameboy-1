module cartridge (output wire HDR1_2, HDR1_6, HDR1_8, HDR1_10,
                  output wire      HDR1_12, HDR1_14, HDR1_16, HDR1_18,
                  output wire      HDR1_20, HDR1_22, HDR1_24, HDR1_26,
                  output wire      HDR1_28, HDR1_30, HDR1_32, HDR1_34,
                  output wire      HDR1_36, HDR1_38, HDR1_40, HDR1_42,
                  input            HDR1_44, HDR1_46, HDR1_48, HDR1_50,
                  input            HDR1_52, HDR1_54, HDR1_56, HDR1_58,
                  output wire      HDR1_60, HDR1_64,
                  output reg [7:0] leds,
                  input [7:0]      switches,
                  input            clock);

   wire                      vdd, w_enable_l, r_enable_l, cs_sram_l;
   wire [15:0]               address;
   wire [7:0]                data;
   wire                      reset_l, gnd;

   assign HDR1_2 = vdd;
   assign HDR1_6 = w_enable_l;
   assign HDR1_8 = r_enable_l;
   assign HDR1_10 = cs_sram_l;
   assign HDR1_12 = address[0];
   assign HDR1_14 = address[1];
   assign HDR1_16 = address[2];
   assign HDR1_18 = address[3];
   assign HDR1_20 = address[4];
   assign HDR1_22 = address[5];
   assign HDR1_24 = address[6];
   assign HDR1_26 = address[7];
   assign HDR1_28 = address[8];
   assign HDR1_30 = address[9];
   assign HDR1_32 = address[10];
   assign HDR1_34 = address[11];
   assign HDR1_36 = address[12];
   assign HDR1_38 = address[13];
   assign HDR1_40 = address[14];
   assign HDR1_42 = address[15];
   assign data[0] = HDR1_44;
   assign data[1] = HDR1_46;
   assign data[2] = HDR1_48;
   assign data[3] = HDR1_50;
   assign data[4] = HDR1_52;
   assign data[5] = HDR1_54;
   assign data[6] = HDR1_56;
   assign data[7] = HDR1_58;
   assign HDR1_60 = reset_l;
   assign HDR1_64 = gnd;


   assign vdd = 1;
   assign gnd = 0;
   assign reset_l = 1;
   assign cs_sram_l = 1;
   assign r_enable_l = 0;
   assign w_enable_l = 1;
   assign address[7:0] = switches[7:0];
   assign address[15:8] = 8'd0;

   reg [40:0]            counter = 0;
   
   always@ (posedge clock) begin
      //counter <= counter + 1;
      //if (counter > 41'd30000000) begin
      leds[7:0] <= data[7:0];
         //counter <= 41'd0;
         //address <= address + 1;
      //end
   end
endmodule
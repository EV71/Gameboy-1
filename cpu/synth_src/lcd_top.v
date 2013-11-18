// The Flash memory stores bytes from the hex -> mcs file as follows:
// Little Endian
// Intellllll!!!!
// Notice that the Flash clock should be 1 for asynchronous read mode, which is
// the default mode.

// The CPU's clock is 4194304 Hz, or 2^22 Hz.

`default_nettype none

module lcd_top(CLK_33MHZ_FPGA,
	       GPIO_SW_C,
	       GPIO_SW_E,
	       GPIO_SW_S,
	       GPIO_SW_W,
               GPIO_SW_N,
               GPIO_LED_S, GPIO_LED_N, GPIO_LED_E, GPIO_LED_W, GPIO_LED_C,
               GPIO_LED_7, GPIO_LED_6, GPIO_LED_5, GPIO_LED_4, GPIO_LED_3,
               GPIO_LED_2, GPIO_LED_1, GPIO_LED_0,
               GPIO_DIP_SW8, GPIO_DIP_SW7, GPIO_DIP_SW6, GPIO_DIP_SW5,
               GPIO_DIP_SW4, GPIO_DIP_SW3, GPIO_DIP_SW2, GPIO_DIP_SW1,
	       LCD_FPGA_RS, LCD_FPGA_RW, LCD_FPGA_E,
	       LCD_FPGA_DB7, LCD_FPGA_DB6, LCD_FPGA_DB5, LCD_FPGA_DB4,
               flash_wait, flash_d, flash_a, flash_adv_n, flash_ce_n, 
               flash_oe_n, flash_we_n, flash_clk,
	       strobe, ac97_sync, ac97_reset_b,
	       ac97_bitclk, ac97_sdata_in, ac97_sdata_out,
	       rotary_inc_a, rotary_inc_b
);

   parameter
     I_HILO = 4, I_SERIAL = 3, I_TIMA = 2, I_LCDC = 1, I_VBLANK = 0;
   
   input CLK_33MHZ_FPGA;
//   input USER_CLK;
   /* switch C is reset, E is clear, S is resetFSM, W is nextString */
   input GPIO_SW_C, GPIO_SW_E, GPIO_SW_S, GPIO_SW_W, GPIO_SW_N;
   output GPIO_LED_C, GPIO_LED_E, GPIO_LED_S, GPIO_LED_W, GPIO_LED_N;
   output LCD_FPGA_RW, LCD_FPGA_RS, LCD_FPGA_E, LCD_FPGA_DB7, LCD_FPGA_DB6,
          LCD_FPGA_DB5, LCD_FPGA_DB4;

   input wire [15:0] flash_d;
   input wire flash_wait;
   output wire [23:0] flash_a;
   output wire        flash_adv_n;
   output wire        flash_ce_n, flash_oe_n, flash_we_n, flash_clk;
   
   output wire 	      strobe, ac97_sync, ac97_reset_b, ac97_sdata_out;
   input wire 	      ac97_bitclk, ac97_sdata_in;
   input wire 	      rotary_inc_a, rotary_inc_b;
   
   wire   clock;

   assign clock = CLK_33MHZ_FPGA;
   assign flash_clk = 1'h1;
   
   wire [2:0] control_out; //rs, rw, en
   wire [3:0] out;
   wire       reset;
   
   wire       writeStart;
   wire       writeDone;
   wire       initDone;
   wire [7:0] data;
//   reg        clearAll;
   wire       nextString;
   
   assign reset = GPIO_SW_C;
   assign GPIO_LED_C = reset;
   //assign resetFSM = GPIO_SW_S;
   //assign clearAll = GPIO_SW_E;
   //assign nextString = GPIO_SW_W;
   
   assign LCD_FPGA_DB7 = out[3];
   assign LCD_FPGA_DB6 = out[2];
   assign LCD_FPGA_DB5 = out[1];
   assign LCD_FPGA_DB4 = out[0];	
   
   assign LCD_FPGA_RS = control_out[2];
   assign LCD_FPGA_RW = control_out[1];
   assign LCD_FPGA_E  = control_out[0];


   assign flash_ce_n = 1'h0;
   assign flash_oe_n = 1'h0;
   assign flash_we_n = 1'h1;

   output wire GPIO_LED_7, GPIO_LED_6, GPIO_LED_5, GPIO_LED_4, GPIO_LED_3;
   output wire GPIO_LED_2, GPIO_LED_1, GPIO_LED_0;

   input wire GPIO_DIP_SW8, GPIO_DIP_SW7, GPIO_DIP_SW6, GPIO_DIP_SW5;
   input wire GPIO_DIP_SW4, GPIO_DIP_SW3, GPIO_DIP_SW2, GPIO_DIP_SW1;

   /*wire       bram_we;
   wire [15:0] bram_addr;
   wire [7:0]  bram_data_in;
   wire [7:0]  bram_data_out;*/

/*   blockram br(.clka(clock),
               .wea(bram_we),
               .addra(bram_addr),
               .dina(bram_data_in),
               .douta(bram_data_out));*/

   
   wire [7:0]  bp_addr_disp, bp_addr_part_in;
   wire        bp_hi_lo_sel_in, bp_hi_lo_disp_in;
   wire [15:0] bp_addr;
   wire        bp_step, bp_continue;

   // Breakpoint module controls
//   assign bp_hi_lo_sel_in = GPIO_SW_E;
//   assign bp_hi_lo_disp_in = GPIO_SW_W;
   assign {GPIO_LED_0, GPIO_LED_1, GPIO_LED_2, GPIO_LED_3, GPIO_LED_4,
           GPIO_LED_5, GPIO_LED_6, GPIO_LED_7} = bp_addr_disp;
   assign bp_addr_part_in = {GPIO_DIP_SW1, GPIO_DIP_SW2, GPIO_DIP_SW3,
                             GPIO_DIP_SW4, GPIO_DIP_SW5, GPIO_DIP_SW6,
                             GPIO_DIP_SW7, GPIO_DIP_SW8};
   
   
   
`define cdisp0 3'd0
`define cdisp1 3'd1
`define cdisp2 3'd2
`define cdisp3 3'd3
`define cwait 3'd4

//   reg [15:0] curr_data, next_data;
   wire [7:0] A_data, instruction;
   wire [79:0] regs_data;
//   wire [95:0] print_data;
//   wire [39:0] print_data;
   wire [63:0] print_data;
   assign print_data = {A_data, instruction, regs_data[79:48], regs_data[15:0]};
//   wire [95:0] print_data;
//   assign print_data = {A_data, instruction, regs_data};

   
//   reg [3:0]   display_hex_data_in;
//   reg        display_hex_start;
   
   wire        clearAll;
   wire [3:0]  display_hex_data_in;
   wire        display_hex_start;

   
   wire       display_hex_done;
   
   reg [2:0]  cstate, next_cstate;
//   reg [15:0] count, next_count;
   wire       button_down;

   wire       halt;
   wire       cpu_clock;

   wire       display_signal_done;
   reg        display_signal_start;
   display_signal #(16)
   sig_disp(// Outputs
            .display_hex_data_in(display_hex_data_in),
            .display_hex_start(display_hex_start),
            .display_signal_done(display_signal_done),
            .clearAll(clearAll),
            // Inputs
            .display_signal_data(print_data),
            .display_hex_done(display_hex_done),
            .display_signal_start(display_signal_start),
            .clock(clock),
            .reset(reset)
            );

   always @(*) begin
      display_signal_start = 1'b0;
      next_cstate = `cdisp0;
      case (cstate)
        `cdisp0: begin
           if (~display_signal_done) begin
              display_signal_start = 1'b1;
              next_cstate = `cdisp0;
           end else if (~halt) begin
              next_cstate = `cdisp1;
           end else begin
              next_cstate = `cwait;
           end
        end
        `cdisp1: begin
           if (halt || button_down) begin
//           if (cpu_clock || button_down) begin //button_down) begin
              next_cstate = `cdisp0;
           end else begin
              next_cstate = `cdisp1;
           end
        end
        `cwait: begin
           if (button_down) begin
              next_cstate = `cdisp0;
           end else begin
              next_cstate = `cwait;
           end
//           next_cstate = `cdisp0;
        end
      endcase
   end

   always @(posedge clock or posedge reset) begin
      if (reset) begin
         cstate <= `cdisp0;
      end else begin
         cstate <= next_cstate;
      end
   end
   
/*   button #(.delay_cycles(6000000))
   inc_button(.pressed(button_down),
              .button_input(GPIO_SW_S),
              .clock(clock),
              .reset(reset));*/

   assign button_down = bp_hi_lo_disp_in;

   button #(.delay_cycles(6000000)) 
   addr_disp_button(.pressed(bp_hi_lo_disp_in),
                    .pressed_disp(GPIO_LED_E),
                    .button_input(GPIO_SW_E),
                    .clock(clock),
                    .reset(reset));

   button #(.delay_cycles(6000000)) 
   addr_sel_button(.pressed(bp_hi_lo_sel_in),
                   .pressed_disp(GPIO_LED_W),
                   .button_input(GPIO_SW_W),
                   .clock(clock),
                   .reset(reset));
   
   button #(.delay_cycles(6000000)) 
   step_button(.pressed(bp_step),
               .pressed_disp(GPIO_LED_N),
               .button_input(GPIO_SW_N),
               .clock(clock),
               .reset(reset));

   button #(.delay_cycles(6000000)) 
   continue_button(.pressed(bp_continue),
                   .pressed_disp(GPIO_LED_S),
                   .button_input(GPIO_SW_S),
                   .clock(clock),
                   .reset(reset));
   
   lcd_control lcd(.rst(reset), .clk(clock), .control(control_out), .sf_d(out),
		   .writeStart(writeStart), .initDone(initDone),
                   .writeDone(writeDone), 
		   .dataIn(data), 
		   .clearAll(clearAll));
   
   display_hex hex_decoder(// Outputs
                           .lcd_dataIn          (data[7:0]),
                           .lcd_writeStart      (writeStart),
                           .display_hex_done    (display_hex_done),
                           // Inputs
                           .display_hex_data_in (display_hex_data_in),
                           .display_hex_start   (display_hex_start),
                           .clock               (clock),
                           .reset               (reset),
                           .lcd_initDone        (initDone),
                           .lcd_writeDone       (writeDone));

   wire mem_we, mem_re;
   wire [15:0] addr_ext;
   wire [7:0]  data_ext;

`define MAX_VCOUNT 9'd440
   
   reg [7:0]   FF44_data;
   reg [8:0]   v_count;

   always @(posedge cpu_clock or posedge reset) begin
      if (reset) begin
         v_count <= 9'd0;
         FF44_data <= 8'd0;
      end else begin
         if (v_count >= `MAX_VCOUNT) begin//9'd440) begin
            v_count <= 9'd0;
            if (FF44_data >= 8'd153) begin
               FF44_data <= 8'd0;
            end else  begin
               FF44_data <= FF44_data + 8'd1;
            end
         end
         v_count <= v_count + 9'd1;
      end
   end

   // Timers, DMA //////////////////////////////////////////////////////////////

   wire       timer_reg_addr; // addr_ext == timer MMIO address

   wire       dma_mem_re, dma_mem_we, cpu_mem_disable;
   
   dma gb80_dma(.dma_mem_re(dma_mem_re),
                .dma_mem_we(dma_mem_we),
                .addr_ext(addr_ext),
                .data_ext(data_ext),
                .mem_we(mem_we),
                .mem_re(mem_re),
                .cpu_mem_disable(cpu_mem_disable),
                .clock(clock),
                .reset(reset));

`define MMIO_DIV 16'hff04
`define MMIO_TIMA 16'hff05
`define MMIO_TMA 16'hff06
`define MMIO_TAC 16'hff07
   
   assign timer_reg_addr = (addr_ext == `MMIO_DIV) |
                           (addr_ext == `MMIO_TMA) |
                           (addr_ext == `MMIO_TIMA) |
                           (addr_ext == `MMIO_TAC);

   wire       timer_interrupt;

   wire [4:0]  IE_data, IF_in, IF_data, IE_in;
   wire        IE_load, IF_load;
   
   assign IF_in[I_TIMA] = timer_interrupt;
   assign IF_in[I_VBLANK] = 1'b0;
   assign IF_in[I_LCDC] = 1'b0;
   assign IF_in[I_HILO] = 1'b0;
   assign IF_in[I_SERIAL] = 1'b0;

   assign IF_load = timer_interrupt;
   
   timers tima_module(/*AUTOINST*/
                      // Outputs
                      .timer_interrupt  (timer_interrupt),
                      // Inouts
                      .addr_ext         (addr_ext[15:0]),
                      .data_ext         (data_ext[7:0]),
                      // Inputs
                      .mem_re           (mem_re),
                      .mem_we           (mem_we),
                      .clock            (clock),
                      .reset            (reset));
   
   wire        FF44_read;
   assign FF44_read = (addr_ext == 16'hff44) & mem_re;
   
   wire        addr_in_flash;

   assign addr_in_flash = addr_ext <= 16'h140;
   


   assign flash_a = {8'd0, addr_ext};
   assign flash_adv_n = ~mem_re;
   
   assign IE_in = 5'b0;
   assign IE_load = 1'b0;

//   assign bp_addr = 16'h0007;
//   assign bp_step = 1'b1;
//   assign bp_continue = 1'b1;
   
   cpu gb80_cpu(.mem_we(mem_we),
                .mem_re(mem_re),
                .halt(halt),
                .addr_ext(addr_ext),
                .data_ext(data_ext),
                .clock(cpu_clock),
                .reset(reset),
                .A_data(A_data),
                .instruction(instruction),
                .regs_data(regs_data),
                .IF_data(IF_data),
                .IE_data(IE_data),
                .IF_in(IF_in),
                .IE_in(IE_in),
                .IF_load(IF_load),
                .IE_load(IE_load),
                .cpu_mem_disable(cpu_mem_disable),
                .bp_addr(bp_addr),
                .bp_step(bp_step),
                .bp_continue(bp_continue));
   
   my_clock_divider #(.DIV_SIZE(2), .DIV_OVER_TWO(4)) //~4.125MHz
   cdiv(.clock_out(cpu_clock),
        .clock_in(clock));
   
   breakpoints #(.reset_addr(16'h0007))
   bpmod(.bp_addr(bp_addr[15:0]),
         .bp_addr_disp(bp_addr_disp[7:0]),
         // Inputs
         .bp_addr_part_in(bp_addr_part_in[7:0]),
         .bp_hi_lo_sel_in(bp_hi_lo_sel_in),
         .bp_hi_lo_disp_in(bp_hi_lo_disp_in),
         .reset(reset),
         .clock(cpu_clock));

   wire        reg_w_enable;
   wire [7:0]  reg_data;
   wire [15:0] reg_addr;

   assign reg_w_enable = ((addr_ext >= 16'hFF10 && addr_ext <= 16'hFF1E) ||
			  (addr_ext >= 16'hFF30 && addr_ext <= 16'hFF3F) ||
			  (addr_ext >= 16'hFF20 && addr_ext <= 16'hFF26));
   assign reg_data = data_ext;//bram_data_in;
   assign reg_addr = addr_ext;//bram_addr;

   audio_top audio(.square_wave_enable(1'b1), 
		   .sample_no(1'b1),
		   .ac97_bitclk(ac97_bitclk),
		   .ac97_sdata_in(ac97_sdata_in),
		   .rotary_inc_a(rotary_inc_a),
		   .rotary_inc_b(rotary_inc_b),
		   .ac97_sdata_out(ac97_sdata_out),
		   .ac97_sync(ac97_sync),
		   .ac97_reset_b(ac97_reset_b),
		   .reset(reset),
/*		   .flash_wait(flash_wait),
		   .flash_d(flash_d),
		   .flash_a(flash_a),
		   .flash_adv_n(flash_adv_n),
		   .flash_ce_n(flash_ce_n),
		   .flash_clk(flash_clk),
		   .flash_oe_n(flash_oe_n),
		   .flash_we_n(flash_we_n),*/
		   .strobe(strobe),
		   .reg_addr(reg_addr),
		   .reg_data(reg_data),
		   .reg_w_enable(reg_w_enable)
		  );

`define MEM_HIGH_END 16'hfffe
`define MEM_HIGH_START 16'hff80
`define MEM_OAM_END 16'hfe9f
`define MEM_OAM_START 16'hfe00
`define MEM_CART_END 16'hbfff
`define MEM_CART_START 16'ha000
`define MEM_WRAM_END 16'hdfff
`define MEM_WRAM_START 16'hc000
`define MEM_VRAM_END 16'h9fff
`define MEM_VRAM_START 16'h8000
   
   wire        addr_in_wram, addr_in_vram, addr_in_oam, addr_in_junk;
   
   assign addr_in_wram = (`MEM_WRAM_START <= addr_ext) & 
                         (addr_ext <= `MEM_WRAM_END);
   assign addr_in_vram = (`MEM_VRAM_START <= addr_ext) & 
                         (addr_ext <= `MEM_VRAM_END);
   assign addr_in_oam =  (`MEM_OAM_START <= addr_ext) & 
                         (addr_ext <= `MEM_OAM_END);
   assign addr_in_junk = ~addr_in_flash & ~FF44_read & ~reg_w_enable &
                         ~timer_reg_addr & ~addr_in_wram & ~addr_in_vram &
                         ~addr_in_oam;

   /*assign bram_data_in = data_ext;
   assign bram_we = ~addr_in_flash & (mem_we | dma_mem_we);
   assign bram_addr = addr_ext;*/

   wire        wram_we, vram_we;
   wire [12:0] wram_addr;
   wire [13:0] vram_addr;
   wire [7:0]  vram_data_in, wram_data_in;
   wire [7:0]  vram_data_out, wram_data_out;
   
   wire [15:0] wram_addr_long;
   assign wram_data_in = data_ext;
   assign wram_we = addr_in_wram & mem_we;
   assign wram_addr_long = addr_ext - `MEM_WRAM_START;
   assign wram_addr = wram_addr_long[12:0]; // 8192 elts

   wire [15:0] vram_addr_long, oam_addr_long;
   assign vram_data_in = data_ext;
   assign vram_we = (addr_in_vram | addr_in_wram) & (mem_we | dma_mem_we);
   assign vram_addr_long = addr_ext - `MEM_VRAM_START; // 8192 elts
   assign oam_addr_long = (addr_ext - `MEM_OAM_START) + 
                          `MEM_VRAM_END + 16'h1; // 160 elts
   assign vram_addr = (addr_in_vram) ?
                      vram_addr_long[13:0] :
                      oam_addr_long[13:0];

   blockram8192
     br_wram(.clka(clock),
             .wea(wram_we),
             .addra(wram_addr),
             .dina(wram_data_in),
             .douta(wram_data_out));

   blockram8352
     br_vram(.clka(clock),
             .wea(vram_we),
             .addra(vram_addr),
             .dina(vram_data_in),
             .douta(vram_data_out));
   
   tristate #(8)
   gating_ff44(.out(data_ext),
	       .in(FF44_data),
	       .en(FF44_read&~mem_we));
   tristate #(8)
   gating_flash(.out(data_ext),
		.in(flash_d),
		.en(addr_in_flash & ~mem_we));
   tristate #(8)
   gating_wram(.out(data_ext),
               .in(wram_data_out),
               .en(addr_in_wram & ~mem_we & (mem_re | dma_mem_re)));
   tristate #(8)
   gating_vram(.out(data_ext),
               .in(vram_data_out),
               .en(addr_in_vram & ~mem_we));
   tristate #(8)
   gating_junk(.out(data_ext),
               .in(8'h00),
               .en(addr_in_junk & ~mem_we));
//   tristate #(8) gating_bram(.out(data_ext),
//			     .in(bram_data_out),
//			     .en(~addr_in_flash & ~FF44_read
//                                 & ~reg_w_enable & ~mem_we & ~timer_reg_addr
//                                 & (mem_re | dma_mem_re)));
   tristate #(8)
   gating_mem_regs(.out(data_ext),
		   .in(reg_data),
		   .en(reg_w_enable&~mem_we));

endmodule
// Local Variables:
// verilog-library-directories:(".")
// verilog-library-files:("./cpu.v")
// End:
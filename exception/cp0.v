`include "mycpu.h"

module cp0(
    input         clk,
    input         reset,
    input  [5:0]  ext_int_in,

    // from WB_stage to cp0_register
    input  [`WB_TO_CP0_REGISTER_BUS_WD -1:0] wb_to_cp0_register_bus,

    // from cp0_register to WB_stage, used in MTF0(read)
    output [`CP0_REGISTER_BUS_WD       -1:0] cp0_register

);

wire        wb_ex;        // exception sign passed to WB_stage
wire [4:0]  wb_excode;    // cause of the exception passed to WB_stage
wire [31:0] wb_badvaddr;  // wrong virtual address passed to WB_stage
wire        wb_bd;        // whether the instruction that generated the exception is in the delay slot
wire [31:0] wb_pc;        // pc of the instruction that generated the exception
// MTC0(write) signal
wire        mtc0_we;      // write enable signal
wire [31:0] c0_addr;      // write address of the coprocessor0 register
wire [31:0] c0_wdata;     // write data 
// ERET interface
wire        eret_flush;
assign {wb_ex,
        wb_excode,
        wb_badvaddr,
        wb_bd,
        wb_pc,
        mtc0_we,
        c0_addr,
        c0_wdata,
        eret_flush
       } = wb_to_cp0_register_bus;

assign cp0_register = {c0_badvaddr,
                       c0_count,
                       c0_compare,
                       c0_status_bev,
                       c0_status_im,
                       c0_status_exl, // remember that wherever cpu needs to check its priority state, it will check this signal
                       c0_status_ie,
                       c0_cause_bd,
                       c0_cause_ti,
                       c0_cause_ip,
                       c0_cause_excode

                        };

reg [31:0] c0_badvaddr;
reg [31:0] c0_count;
reg        tick;        //implement the upgrade of c0_count
reg [31:0] c0_compare;

// region of c0_status
wire       c0_status_bev;
assign     c0_status_bev = 1'b1;
reg [ 7:0] c0_status_im;
reg        c0_status_exl;
reg        c0_status_ie;

// region of c0_cause
reg        c0_cause_bd;
reg        c0_cause_ti;
reg [ 7:0] c0_cause_ip;
reg [ 4:0] c0_cause_excode;

reg [31:0] c0_epc;

// c0_badvaddr
always @(posedge clk)begin
    //`EX_ADEL represents wrong address when reading data or instruction
    //`EX_ADES represents wrong address when writing data
    if (wb_ex && (wb_excode==`EX_ADEL) || (wb_excode==`EX_ADES)) 
        c0_badvaddr <= wb_badvaddr;
end

// c0_count
always @(posedge clk)begin
    if (reset) tick <= 1'b0;
    else       tick <= ~tick;

    if (mtc0_we && c0_addr==`CR_COUNT)
        c0_count <= c0_wdata;
    else if(tick)
        c0_count <= c0_count + 1'b1;
end

// c0_compare
always @(posedge clk)begin
    if (mtc0_we && c0_addr==`CR_COMPARE)
        c0_compare <= c0_wdata;
end

// c0_status_im
always @(posedge clk)begin
    if (mtc0_we && c0_addr==`CR_STATUS)
        c0_status_im <= c0_wdata[15:8];
end

// c0_status_exl
always @(posedge clk)begin
    if (reset)
        c0_status_exl <= 1'b0;
    else if (wb_ex)
        c0_status_exl <= 1'b1;
    else if (eret_flush)
        c0_status_exl <= 1'b0;
    else if (mtc0_we && c0_addr==`CR_STATUS)
        c0_status_im <= c0_wdata[1];
end

// c0_status_ie
always @(posedge clk)begin
    if (reset)
        c0_status_ie <= 1'b0;
    else if (mtc0_we && c0_addr==`CR_STATUS)
        c0_status_ie <= c0_wdata[0];
end

// c0_cause_bd
always @(posedge clk)begin
    if (reset)
        c0_cause_bd <= 1'b0;
    else if (wb_ex && !c0_status_exl)
        c0_cause_bd <= wb_bd;
end

wire count_eq_compare;
assign count_eq_compare = c0_count==c0_compare;
// c0_cause_ti
always @(posedge clk)begin
    if (reset)
        c0_cause_ti <= 1'b0;
    else if (mtc0_we && c0_addr==`CR_COMPARE)
        c0_cause_ti <= 1'b0;
    else if (count_eq_compare)
        c0_cause_ti <= 1'b1;
end

// c0_cause_ip [7:2] and [1:0]
always @(posedge clk)begin
    if (reset)
        c0_cause_ip[7:2] <= 6'b0;
    else begin
        c0_cause_ip[7]   <= ext_int_in[5] | c0_cause_ti;
        c0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end

always @(posedge clk)begin
    if (reset)
        c0_cause_ip[1:0] <= 2'b0;
    else if (mtc0_we && c0_addr==`CR_CAUSE)
        c0_cause_ip[1:0] <= c0_wdata[9:8];
end

// c0_cause_excode
always @(posedge clk)begin
    if (reset)
        c0_cause_excode <= 5'b0;
    else if (wb_ex)
        c0_cause_excode <= wb_excode;
end

//c0_epc
always @(posedge clk)begin
    if (wb_ex && !c0_status_exl)
        c0_epc <= wb_bd ? wb_pc-3'h4 : wb_pc;
    else if (mtc0_we && c0_addr==`CR_EPC)
        c0_epc <= c0_wdata;
end    

endmodule
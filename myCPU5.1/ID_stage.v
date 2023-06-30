`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,

    //forward datapath
    input [32-1:0] ds_forward_bus,
    //forward control
    input[2-1:0] ds_forward_ctrl,
    //stall
    input [1:0]stallD, 
    output [10                -1:0] ds_to_es_addr,
    output ifbranch


);

 (* keep = "true" *) reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
 (* keep = "true" *) reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
//////1控制信号
wire [3:0]  ds_mudi;
wire [1:0]  ds_hl_we;
wire        dst_is_hi;
wire        dst_is_lo;
wire        res_from_hi;
wire        res_from_lo;
//////0
//wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
//////信号名更改
wire        src2_is_simm;
wire        src2_is_usimm;
//////
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
//forward path
wire [31:0] ms_to_ds_fvalue1;
wire [31:0] ms_to_ds_fvalue2;
//forward ctrl
wire ds_f_ctrl1;
wire ds_f_ctrl2;

assign {
    ds_f_ctrl1,      //1:1
    ds_f_ctrl2      //0:0
}=ds_forward_ctrl;



wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;


wire        rs_eq_rt;

assign br_bus       = {br_taken,br_target};

assign ds_to_es_bus = {//////
                       dst_is_hi   ,  //146:146
                       dst_is_lo   ,  //145:145
                       res_from_hi ,  //144:144
                       res_from_lo ,  //143:143
                       ds_hl_we    ,  //142:141
                       ds_mudi     ,  //140:137
                       //////
                       alu_op      ,  //136:125
                       res_from_mem,  //124:124
                       src1_is_sa  ,  //123:123
                       src1_is_pc  ,  //122:122
                       //////
                       src2_is_usimm, //121:121
                       src2_is_simm,  //120:120
                       //////
                       src2_is_8   ,  //119:119
                       gr_we       ,  //118:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };

assign ds_ready_go    = 1'b1;
assign ds_allowin     = (stallD==2'b01)?1'b0:
                        (stallD==2'b10)?1'b1:(!ds_valid || ds_ready_go && es_allowin);

assign ds_to_es_valid = (stallD==2'b01)?1'b0:
                        (stallD==2'b10)?1'b0:(ds_valid && ds_ready_go);
//这里是flush操作
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
   else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end



assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

//第五章逻辑运算
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
//第五章数据搬运
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & sa_d[5'h00] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & sa_d[5'h00] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & sa_d[5'h00] & rt_d[5'h00] & rd_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & sa_d[5'h00] & rt_d[5'h00] & rd_d[5'h00];
//第五章乘除
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00] & rd_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00] & rd_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00] & rd_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00] & rd_d[5'h00];
//第六章转移
//第六章访存

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal | inst_add | inst_addi;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_sll  | inst_sllv;
assign alu_op[ 9] = inst_srl  | inst_srlv;
assign alu_op[10] = inst_sra  | inst_srav;
assign alu_op[11] = inst_lui;

assign ds_mudi[0] = inst_mult;
assign ds_mudi[1] = inst_multu;
assign ds_mudi[2] = inst_div;
assign ds_mudi[3] = inst_divu;
assign ds_hl_we[1]   = (inst_mult | inst_multu | inst_div | inst_divu | inst_mthi) ? 1'b1 :
                        1'b0;
assign ds_hl_we[0]   = (inst_mult | inst_multu | inst_div | inst_divu | inst_mtlo) ? 1'b1 :
                        1'b0;
assign dst_is_hi  = inst_mthi;
assign dst_is_lo  = inst_mtlo;
assign res_from_hi = inst_mfhi;
assign res_from_lo = inst_mflo;

//bug1,Load悬空

assign src1_is_sa   = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal;
assign src2_is_simm = inst_addiu | inst_lui | inst_lw | inst_sw | inst_addi | inst_slti | inst_sltiu;
assign src2_is_usimm = inst_andi | inst_ori | inst_xori;
assign src2_is_8    = inst_jal;
assign res_from_mem = inst_lw && ds_valid;   //是这个
assign dst_is_r31   = inst_jal;
assign dst_is_rt    = inst_addiu | inst_lui | inst_lw | inst_addi | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori;
assign gr_we        = (~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr)&& ds_valid;
assign mem_we       = inst_sw && ds_valid;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );


//backward path
assign ds_to_es_addr={
    rf_raddr1,       //9:5
    rf_raddr2      //4:0
};

assign rs_value = ds_f_ctrl1?ds_forward_bus:rf_rdata1;
assign rt_value = ds_f_ctrl2?ds_forward_bus:rf_rdata2;

assign rs_eq_rt = (rs_value == rt_value);
assign ifbranch =(inst_beq || inst_bne) ;
assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || inst_jal
                   || inst_jr
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr)              ? rs_value :
                  /*inst_jal*/              {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule

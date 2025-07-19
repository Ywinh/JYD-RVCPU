`include "core.v"

module exe_stage(
    input                    clk                 ,
    input                    reset               ,
    //allowin
    input                    ms_allowin          ,
    output                   es_allowin          ,
    //from ds
    input                    ds_to_es_valid      ,
    input      [`DS_TO_ES_BUS_WD -1:0]     ds_to_es_bus        ,
    //to ms
    output                   es_to_ms_valid      ,
    output     [`ES_TO_MS_BUS_WD -1:0]     es_to_ms_bus        ,
    // ex
    input                    ws_ex               ,
    input                    ws_mret             ,
    // forword & block from es
    output     [`ES_FWD_BLK_BUS_WD -1:0]     es_fwd_blk_bus      ,
    // DRAM interface
    output     [   3: 0]     data_sram_wen        ,
    output     [  31: 0]     data_sram_addr      , // perip_addr
    output     [  31: 0]     data_sram_wdata     ,     
    output     [  1: 0]      data_sram_mask     ,
    // forward: ms_to_es forward to solve sw-lw hazard
    input      [`MS_FWD_ES_BUS_WD-1:0] ms_fwd_es_bus
);
//-------------------------------------------------------------
// pipeline
//-------------------------------------------------------------
//from ds
reg     [`DS_TO_ES_BUS_WD -1:0]     ds_to_es_bus_r     ;
wire                  es_shift_op        ;
wire                  es_shift_op_i      ;
wire                  es_inst_lw         ;
wire                  es_inst_lh         ;
wire                  es_inst_lhu        ;
wire                  es_inst_lb         ;
wire                  es_inst_lbu        ;
wire                  es_inst_sw         ;
wire                  es_inst_sh         ;
wire                  es_inst_sb         ;
wire    [   9: 0]     es_alu_op          ;
wire                  es_csr_op          ;
wire                  es_rs1_is_4        ;
wire                  es_rs1_is_imm_u    ;
wire                  es_rs2_is_zero     ;
wire                  es_rs2_is_imm      ;
wire                  es_rs2_is_shamt    ;
wire                  es_rs2_is_pc       ;
wire                  es_res_from_mem    ;
wire                  es_gpr_we          ;
wire                  es_mem_we          ;
wire    [   4: 0]     es_dest            ;
wire    [   4: 0]     es_shamt           ;
wire    [  11: 0]     es_imm             ;
wire    [  11: 0]     es_csr_addr        ;
wire    [  19: 0]     es_imm_u           ;
wire    [  31: 0]     es_rs1_value       ;
wire    [  31: 0]     es_rs2_value       ;
wire    [  31: 0]     es_pc              ;
wire    [  31: 0]     es_csr_rdata       ;
wire    [  31: 0]     es_csr_wdata       ;
wire    [  31: 0]     ds_epc             ;
wire    [  31: 0]     ds_excode          ;
wire    [  31: 0]     es_einst           ;
wire                  ds_ex              ;
wire                  inst_mret          ;

wire    [  31: 0]     es_alu_rs1         ;
wire    [  31: 0]     es_alu_rs2         ;
wire    [  31: 0]     es_alu_result      ;
wire    [  31: 0]     es_exe_result      ;
wire                  overflow           ;

wire                  es_inst_jl         ;
wire                  inst_ebreak        ;
wire                  inst_ecall         ;

assign {
    es_einst        ,                                               //342:311
    inst_ebreak     ,                                               //310:310
    inst_ecall      ,                                               //309:309
    es_inst_jl      ,                                               //308:308
    ds_epc          ,                                               //307:276
    ds_excode       ,                                               //275:244
    ds_ex           ,                                               //243:243
    inst_mret       ,                                               //242:242
    es_csr_addr     ,                                               //241:230
    es_csr_rdata    ,                                               //229:198
    es_csr_wdata    ,                                               //197:166
    es_inst_lw      ,                                               //165:165
    es_inst_lh      ,                                               //164:164
    es_inst_lhu     ,                                               //163:163
    es_inst_lb      ,                                               //162:162
    es_inst_lbu     ,                                               //161:161
    es_inst_sw      ,                                               //160:160
    es_inst_sh      ,                                               //159:159
    es_inst_sb      ,                                               //158:158
    es_rs1_is_4     ,                                               //157:157
    es_rs2_is_zero  ,                                               //156:156
    es_imm_u        ,                                               //155:136
    es_alu_op       ,                                               //135:126
    es_csr_op       ,                                               //125:125
    es_rs1_is_imm_u ,                                               //124:124
    es_rs2_is_imm   ,                                               //123:123
    es_rs2_is_shamt ,                                               //122:122
    es_rs2_is_pc    ,                                               //121:121
    es_res_from_mem ,                                               //120:120
    es_gpr_we       ,                                               //119:119
    es_mem_we       ,                                               //118:118
    es_shamt        ,                                               //117:113
    es_dest         ,                                               //112:108
    es_imm          ,                                               //107:96
    es_rs1_value    ,                                               //95 :64
    es_rs2_value    ,                                               //63 :32
    es_pc                                                           //31 :0
} = ds_to_es_bus_r;

//to ms
wire    [  31: 0]     es_epc             ;
wire                  es_ex              ;
wire    [  31: 0]     es_excode          ;

wire                  es_store_load_hazard;
// wire    [  31: 0]     es_final_wdata; 

assign es_to_ms_bus = {
    es_store_load_hazard,                                           //321:321
    es_mem_we       ,                                               //320:320
    // es_final_wdata,                                                 //319:288 //这个是ms旁路过来的，保存到bus里面，有点奇怪，用到了吗？
    data_sram_wen,                                                  //288:285
    data_sram_addr  ,                                               //31位, 284:253
    data_sram_wdata ,                                               //252:221 //这个是exe阶段的，保存到bus里面，便于后续传过来
    es_einst        ,                                               //220:189
    inst_ebreak     ,                                               //188:188
    inst_ecall      ,                                               //187:187
    es_epc          ,                                               //186:155
    es_excode       ,                                               //154:123
    es_ex           ,                                               //122:122
    inst_mret       ,                                               //121:121
    es_csr_op       ,                                               //120:120
    es_csr_addr     ,                                               //119:108
    es_csr_wdata    ,                                               //107:76
    es_inst_lw      ,                                               //75:75
    es_inst_lh      ,                                               //74:74
    es_inst_lhu     ,                                               //73:73
    es_inst_lb      ,                                               //72:72
    es_inst_lbu     ,                                               //71:71
    es_res_from_mem ,                                               //70:70
    es_gpr_we       ,                                               //69:69
    es_dest         ,                                               //68:64
    es_exe_result   ,                                               //63:32
    es_pc                                                           //31:0
};

//es reg
reg                   es_valid           ;
wire                  es_ready_go        ;

assign es_ready_go      = 1'b1;
assign es_allowin       = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid   = es_valid && es_ready_go && !ws_mret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_rs1      =  es_rs1_is_imm_u ? {es_imm_u,12'b0} :
                          es_rs1_is_4     ? 32'd4            :
                          es_rs1_value;
assign es_alu_rs2      =  es_rs2_is_imm   ? {{20{es_imm[11]}}, es_imm[11:0]} : 
                          es_rs2_is_shamt ? es_shamt :
                          es_rs2_is_pc    ? es_pc    :
                          es_rs2_is_zero  ? 32'b0    :
                          es_rs2_value;

assign es_exe_result    = es_csr_op ? es_csr_rdata   : 
                          es_inst_jl ? es_pc + 32'd4 :
                          es_alu_result;
//-------------------------------------------------------------
// alu
//-------------------------------------------------------------

alu u_alu(
    .alu_op                (es_alu_op                 ),
    .alu_src1              (es_alu_rs1                ),
    .alu_src2              (es_alu_rs2                ),
    .alu_result            (es_alu_result             ),
    .overflow              (overflow                  ) 
    );
//-------------------------------------------------------------
// forward & block
//-------------------------------------------------------------
wire    [ 3: 0]     es_fwd_valid       ;
wire    [ 4: 0]     es_rf_dest         ;
wire    [31: 0]     es_rf_data         ;
wire                es_blk_valid       ;

assign es_fwd_valid     = {4{ es_valid && es_gpr_we && !es_res_from_mem }}; // 1:前递有效 0:前递无效
assign es_rf_dest       = es_dest;
assign es_rf_data       = es_exe_result;
assign es_blk_valid     = es_valid && es_res_from_mem; // 1:阻塞 0:不阻塞

assign es_fwd_blk_bus = {
    es_fwd_valid,   // 41:38
    es_rf_dest,     // 37:33
    es_rf_data,     // 32:1
    es_blk_valid    // 0:0
};

wire                        ms_valid;
wire                        ms_mem_we;
wire        [31:0]          ms_data_sram_addr; // 32位
assign {
    ms_valid,          // 65:65
    ms_mem_we,         // 64:64
    ms_data_sram_addr // 63:32
    // es_final_wdata // 31:0
} = ms_fwd_es_bus;

// sw-lw hazard
assign es_store_load_hazard = ms_valid & ms_mem_we & (ms_data_sram_addr == data_sram_addr);

//-------------------------------------------------------------
// exception
//-------------------------------------------------------------
wire                  es_w_addr_error    ;//lw and sw
wire                  es_h_addr_error    ;//lh and lhu and sh
assign es_w_addr_error  = (es_res_from_mem || es_mem_we) &&
                          (es_alu_result[1:0] != 2'b0) && 
                          (es_inst_lw || es_inst_sw);
assign es_h_addr_error  = (es_res_from_mem || es_mem_we) &&
                          (es_alu_result[0] != 1'b0) && 
                          (es_inst_lh || es_inst_sh);
// wire                  es_ex              ;
// wire    [  31: 0]     es_excode          ;
// wire    [  31: 0]     es_epc             ;

assign es_ex = (es_w_addr_error || es_h_addr_error || ds_ex) && es_valid;
assign es_excode = (es_w_addr_error || es_h_addr_error) ? `EX_LAM : ds_excode;
assign es_epc           = ds_epc;

//-------------------------------------------------------------
// data ram
//-------------------------------------------------------------
wire    [   31: 0]     es_ram_wdata       ;
wire    [   31: 0]     es_st_data         ;
wire    [   1:  0]     es_st_addr         ;
wire    [  15:  0]     es_mem_dest        ; 
wire    [   1:  0]     es_access_size     ;

assign es_mem_dest      = es_alu_result[15:2]; //修改
assign es_st_addr       = es_alu_result[1:0]; //偏移
assign es_ram_wdata     =  es_rs2_value;
assign es_st_data = es_inst_sb ? {4{es_rs2_value[ 7:0]}} :  es_inst_sh ? {2{es_rs2_value[15:0]}} :  es_rs2_value[31:0];
assign es_access_size = es_inst_sb ? 2'b00 :
                        es_inst_sh ? 2'b01 :
                        /*sw*/       2'b10;

// data ram interface
// assign data_sram_wen     = es_valid && es_mem_we;
assign data_sram_wen = {4{es_valid}} & (es_inst_sw ? 4'b1111 :
                        es_inst_sh ? (es_st_addr == 2'b00 ? 4'b0011 :
                                      es_st_addr == 2'b10 ? 4'b1100 :
                                      4'b0000
                                      ) :
                        es_inst_sb ? (es_st_addr == 2'b00 ? 4'b0001 :
                                      es_st_addr == 2'b01 ? 4'b0010 :
                                      es_st_addr == 2'b10 ? 4'b0100 :
                                      es_st_addr == 2'b11 ? 4'b1000 :
                                      4'b0000
                                      ) :
                        4'b0000);
                                
assign data_sram_addr   = es_mem_dest;
assign data_sram_wdata  = es_st_data;
assign data_sram_mask   = es_access_size;

endmodule
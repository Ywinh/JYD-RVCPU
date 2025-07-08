`include "core.v"

module mem_stage(
    input                    clk                 ,
    input                    reset               ,
    //allowin
    input                    ws_allowin          ,
    output                   ms_allowin          ,
    //from es
    input                    es_to_ms_valid      ,
    input      [`ES_TO_MS_BUS_WD -1:0]     es_to_ms_bus        ,
    //to ws
    output                   ms_to_ws_valid      ,
    output     [`MS_TO_WS_BUS_WD -1:0]     ms_to_ws_bus        ,
    // ex
    input                    ws_ex               ,
    input                    ws_mret             ,
    // forword from es
    output     [`MS_FWD_BLK_BUS_WD -1:0]     ms_fwd_blk_bus      ,
    //data sram interface
    input      [  31: 0]     data_sram_rdata   
);

//-------------------------------------------------------------
// pipeline
//-------------------------------------------------------------
//from es
reg     [`ES_TO_MS_BUS_WD -1:0]     es_to_ms_bus_r     ;
wire                  ms_inst_lw         ;
wire                  ms_inst_lh         ;
wire                  ms_inst_lhu        ;
wire                  ms_inst_lb         ;
wire                  ms_inst_lbu        ;
wire                  ms_res_from_mem    ;
wire                  ms_gpr_we          ;
wire                  ms_csr_op          ;
wire    [   4: 0]     ms_dest            ;
wire    [  11: 0]     ms_csr_addr        ;
wire    [  31: 0]     ms_exe_result      ;
wire    [  31: 0]     ms_pc              ;
wire    [  31: 0]     ms_einst           ;
wire    [  31: 0]     ms_mem_res         ;
wire    [  31: 0]     ms_csr_wdata       ;
wire                  es_ex              ;
wire    [  31: 0]     es_excode          ;
wire    [  31: 0]     es_epc             ;
wire                  es_mret            ;
wire                  es_ecall           ;
wire                  es_ebreak          ;

assign {
    ms_einst        ,                                               //220:189
    es_ebreak       ,                                               //188:188
    es_ecall        ,                                               //187:187
    es_epc          ,                                               //186:155
    es_excode       ,                                               //154:123
    es_ex           ,                                               //122:122
    es_mret         ,                                               //121:121
    ms_csr_op       ,                                               //120:120
    ms_csr_addr     ,                                               //119:108
    ms_csr_wdata    ,                                               //107:76
    ms_inst_lw      ,                                               //75:75
    ms_inst_lh      ,                                               //74:74
    ms_inst_lhu     ,                                               //73:73
    ms_inst_lb      ,                                               //72:72
    ms_inst_lbu     ,                                               //71:71
    ms_res_from_mem ,                                               //70:70
    ms_gpr_we       ,                                               //69:69
    ms_dest         ,                                               //68:64
    ms_exe_result   ,                                               //63:32
    ms_pc                                                           //31:0
} = es_to_ms_bus_r;

// to ws
wire    [  31: 0]     mem_result         ;
wire    [   3: 0]     ms_gpr_strb        ;
wire    [  31: 0]     ms_result          ;

wire                  ms_ebreak          ;
wire                  ms_ecall           ;
wire                  ms_ex              ;
wire                  ms_mret            ;
wire    [  31: 0]     ms_excode          ;
wire    [  31: 0]     ms_epc             ;

assign ms_result        = ms_res_from_mem ? ms_mem_res :
                                            ms_exe_result;
assign ms_gpr_strb = {4{ms_gpr_we}};

assign ms_to_ws_bus = {
    ms_einst        ,                                               //217:186
    ms_ebreak   ,                                                   //185:185
    ms_ecall    ,                                                   //184:184
    ms_epc      ,                                                   //183:152
    ms_excode   ,                                                   //151:120
    ms_ex       ,                                                   //119:119
    ms_mret     ,                                                   //118:118
    ms_csr_op   ,                                                   //117:117
    ms_csr_addr ,                                                   //116:105
    ms_csr_wdata,                                                   //104:73
    ms_gpr_strb ,                                                   //72:69
    ms_dest     ,                                                   //68:64
    ms_result   ,                                                   //63:32
    ms_pc                                                           //31:0
};

//ms reg
reg                   ms_valid           ;
wire                  ms_ready_go        ;

assign ms_ready_go      = 1'b1;
assign ms_allowin       = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid   = ms_valid && ms_ready_go && !ws_mret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

//-------------------------------------------------------------
// forward & block
//-------------------------------------------------------------
wire    [ 3: 0]     ms_fwd_valid       ;
wire    [ 4: 0]     ms_rf_dest         ;
wire    [31: 0]     ms_rf_data         ;

assign ms_fwd_valid     = {4{ ms_valid }} & ms_gpr_strb;
assign ms_rf_dest       = ms_dest;
assign ms_rf_data       = ms_result;

assign ms_fwd_blk_bus = {
    ms_fwd_valid,   // 40:37
    ms_rf_dest,     // 36:32
    ms_rf_data      // 31:0
};

//-------------------------------------------------------------
// exception
//-------------------------------------------------------------
// wire                  ms_ecall           ;
// wire                  ms_ebreak          ;
// wire                  ms_ex              ;
// wire                  ms_mret            ;
// wire    [  31: 0]     ms_excode          ;
// wire    [  31: 0]     ms_epc             ;

assign ms_mret          = es_mret;
assign ms_ecall         = es_ecall;
assign ms_ebreak        = es_ebreak;
assign ms_ex            = es_ex && ms_valid;
assign ms_excode        = es_excode;
assign ms_epc           = es_epc;
//-------------------------------------------------------------
// data ram
//-------------------------------------------------------------
wire    [   1: 0]     ms_ld_addr         ;
assign ms_ld_addr       = ms_exe_result[1:0];

wire    [  31: 0]     ms_lw_data         ;
wire    [  15: 0]     ms_lh_data         ;
wire    [   7: 0]     ms_lb_data         ;

assign ms_lw_data       = data_sram_rdata;
assign ms_lh_data       = data_sram_rdata[15: 0];
assign ms_lb_data       = data_sram_rdata[ 7: 0];

assign ms_mem_res       = ms_inst_lh  ? {{16{ms_lh_data[15]}},ms_lh_data} :
                          ms_inst_lhu ? {16'b0,ms_lh_data}:
                          ms_inst_lb  ? {{24{ms_lb_data[7]}},ms_lb_data} :
                          ms_inst_lbu ? {24'b0,ms_lb_data} :
                          ms_inst_lw  ?  ms_lw_data : 32'b0;

endmodule

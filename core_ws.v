`include "core.v"

module wb_stage(
    input                    clk                 ,
    input                    reset               ,
    //allowin
    output                   ws_allowin          ,
    //from ms
    input                    ms_to_ws_valid      ,
    input      [`MS_TO_WS_BUS_WD -1:0]     ms_to_ws_bus        ,
    //to rf: for write back
    output     [`WS_TO_RF_BUS_WD -1:0]     ws_to_rf_bus        ,
    //to csr
    // output     [`WS_TO_CSR_BUS_WD -1:0]    ws_to_csr_bus       ,
    //ex
    // output                   ws_ex               ,
    // output                   ws_mret             ,
    //trace debug interface
    output     [  31: 0]     debug_wb_pc         ,
    output     [   3: 0]     debug_wb_rf_wen    ,
    output     [   4: 0]     debug_wb_rf_wnum    ,
    output     [  31: 0]     debug_wb_rf_wdata   ,

    // sw-lw bypass
    output     [`WS_TO_MS_BYPASS_WD -1:0 ]   ws_to_ms_bypass
);
//-------------------------------------------------------------
// pipeline
//-------------------------------------------------------------
//from ms
reg     [`MS_TO_WS_BUS_WD -1:0]     ms_to_ws_bus_r     ;
wire    [   3: 0]     ws_gpr_strb        ;
wire    [   4: 0]     ws_dest            ;
wire    [  31: 0]     ws_result          ;
wire    [ 31: 0]      ws_wdata           ;
wire                  ws_mem_we          ;
wire    [  31: 0]     ws_pc              ;


// wire    [  31: 0]     ws_einst           ;
// wire    [  31: 0]     ws_csr_wdata       ;
// wire                  ms_to_ws_ex        ;
// wire                  ms_to_ws_mret      ;
// wire    [  31: 0]     ws_excode          ;
// wire    [  31: 0]     ws_epc             ;
// wire                  ws_ebreak          ;
// wire                  ws_ecall           ;
// wire                  ws_csr_op          ;
// wire    [  11: 0]     ws_csr_addr        ;

assign {
    ws_wdata,
    ws_mem_we,
    // ws_einst    ,                                                   //217:186
    // ws_ebreak   ,                                                   //185:185
    // ws_ecall    ,                                                   //184:184
    // ws_epc      ,                                                   //183:152
    // ws_excode   ,                                                   //151:120
    // ms_to_ws_ex ,                                                   //119:119
    // ms_to_ws_mret,                                                  //118:118
    // ws_csr_op   ,                                                   //117:117
    // ws_csr_addr ,                                                   //116:105
    // ws_csr_wdata,                                                   //104:73
    ws_gpr_strb ,                                                   //72:69
    ws_dest     ,                                                   //68:64
    ws_result   ,                                                   //63:32
    ws_pc                                                           //31:0
} = ms_to_ws_bus_r;

//to rf
wire    [   3: 0]     rf_we              ;
wire    [   4: 0]     rf_waddr           ;
wire    [  31: 0]     rf_wdata           ;

//ws reg
reg                   ws_valid           ;
wire                  ws_ready_go        ;

assign rf_we            = ws_gpr_strb & {4{ws_valid}};
assign rf_waddr         = ws_dest;
assign rf_wdata         = ws_result;

assign ws_to_rf_bus = {
    rf_we,                                                          //40:37
    rf_waddr,                                                       //36:32
    rf_wdata                                                        //31:0
};

assign ws_to_ms_bypass = {
    ws_mem_we,
    ws_wdata
};

assign ws_ready_go      = 1'b1;
assign ws_allowin       = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

//-------------------------------------------------------------
// csr
//-------------------------------------------------------------
// assign ws_ex            = ms_to_ws_ex && ws_valid;
// assign ws_mret          = ms_to_ws_mret && ws_valid;

// assign ws_to_csr_bus = {
//     ws_einst,                                                       //144:113
//     ws_ebreak,                                                      //112:112
//     ws_ecall,                                                       //111:111
//     ws_epc,                                                         //110:79
//     ws_excode,                                                      //78:47
//     ws_ex,                                                          //46:46
//     ws_mret,                                                        //45:45
//     ws_csr_wdata,                                                   //44:2
//     ws_csr_addr ,                                                   //12:1
//     ws_csr_op                                                       //0:0
// }
// ;

// debug info generate
assign debug_wb_pc      = ws_pc;
assign debug_wb_rf_wen = {4{ws_valid}} & rf_we;
assign debug_wb_rf_wnum = ws_dest;
assign debug_wb_rf_wdata= rf_wdata;


endmodule

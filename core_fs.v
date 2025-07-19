`include "core.v"

module if_stage(
    input                    clk                 ,
    input                    reset               ,
    // allwoin
    input                    ds_allowin          ,
    output                   fs_allowin          ,
    //to fs: for branch stall
    input                    br_stall            ,
    // from pfs
    input                    ps_to_fs_valid      ,
    input      [`PS_TO_FS_BUS_WD -1:0]     ps_to_fs_bus        ,
    // to ds
    output                   fs_to_ds_valid      ,
    output     [`FS_TO_DS_BUS_WD -1:0]     fs_to_ds_bus        ,
    // ex
    input                    ws_ex               ,
    input                    ws_mret             ,
    // IROM interface
    input      [  31: 0]     inst_sram_rdata     ,
    // branch predict
    output     [  31: 0]     pc_next             ,
    output                   inst_b_type         
);

//-------------------------------------------------------------
// pipeline
//-------------------------------------------------------------
// from ps
wire    [  31: 0]     ps_epc             ;
wire    [  31: 0]     ps_excode          ;
wire                  ps_ex              ;
wire    [  31: 0]     ps_pc              ;
reg     [`PS_TO_FS_BUS_WD -1:0]     ps_to_fs_bus_r    ;

assign {
    ps_epc   ,                                                      //96:65
    ps_excode,                                                      //64:33
    ps_ex    ,                                                      //32:32
    ps_pc                                                           //31:0
} = ps_to_fs_bus_r;

//to ds
wire    [  31: 0]     fs_inst            ;
wire    [  31: 0]     fs_pc              ;
wire    [  31: 0]     fs_epc             ;
wire    [  31: 0]     fs_excode          ;
wire                  fs_ex              ;

assign fs_pc            = ps_pc;

assign fs_to_ds_bus = {
    predict_taken,                                                  //129
    fs_epc,                                                         //128:97
    fs_excode,                                                      //96:65
    fs_ex   ,                                                       //64:64
    fs_inst ,                                                       //63:32
    fs_pc                                                           //31:0
};

// fs reg
reg                   fs_valid           ;
wire                  fs_ready_go        ;

assign fs_ready_go      = !br_stall;// || flush);
assign fs_allowin       = !fs_valid || (fs_ready_go && ds_allowin) || br_stall;
assign fs_to_ds_valid   = fs_valid && fs_ready_go && !ws_ex && !ws_mret;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end else if (fs_allowin) begin
        fs_valid <= ps_to_fs_valid;
    end

    if (ps_to_fs_valid && fs_allowin) begin
        ps_to_fs_bus_r <= ps_to_fs_bus;
    end
end
//-------------------------------------------------------------
// exception
//-------------------------------------------------------------
// wire    [  31: 0]     fs_epc             ;
// wire    [  31: 0]     fs_excode          ;
// wire                  fs_ex              ;

assign fs_epc           = ps_epc;
assign fs_excode        = ps_excode;
assign fs_ex            = ps_ex && fs_valid;
//-------------------------------------------------------------
// inst ram
//-------------------------------------------------------------
reg     [  31: 0]     fs_inst_r          ;
wire                  fs_inst_latch      ;
reg                   fs_inst_latch_r    ;

/*assign fs_inst_latch = !(ps_to_fs_valid && fs_allowin);
always @(posedge clk) begin                                        
    if(reset) begin                               
        fs_inst_latch_r <= 1'b0;
    end else begin
        fs_inst_latch_r <= fs_inst_latch;
    end                           
end


always @(posedge clk) begin
    if (reset)
        fs_inst_r <= 32'b0;
    else if (!fs_inst_latch_r)  // latch = 0 表示允许读取新指令
        fs_inst_r <= inst_sram_rdata;
end
*/

always @(posedge clk) begin
    if (reset)
        fs_inst_r <= 32'b0;
    else if (ps_to_fs_valid && fs_allowin)  // 只在真正流入新指令时才更新
        fs_inst_r <= inst_sram_rdata;
end

// 输出
assign fs_inst = fs_inst_r;

wire [31:0] branch_pc;

assign      inst_b_type = (fs_inst_r[6:0] == 7'b1100011) ? 1 : 0 ;

//wire predict_taken;

branch_predict branch_predict1(
    .pc(fs_pc),
    .dest_inst(fs_inst_r),
    .inst_b_type(inst_b_type),
    .predict_pc(branch_pc),
    .fw_or_bw(predict_taken)
);


assign pc_next = branch_pc ;

endmodule
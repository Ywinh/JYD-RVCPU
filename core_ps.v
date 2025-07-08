`include "core.v"

module pre_if_stage(                                                // instruction require stage
    input                    clk                 ,
    input                    reset               ,
    // from fs
    input                    fs_allowin          ,
    // to fs
    output                   ps_to_fs_valid      ,
    output     [`PS_TO_FS_BUS_WD - 1:0]     ps_to_fs_bus        ,
    // from ds
    input      [`BR_BUS_WD       -1:0]     br_bus              ,
    // ex
    input                    ws_ex               ,
    input                    ws_mret             ,
    input      [  31: 0]     csr_mtvec           ,
    input      [  31: 0]     csr_mepc            ,
    // IROM interface
    // output                   inst_sram_en        ,
    // output     [   3: 0]     inst_sram_wen       ,
    // output     [  31: 0]     inst_sram_wdata     
    output     [  31: 0]     inst_sram_addr
    );

//-------------------------------------------------------------
// pipeline
//-------------------------------------------------------------
// to fs
wire    [  31: 0]     ps_pc              ;
wire                  ps_ex              ;
wire    [  31: 0]     ps_epc             ;
wire    [  31: 0]     ps_excode          ;

assign ps_to_fs_bus    = {
    ps_epc   ,                                                      //96:65
    ps_excode,                                                      //64:33
    ps_ex    ,                                                      //32:32
    ps_pc                                                           // 31:0
};

wire                  ps_valid           ;
wire                  ps_ready_go        ;

assign ps_valid         = ~reset;
assign ps_ready_go      = 1'b1;
assign ps_to_fs_valid   = ps_valid && ps_ready_go;

//-------------------------------------------------------------
// pc control
//-------------------------------------------------------------
reg     [  31: 0]     seq_pc             ;

always @ (posedge clk   ) begin
    if (reset) begin
        seq_pc <= `RESET_ADDR;
    end else if (ps_ready_go && fs_allowin) begin
        seq_pc <= ps_pc + 32'h4;
    end
end

//-------------------------------------------------------------
// branch and jump
//-------------------------------------------------------------
wire                  br_taken           ;
wire    [  31: 0]     br_target          ;

assign {
    br_taken,
    br_target
} = br_bus;

assign ps_pc            = ws_mret  ? csr_mepc  :
                          ws_ex    ? csr_mtvec :
                          br_taken ? br_target :
                          seq_pc;

//-------------------------------------------------------------
// exception
//-------------------------------------------------------------
wire                  ps_addr_error      ;
// wire                  ps_ex              ;
// wire    [  31: 0]     ps_epc             ;
// wire    [  31: 0]     ps_excode          ;

assign ps_addr_error    = (ps_pc[1:0] != 2'b00);
assign ps_ex            = ps_addr_error && ps_valid;
assign ps_excode        = ps_ex ? `EX_IAM : `EX_NOP;
assign ps_epc           = ps_pc;

//-------------------------------------------------------------
// inst ram
//-------------------------------------------------------------
assign inst_sram_en     = 1'b1;
assign inst_sram_wen    = 4'b0000;
assign inst_sram_addr   = ps_pc;
assign inst_sram_wdata  = 32'b0;

endmodule
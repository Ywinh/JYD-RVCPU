`timescale 1ns / 1ps
`include "../imports/core/core.v"

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/03 22:42:03
// Design Name: 
// Module Name: Core_cpu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Core_cpu(
    input cpu_rst,
    input cpu_clk,

    // Interface to IROM
    output logic [31:0] irom_addr,             
    input logic [31:0] irom_data,   

    // Interface to DRAM & periphera
    output logic [31:0] perip_addr,     
    output logic perip_wen,             // 1:write, 0:read or nop
    output logic [1:0] perip_mask,      // 00: r/w 1 byte, 01: r/w 2 byte, 10: r/w 4 byte, 
    output logic [31:0] perip_wdata,    
    input logic [31:0] perip_rdata  
    );

reg                   reset              ;
wire                  clk = cpu_clk      ;
always @(posedge clk) reset <= ~cpu_rst;

wire                  ws_ex              ;
wire                  ws_mret            ;
wire    [  31: 0]     csr_mtvec          ;
wire    [  31: 0]     csr_mepc           ;
wire    [  11: 0]     csr_raddr          ;
wire    [  31: 0]     csr_rdata          ;

wire                  br_stall           ;
wire                  fs_allowin         ;
wire                  ds_allowin         ;
wire                  es_allowin         ;
wire                  ms_allowin         ;
wire                  ws_allowin         ;
wire                  ps_to_fs_valid     ;
wire                  fs_to_ds_valid     ;
wire                  ds_to_es_valid     ;
wire                  es_to_ms_valid     ;
wire                  ms_to_ws_valid     ;
wire    [`PS_TO_FS_BUS_WD -1:0]     ps_to_fs_bus       ;
wire    [`FS_TO_DS_BUS_WD -1:0]     fs_to_ds_bus       ;
wire    [`DS_TO_ES_BUS_WD -1:0]     ds_to_es_bus       ;
wire    [`ES_TO_MS_BUS_WD -1:0]     es_to_ms_bus       ;
wire    [`MS_TO_WS_BUS_WD -1:0]     ms_to_ws_bus       ;
wire    [`WS_TO_RF_BUS_WD -1:0]     ws_to_rf_bus       ;
wire    [`BR_BUS_WD       -1:0]     br_bus             ;
wire    [`WS_TO_CSR_BUS_WD -1:0]    ws_to_csr_bus      ;
wire    [`ES_FWD_BLK_BUS_WD -1:0]   es_fwd_blk_bus     ;
wire    [`MS_FWD_BLK_BUS_WD -1:0]   ms_fwd_blk_bus     ;

// PIF stage
pre_if_stage pre_if_stage(
    .clk            (clk            ),//i
    .reset          (reset          ),//i
    //allowin
    .fs_allowin     (fs_allowin     ),//i
    //to fs
    .ps_to_fs_valid (ps_to_fs_valid ),//o
    .ps_to_fs_bus   (ps_to_fs_bus   ),//o
    //brbus
    .br_bus         (br_bus         ),
    // ex
    .ws_ex          (ws_ex          ),
    .ws_mret        (ws_mret        ),
    .csr_mepc       (csr_mepc       ),
    .csr_mtvec      (csr_mtvec      ),
    // inst sram interface
    .inst_sram_addr (irom_addr )//o,32
);

// IF stage
if_stage if_stage(
    .clk            (clk            ),//i
    .reset          (reset          ),//i
    //allowin
    .ds_allowin     (ds_allowin     ),//i
    .fs_allowin     (fs_allowin     ),//o
    //branch stall
    .br_stall       (br_stall       ),//i
    //from ps
    .ps_to_fs_valid (ps_to_fs_valid ),//i
    .ps_to_fs_bus   (ps_to_fs_bus   ),//i
    //to ds
    .fs_to_ds_valid (fs_to_ds_valid ),//o
    .fs_to_ds_bus   (fs_to_ds_bus   ),//o
    // ex
    .ws_ex          (ws_ex          ),
    .ws_mret        (ws_mret        ),
    // inst sram interface
    .inst_sram_rdata(irom_data)//i,32
);

// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //branch stall
    .br_stall       (br_stall       ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //from csr
    .csr_addr       (csr_raddr      ),
    .csr_rdata      (csr_rdata      ),
    // ex
    .ws_ex          (ws_ex          ),
    .ws_mret        (ws_mret        ),
    // forward & block
    .es_fwd_blk_bus (es_fwd_blk_bus ),
    .ms_fwd_blk_bus (ms_fwd_blk_bus ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // ex
    .ws_ex          (ws_ex          ),
    .ws_mret        (ws_mret        ),
    // forward & block
    .es_fwd_blk_bus (es_fwd_blk_bus ),
    // data sram interface
    .data_sram_wen   (perip_wen   ),
    .data_sram_mask  (perip_mask  ),
    .data_sram_addr (perip_addr ),
    .data_sram_wdata(perip_wdata)
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    // ex
    .ws_ex          (ws_ex          ),
    .ws_mret        (ws_mret        ),
    // forward & block
    .ms_fwd_blk_bus (ms_fwd_blk_bus),
    //from data-sram
    .data_sram_rdata(perip_rdata)
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    // ex
    .ws_ex          (ws_ex          ),
    .ws_mret        (ws_mret        ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //to csr
    .ws_to_csr_bus  (ws_to_csr_bus  ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule

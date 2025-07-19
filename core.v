`ifndef CPU_CORE_H
    `define CPU_CORE_H
    `define RESET_ADDR          32'h8000_0000

    `define BR_BUS_WD           33
`define WS_TO_CSR_BUS_WD    145  

    `define PS_TO_FS_BUS_WD     129  
    `define FS_TO_DS_BUS_WD     161  
    `define DS_TO_ES_BUS_WD     344 
    `define ES_TO_MS_BUS_WD     320 
    `define MS_TO_WS_BUS_WD     251  
    `define WS_TO_RF_BUS_WD     41
    `define ES_FWD_BLK_BUS_WD   42
    `define MS_FWD_BLK_BUS_WD   42
    `define MS_FWD_ES_BUS_WD    66
    `define WS_TO_MS_BYPASS_WD  33

    `define EX_IAM              32'h00 // Instruction address misaligned
    `define EX_IAF              32'h01 // Instruction access fault
    `define EX_IILL             32'h02 // Illegal instruction
    `define EX_BP               32'h03 // Breakpoint
    `define EX_LAM              32'h04 // Load address misaligned
    `define EX_LAF              32'h05 // load access fault
    `define EX_SAM              32'h06 // Store/AMO address misaligned
    `define EX_SAF              32'h07 // Store/AMO access fault
    `define EX_EUM              32'h08 // Environment call from U-mode
    `define EX_ESM              32'h09 // Environment call from S-mode
    `define EX_NOP              32'h0A // Reserved
    `define EX_EMM              32'h0B // Environment call from M-mode
    `define EX_IPF              32'h0C // Instruction page fault
    `define EX_LPF              32'h0D // Loade page fault
    `define EX_SPF              32'h0F // Store/AMO page fault

    `define EX_ENTRY            32'h_bfc00380

`endif

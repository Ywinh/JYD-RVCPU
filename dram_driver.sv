`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 11:42:01 AM
// Design Name: 
// Module Name: dram_driver
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


module dram_driver(
    input  logic         clk				,

    input  logic [17:0]  perip_addr			,
    input  logic [31:0]  perip_wdata		,
	input  logic [1:0]	 perip_mask			,
    input  logic [3:0]   dram_wen           ,
    output logic [31:0]  perip_rdata		
);
    logic [15:0] dram_addr;
    logic [ 1:0] offset;
    logic [31:0] dram_data, dram_rdata_raw, dout;

    assign dram_addr = perip_addr[17:2];
    assign offset = perip_addr[1:0];
    assign perip_rdata = dout;

    DRAM1 Mem_DRAM  (
        .clka(clk),    // input wire clka
        .wea(dram_wen),      // input wire [3 : 0] wea
        .addra(dram_addr),  // input wire [15 : 0] addra
        .dina(perip_wdata),    // input wire [31 : 0] dina
        .douta(dram_rdata_raw)  // output wire [31 : 0] douta
    );

    // DRAM Mem_DRAM (
    //     .clk        (clk),
    //     .a          (dram_addr),
    //     .spo        (dram_rdata_raw),
    //     .we         (dram_wen),
    //     .d          (dram_data)
    // );

    // dram_rdata_raw process, lh lb
    always_comb begin
        dout = 0;
        case (perip_mask)
            2'b00: // lb/lbu
                case (offset)
                    2'b00:  dout = {24'b0, dram_rdata_raw[7:0]};
                    2'b01:  dout = {24'b0, dram_rdata_raw[15:8]};
                    2'b10:  dout = {24'b0, dram_rdata_raw[23:16]};
                    2'b11:  dout = {24'b0, dram_rdata_raw[31:24]};
                endcase
            2'b01: // lh/lhu
                case (offset[1])
                    1'b0:  dout = {24'b0, dram_rdata_raw[15:0]};
                    1'b1:  dout = {24'b0, dram_rdata_raw[31:16]};
                endcase
            2'b10: dout = dram_rdata_raw;
            default: dout = 0;
        endcase
    end

    // dram_data_raw process, sh, sb
    // always_comb begin
    //     case (perip_mask)
    //         2'b10: dram_data = perip_wdata;  // sw
    //         2'b01: begin           // sh
    //             case (offset[1])
    //                 1'b0: dram_data = {dram_rdata_raw[31:16], perip_wdata[15:0]};
    //                 1'b1: dram_data = {perip_wdata[15:0], dram_rdata_raw[15:0]};
    //             endcase
    //         end
    //         2'b00: begin           // sb
    //             case (offset)
    //                 2'b00: dram_data = {dram_rdata_raw[31:8], perip_wdata[7:0]};
    //                 2'b01: dram_data = {dram_rdata_raw[31:16], perip_wdata[7:0], dram_rdata_raw[7:0]};
    //                 2'b10: dram_data = {dram_rdata_raw[31:24], perip_wdata[7:0], dram_rdata_raw[15:0]};
    //                 2'b11: dram_data = {perip_wdata[7:0], dram_rdata_raw[23:0]};
    //             endcase
    //         end
    //         default: dram_data = perip_wdata;
    //     endcase
    // end

    // assign dram_data = ({32{dram_wen[0]}} & {24'b0, perip_wdata[7:0]})   |
    //                  ({32{dram_wen[1]}} & {16'b0, perip_wdata[15:8], 8'b0}) |
    //                  ({32{dram_wen[2]}} & {8'b0, perip_wdata[23:16], 16'b0}) |
    //                  ({32{dram_wen[3]}} & {perip_wdata[31:24], 24'b0}) |
    //                  // 保留未写入位
    //                  (~{8{dram_wen[3], dram_wen[2], dram_wen[1], dram_wen[0]}} & perip_rdata);

endmodule

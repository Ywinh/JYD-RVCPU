module branch_predict(
    input       [31 : 0]  pc             ,
    input       [31 : 0]  dest_inst      ,
    //input  [ 6 : 0]  opcode         ,
    input                 inst_b_type    ,
    output                fw_or_bw       ,
    output wire [31 : 0]  predict_pc
);

wire [11 : 0] imm;
wire [31 : 0] offset;


assign imm    =   inst_b_type ? {dest_inst[31],dest_inst[7],dest_inst[30:25],dest_inst[11:8]} : 12'b0;
assign offset =   { {20{imm[11]}} , imm , 1'b0 } ;

assign fw_or_bw  =   ~offset[31] ; //1是向前传播(不跳转) 0是向后传播(跳转)

assign predict_pc =   fw_or_bw == 1'b1 ? pc+4 : pc + offset ;

endmodule
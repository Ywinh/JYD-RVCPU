`include "core.v"

module id_stage(
    input                    clk                 ,
    input                    reset               ,
    //allowin
    input                    es_allowin          ,
    output                   ds_allowin          ,
    //to ps: for branch and jump
    output     [`BR_BUS_WD       -1:0]     br_bus              ,
    //to fs: for branch stall
    output                   br_stall            ,
    //from fs
    input                    fs_to_ds_valid      ,
    input      [`FS_TO_DS_BUS_WD -1:0]     fs_to_ds_bus        ,
    //to es
    output                   ds_to_es_valid      ,
    output     [`DS_TO_ES_BUS_WD -1:0]     ds_to_es_bus        ,
    //csr
    output     [  11: 0]     csr_addr            ,
    input      [  31: 0]     csr_rdata           ,
    // ex
    input                    ws_ex               ,
    input                    ws_mret             ,
    // forword & block from es
    input      [`ES_FWD_BLK_BUS_WD -1:0]     es_fwd_blk_bus      ,
    // forword & block from ms
    input      [`MS_FWD_BLK_BUS_WD -1:0]     ms_fwd_blk_bus      ,
    //to rf: for write back
    input      [`WS_TO_RF_BUS_WD -1:0]       ws_to_rf_bus        
                );
//-------------------------------------------------------------
// pipeline
//-------------------------------------------------------------
// from fs
wire    [  31: 0]     fs_epc             ;
wire    [  31: 0]     fs_excode          ;
wire                  fs_ex              ;
wire    [  31: 0]     ds_inst            ;
wire    [  31: 0]     ds_pc              ;
wire    [  31: 0]     ds_einst           ;
wire    [  31: 0]     ds_epc             ;
wire    [  31: 0]     ds_excode          ;
wire                  ds_ex              ;

wire    [  31: 0]     csr_wdata          ;
wire                  csr_op             ;

wire                  inst_jl            ;
wire                  inst_ebreak        ;
wire                  inst_ecall         ;
wire                  inst_mret          ;
wire                  inst_lw            ;
wire                  inst_lh            ;
wire                  inst_lhu           ;
wire                  inst_lb            ;
wire                  inst_lbu           ;
wire                  inst_sw            ;
wire                  inst_sh            ;
wire                  inst_sb            ;

wire                  rs1_is_4           ;
wire                  rs1_is_imm_u       ;
wire                  rs2_is_zero        ;
wire                  rs2_is_imm         ;
wire                  rs2_is_shamt       ;
wire                  rs2_is_pc          ;

wire    [  19: 0]     imm_u              ;
wire    [   9: 0]     alu_op             ;
wire                  res_from_mem       ;
wire                  gpr_we             ;
wire                  mem_we             ;
wire    [   4: 0]     dest               ;
wire    [   4: 0]     shamt              ;
wire    [  11: 0]     imm                ;
wire    [  31: 0]     rs1_value          ;
wire    [  31: 0]     rs2_value          ;
     
reg     [`FS_TO_DS_BUS_WD -1:0]     fs_to_ds_bus_r     ;

wire                 fw_or_bw       ;
wire                 predict_taken  ;
assign {
    fw_or_bw,
    fs_epc,                                                         //128:97
    fs_excode,                                                      //96:65
    fs_ex   ,                                                       //64:64
    ds_inst,
    ds_pc
}               = fs_to_ds_bus_r;

// to es
assign ds_to_es_bus                 = {
    ds_einst     ,                                                  //342:311
    inst_ebreak  ,                                                  //310:310
    inst_ecall   ,                                                  //309:309
    inst_jl      ,                                                  //308:308
    ds_epc       ,                                                  //307:276
    ds_excode    ,                                                  //275:244
    ds_ex        ,                                                  //243:243
    inst_mret    ,                                                  //242:242
    csr_addr     ,                                                  //241:230
    csr_rdata    ,                                                  //229:198
    csr_wdata    ,                                                  //197:166
    inst_lw      ,                                                  //165:165
    inst_lh      ,                                                  //164:164
    inst_lhu     ,                                                  //163:163
    inst_lb      ,                                                  //162:162
    inst_lbu     ,                                                  //161:161
    inst_sw      ,                                                  //160:160
    inst_sh      ,                                                  //159:159
    inst_sb      ,                                                  //158:158
    rs1_is_4     ,                                                  //157:157
    rs2_is_zero  ,                                                  //156:156
    imm_u        ,                                                  //155:136
    alu_op       ,                                                  //135:126
    csr_op       ,                                                  //125:125
    rs1_is_imm_u ,                                                  //124:124
    rs2_is_imm   ,                                                  //123:123
    rs2_is_shamt ,                                                  //122:122
    rs2_is_pc    ,                                                  //121:121
    res_from_mem ,                                                  //120:120
    gpr_we       ,                                                  //119:119
    mem_we       ,                                                  //118:118
    shamt        ,                                                  //117:113
    dest         ,                                                  //112:108
    imm          ,                                                  //107:96
    rs1_value    ,                                                  //95 :64
    rs2_value    ,                                                  //63 :32
    ds_pc                                                           //31 :0
};

// ds reg
reg                   ds_valid           ;
wire                  ds_ready_go        ;
wire                  es_blk_valid       ;

wire    [   4: 0]     rs1                ;
wire    [   4: 0]     rs2                ;
wire    [   4: 0]     es_rf_dest         ;

assign ds_ready_go      = !(es_blk_valid && (rs1 == es_rf_dest || rs2 == es_rf_dest));
assign ds_allowin       = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid   = ds_valid && ds_ready_go && !ws_mret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

//-------------------------------------------------------------
// inst decode
//-------------------------------------------------------------
//data flow
// wire    [   4: 0]     dest               ;
// wire    [   4: 0]     shamt              ;
// wire    [   4: 0]     rs1                ;
// wire    [   4: 0]     rs2                ;
wire    [   6: 0]     opcode             ;
wire    [   2: 0]     funct3             ;
wire    [   6: 0]     funct7             ;
wire    [ 127: 0]     opcode_d           ;
wire    [ 127: 0]     funct7_d           ;
wire    [   7: 0]     funct3_d           ;
//wire    [  11: 0]     csr_addr           ;
// wire    [  19: 0]     imm_u              ;
wire    [  11: 0]     imm_i              ;
wire    [  11: 0]     imm_s              ;
wire    [  11: 0]     imm_b              ;
wire    [  19: 0]     imm_j              ;
wire    [   4: 0]     zimm               ;

wire    [   4: 0]     rf_raddr1          ;
wire    [   4: 0]     rf_raddr2          ;
wire    [  31: 0]     rf_rdata1          ;
wire    [  31: 0]     rf_rdata2          ;
// wire    [  31: 0]     rs1_value          ;
// wire    [  31: 0]     rs2_value          ;

assign dest             = ds_inst[11: 7];
assign shamt            = ds_inst[24:20];
assign rs1              = ds_inst[19:15];
assign rs2              = ds_inst[24:20];
assign opcode           = ds_inst[ 6: 0];
assign funct3           = ds_inst[14:12];
assign funct7           = ds_inst[31:25];
assign csr_addr         = ds_inst[31:20];
assign imm_u            = ds_inst[31:12];
assign imm_i            = ds_inst[31:20];
assign imm_s            = {ds_inst[31:25],ds_inst[11:7]};
assign imm_b            = {ds_inst[31:31],ds_inst[7:7],ds_inst[30:25],ds_inst[11:8]};
assign imm_j            = {ds_inst[31],ds_inst[19:12],ds_inst[20],ds_inst[30:21]};
assign zimm             = ds_inst[19:15];

// arithmetic inst
wire                  inst_add           ;
wire                  inst_addi          ;
wire                  inst_sub           ;
wire                  inst_slt           ;
wire                  inst_slti          ;
wire                  inst_sltu          ;
wire                  inst_sltiu         ;

// logic inst
wire                  inst_and           ;
wire                  inst_andi          ;
wire                  inst_or            ;
wire                  inst_ori           ;
wire                  inst_xor           ;
wire                  inst_xori          ;

// shift inst
wire                  inst_sll           ;
wire                  inst_slli          ;
wire                  inst_srl           ;
wire                  inst_srli          ;
wire                  inst_sra           ;
wire                  inst_srai          ;
wire                  inst_auipc         ;
wire                  inst_lui           ;

// branch & jump inst
wire                  inst_jal           ;
wire                  inst_jalr          ;
wire                  inst_beq           ;
wire                  inst_bne           ;
wire                  inst_blt           ;
wire                  inst_bltu          ;
wire                  inst_bge           ;
wire                  inst_bgeu          ;

// memory inst
// wire                  inst_lw            ;
// wire                  inst_lh            ;
// wire                  inst_lhu           ;
// wire                  inst_lb            ;
// wire                  inst_lbu           ;
// wire                  inst_sw            ;
// wire                  inst_sh            ;
// wire                  inst_sb            ;

// csr inst
wire                  inst_csrrw         ;
wire                  inst_csrrs         ;
wire                  inst_csrrc         ;
wire                  inst_csrrwi        ;
wire                  inst_csrrsi        ;
wire                  inst_csrrci        ;

// fence inst
wire                  inst_fence         ;
wire                  inst_fence_i       ;

// other inst
// wire                  inst_ecall         ;
// wire                  inst_ebreak        ;
// wire                  inst_mret          ;
wire                  inst_wfi           ;

// control signal
wire                  inst_i_type        ;
wire                  inst_s_type        ;
wire                  inst_b_type        ;
// wire                  rs1_is_4           ;
// wire                  rs1_is_imm_u       ;
// wire                  rs2_is_zero        ;
// wire                  rs2_is_imm         ;
// wire                  rs2_is_shamt       ;
// wire                  rs2_is_pc          ;
// wire                  res_from_mem       ;
// wire                  gpr_we             ;
// wire                  mem_we             ;
// wire                  csr_op             ;
// wire    [  11: 0]     imm                ;
// wire    [   9: 0]     alu_op             ;

// decoder
decoder_7_128 u_dec0(.in(opcode                 ), .out(opcode_d  ));
decoder_7_128 u_dec1(.in(funct7                 ), .out(funct7_d  ));
decoder_3_8   u_dec2(.in(funct3                 ), .out(funct3_d  ));

// arithmetic inst
assign inst_add         = opcode_d[7'h33] & funct3_d[3'h0] & funct7_d[7'h00];
assign inst_addi        = opcode_d[7'h13] & funct3_d[3'h0];
assign inst_sub         = opcode_d[7'h33] & funct3_d[3'h0] & funct7_d[7'h20];
assign inst_slt         = opcode_d[7'h33] & funct3_d[3'h2] & funct7_d[7'h00];
assign inst_slti        = opcode_d[7'h13] & funct3_d[3'h2];
assign inst_sltu        = opcode_d[7'h33] & funct3_d[3'h3] & funct7_d[7'h00];
assign inst_sltiu       = opcode_d[7'h13] & funct3_d[3'h3];

// logic inst
assign inst_and         = opcode_d[7'h33] & funct3_d[3'h7] & funct7_d[7'h00];
assign inst_andi        = opcode_d[7'h13] & funct3_d[3'h7];
assign inst_or          = opcode_d[7'h33] & funct3_d[3'h6] & funct7_d[7'h00];
assign inst_ori         = opcode_d[7'h13] & funct3_d[3'h6];
assign inst_xor         = opcode_d[7'h33] & funct3_d[3'h4] & funct7_d[7'h00];
assign inst_xori        = opcode_d[7'h13] & funct3_d[3'h4];

// shift inst
assign inst_sll         = opcode_d[7'h33] & funct3_d[3'h1] & funct7_d[7'h00];
assign inst_slli        = opcode_d[7'h13] & funct3_d[3'h1] & funct7_d[7'h00];
assign inst_srl         = opcode_d[7'h33] & funct3_d[3'h5] & funct7_d[7'h00];
assign inst_srli        = opcode_d[7'h13] & funct3_d[3'h5] & funct7_d[7'h00];
assign inst_sra         = opcode_d[7'h33] & funct3_d[3'h5] & funct7_d[7'h20];
assign inst_srai        = opcode_d[7'h13] & funct3_d[3'h5] & funct7_d[7'h20];
assign inst_auipc       = opcode_d[7'h17];
assign inst_lui        = opcode_d[7'h37];

// branch & jump inst
assign inst_jal         = opcode_d[7'h6f];
assign inst_jalr        = opcode_d[7'h67] & funct3_d[3'h0];
assign inst_beq         = opcode_d[7'h63] & funct3_d[3'h0];
assign inst_bne         = opcode_d[7'h63] & funct3_d[3'h1];
assign inst_blt         = opcode_d[7'h63] & funct3_d[3'h4];
assign inst_bltu        = opcode_d[7'h63] & funct3_d[3'h6];
assign inst_bge         = opcode_d[7'h63] & funct3_d[3'h5];
assign inst_bgeu        = opcode_d[7'h63] & funct3_d[3'h7];

// memory inst
assign inst_lw          = opcode_d[7'h03] & funct3_d[3'h2];
assign inst_lh          = opcode_d[7'h03] & funct3_d[3'h1];
assign inst_lhu         = opcode_d[7'h03] & funct3_d[3'h5];
assign inst_lb          = opcode_d[7'h03] & funct3_d[3'h0];
assign inst_lbu         = opcode_d[7'h03] & funct3_d[3'h4];
assign inst_sw          = opcode_d[7'h23] & funct3_d[3'h2];
assign inst_sh          = opcode_d[7'h23] & funct3_d[3'h1];
assign inst_sb          = opcode_d[7'h23] & funct3_d[3'h0];

// csr inst
assign inst_csrrw       = opcode_d[7'h73] & funct3_d[3'h1];
assign inst_csrrs       = opcode_d[7'h73] & funct3_d[3'h2];
assign inst_csrrc       = opcode_d[7'h73] & funct3_d[3'h3];
assign inst_csrrwi      = opcode_d[7'h73] & funct3_d[3'h5];
assign inst_csrrsi      = opcode_d[7'h73] & funct3_d[3'h6];
assign inst_csrrci      = opcode_d[7'h73] & funct3_d[3'h7];

// fence inst
//assign inst_fence = ;   TODO
assign inst_fence_i     = (ds_inst == 32'h0000000f);

// other inst
assign inst_ecall       = (ds_inst == 32'h00000073);
assign inst_ebreak      = (ds_inst == 32'h00100073);
assign inst_mret        = (ds_inst == 32'h30200073);
assign inst_wfi         = (ds_inst == 32'h10500073);

assign inst_jl          = inst_jal | inst_jalr;
assign inst_i_type      = inst_lb | inst_lh | inst_lw | inst_lbu | inst_lhu | inst_addi | 
                          inst_slti | inst_sltiu | inst_xori | inst_ori | inst_andi | inst_jalr;
assign inst_s_type      = inst_sb | inst_sh | inst_sw;
assign inst_b_type      = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign rs1_is_4         = inst_jal | inst_jalr;
assign rs1_is_imm_u     = inst_lui | inst_auipc;
assign rs2_is_imm       = inst_addi | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori |
                          inst_lw | inst_lh | inst_lhu | inst_lb | inst_lbu | inst_sw | inst_sh |
                          inst_sb;
assign rs2_is_zero      = inst_lui;
assign rs2_is_shamt     = inst_slli | inst_srli | inst_srai;
assign rs2_is_pc        = inst_auipc | inst_jal | inst_jalr;
assign res_from_mem     = inst_lw | inst_lh | inst_lhu | inst_lb | inst_lbu;
assign gpr_we           = ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bltu & ~inst_bge & ~inst_bgeu &
                          ~inst_sw & ~inst_sh & ~inst_sb;
assign mem_we           = inst_sw | inst_sh | inst_sb;
assign csr_op           = inst_csrrw | inst_csrrs | inst_csrrc | inst_csrrwi | inst_csrrsi | inst_csrrci;
assign imm              = ({12{inst_i_type}} & imm_i) |
                          ({12{inst_s_type}} & imm_s) |
                          ({12{inst_b_type}} & imm_b);
assign alu_op[0]        = inst_add | inst_addi | inst_lui | inst_auipc | inst_lw |
                          inst_lh | inst_lhu | inst_lb | inst_lbu | inst_sw | inst_sh |
                          inst_sb; // Addition operation
assign alu_op[1]        = inst_sub;             // Subtraction operation
assign alu_op[2]        = inst_slt | inst_slti ;// Signed less-than comparison, sets if less
assign alu_op[3]        = inst_sltiu | inst_sltu;           // Unsigned less-than comparison, sets if less
assign alu_op[4]        = inst_and | inst_andi;             // Bitwise AND
assign alu_op[5]        = inst_or | inst_ori;   // Bitwise OR
assign alu_op[6]        = inst_xor | inst_xori; // Bitwise XOR
assign alu_op[7]        = inst_sll | inst_slli; // Logical shift left
assign alu_op[8]        = inst_srl | inst_srli; // Logical shift right
assign alu_op[9]        = inst_sra | inst_srai; // Arithmetic shift right

//-------------------------------------------------------------
// forward & block
//-------------------------------------------------------------
wire    [   3: 0]     es_fwd_valid       ;
// wire    [   4: 0]     es_rf_dest         ;
wire    [  31: 0]     es_rf_data         ;
// wire                  es_blk_valid       ;

assign {
    es_fwd_valid,   // 41:38
    es_rf_dest,     // 37:33
    es_rf_data,     // 32:1
    es_blk_valid    // 0:0
} = es_fwd_blk_bus;

wire    [ 3: 0]     ms_fwd_valid       ;
wire    [ 4: 0]     ms_rf_dest         ;
wire    [31: 0]     ms_rf_data         ;
assign {
    ms_fwd_valid,   // 40:37
    ms_rf_dest,     // 36:32
    ms_rf_data      // 31:0
} = ms_fwd_blk_bus;

// from ws : for write back
wire    [   3: 0]     rf_we              ;
wire    [   4: 0]     rf_waddr           ;
wire    [  31: 0]     rf_wdata           ;
assign {
    rf_we   ,                                                       //40:37
    rf_waddr,                                                       //36:32
    rf_wdata                                                        //31:0
}               = ws_to_rf_bus;

assign rs1_value        = 
    ((es_fwd_valid == 4'b1111) && (es_rf_dest == rs1) && (rs1 != 5'b0)) ? es_rf_data :
    ((ms_fwd_valid == 4'b1111) && (ms_rf_dest == rs1) && (rs1 != 5'b0)) ? ms_rf_data :
    ((rf_we == 4'b1111) && (rf_waddr  == rs1) && (rs1 != 5'b0)) ? rf_wdata :rf_rdata1;

assign rs2_value        = 
    ((es_fwd_valid == 4'b1111) && (es_rf_dest == rs2) && (rs2 != 5'b0)) ? es_rf_data :
    ((ms_fwd_valid == 4'b1111) && (ms_rf_dest == rs2) && (rs2 != 5'b0)) ? ms_rf_data :
    ((rf_we == 4'b1111) && (rf_waddr  == rs2) && (rs2 != 5'b0)) ? rf_wdata :rf_rdata2;

//-------------------------------------------------------------
// branch and jump
//-------------------------------------------------------------
wire                  beq_judge          ;
wire                  blt_judge          ;
wire                  bltu_judge         ;
wire    [  31: 0]     br_b_target        ;
wire    [  31: 0]     br_j_target        ;
wire    [  31: 0]     jalr_target        ;

assign beq_judge        = (rs1_value == rs2_value);
assign blt_judge        = ($signed(rs1_value) < $signed(rs2_value));
assign bltu_judge       = (rs1_value < rs2_value);

wire                  actual_taken       ;
wire                  mispredict         ;
wire                  ds_br_taken        ;
wire    [  31: 0]     ds_br_target       ;
//wire                  flush_target       ;

assign predict_taken = ~ fw_or_bw        ;
assign actual_taken  = (
    (inst_beq  & beq_judge)   |
    (inst_bne  & !beq_judge)  |
    (inst_blt  & blt_judge)   |
    (inst_bltu & bltu_judge)  |
    (inst_bge  & !blt_judge)  |
    (inst_bgeu & !bltu_judge) 
);
assign mispredict = (actual_taken != predict_taken);

assign br_stall = ds_br_taken && ds_ready_go;
//assign flush = mispredict;
//assign flush_target = correct_pc;

assign ds_br_taken      = (
 //   (inst_beq  & beq_judge)   |
 //   (inst_bne  & !beq_judge)  |
 //   (inst_blt  & blt_judge)   |
 //   (inst_bltu & bltu_judge)  |
 //   (inst_bge  & !blt_judge)  |
 //   (inst_bgeu & !bltu_judge) |
    mispredict                | 
    inst_jal                  |
    inst_jalr
) & ds_valid;

//reg            mispredict_valid_r;
//reg  [ 31 : 0] correct_pc_r;
//wire           mispredict_valid;
wire [ 31 : 0] correct_pc;

/*always @(*)
{
    if(reset) begin
        mispredict_valid    = 1'b0;
        correct_pc          =32'b0;
    end else if (mispredict) begin
        mispredict_valid    = 1'b1;
        correct_pc          = br_b_target;
    end else begin
        mispredict_valid    = 1'b0;
}*/

//assign mispredict_valid = (mispredict == 1'b1) ? 1'b1 : 1'b0;
assign correct_pc       = (actual_taken) ? br_b_target : (ds_pc+4);

assign br_b_target = $signed({imm_b, 1'b0}) + $signed(ds_pc);
assign br_j_target = $signed({imm_j, 1'b0}) + $signed(ds_pc);
assign jalr_target = (($signed({{20{imm_i[11]}}, imm_i}) + $signed(rs1_value)) & ~'h1);

assign ds_br_target     = //(inst_beq | inst_bne | inst_blt | inst_bltu | 
                          //inst_bge | inst_bgeu) ? br_b_target :
                          mispredict ? correct_pc  :
                          inst_jal   ? br_j_target :
                          inst_jalr  ? jalr_target :
                          ds_pc;              
 


 assign br_bus = {
    ds_br_taken,
    ds_br_target
};
//-------------------------------------------------------------
// regfile
//-------------------------------------------------------------

assign rf_raddr1        = rs1;
assign rf_raddr2        = rs2;

regfile u_regfile(
    .clk                   (clk                       ),
    .raddr1                (rf_raddr1                 ),
    .rdata1                (rf_rdata1                 ),
    .raddr2                (rf_raddr2                 ),
    .rdata2                (rf_rdata2                 ),
    .we                    (rf_we                     ),
    .waddr                 (rf_waddr                  ),
    .wdata                 (rf_wdata                  ) 
                    );

//-------------------------------------------------------------
// csr
//-------------------------------------------------------------
// wire    [  31: 0]     csr_wdata          ;

assign csr_wdata        = inst_csrrw  ? rs1_value                  :
                          inst_csrrs  ? (csr_rdata | rs1_value)    :
                          inst_csrrc  ? (csr_rdata & ~rs1_value)   :
                          inst_csrrwi ? {27'b0,zimm}               :
                          inst_csrrsi ? (csr_rdata | {27'b0,zimm}) :
                        /*inst_csrrci*/ (csr_rdata & ~{27'b0,zimm});

//-------------------------------------------------------------
// exception
//-------------------------------------------------------------
wire                  ileg_inst          ;
// assign ileg_inst = ~(inst_add | inst_addi | inst_sub | inst_slt | inst_sltu |
//                      inst_sltiu | inst_slti | inst_and | inst_andi | inst_or |
//                      inst_ori | inst_xor | inst_xori | inst_sll | inst_slli |
//                      inst_srl | inst_srli | inst_sra | inst_srai | inst_auipc | 
//                      inst_lui | inst_jal | inst_jalr | inst_beq | inst_bne | 
//                      inst_blt | inst_bltu | inst_bge | inst_bgeu | inst_lw |
//                      inst_lh | inst_lhu | inst_lb | inst_lbu | inst_sw | inst_sh |
//                      inst_sb | inst_csrrw | inst_csrrwi | inst_csrrs | inst_csrrsi |
//                      inst_csrrc | inst_csrrci | inst_fence | inst_fence_i | 
//                      inst_ecall | inst_ebreak | inst_mret | inst_wfi);
assign ileg_inst        = 1'b0;

// wire                  ds_ex              ;
// wire    [  31: 0]     ds_excode          ;
// wire    [  31: 0]     ds_epc             ;

assign ds_ex            = (ileg_inst | inst_ecall | inst_ebreak | inst_wfi |
                           inst_mret | fs_ex) && ds_valid;
assign ds_excode        = ileg_inst  ? `EX_IILL :
                          inst_ecall ? `EX_EMM :
                          inst_ebreak? `EX_BP :
                          fs_excode; // TODO : wfi
//tip : actually ds_epc always same as ds_pc
assign ds_epc           = (inst_ecall | inst_ebreak) ? ds_pc : fs_epc;
assign ds_einst         = ds_inst;

endmodule

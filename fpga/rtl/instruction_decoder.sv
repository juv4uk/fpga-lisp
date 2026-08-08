`include "lisp_word.sv"

typedef enum logic [3:0] {
    OP_NOP   = 4'd0,
    OP_LOADI = 4'd1,
    OP_MOV   = 4'd2,
    OP_CONS  = 4'd3,
    OP_CAR   = 4'd4,
    OP_CDR   = 4'd5,
    OP_ATOM  = 4'd6,
    OP_EQ    = 4'd7,
    OP_JMP   = 4'd8,
    OP_JT    = 4'd9,
    OP_JF    = 4'd10,
    OP_HALT  = 4'd11,
    OP_OUT   = 4'd12,
    OP_ADD   = 4'd13,
    OP_SUB   = 4'd14,
    OP_IN    = 4'd15
} opcode_t;

module instruction_decoder (
    input  logic [31:0]  instruction,
    output opcode_t      opcode,
    output logic [3:0]   rd,
    output logic [3:0]   rs1,
    output logic [3:0]   rs2,
    output logic [15:0]  imm
);

    // Very simple encoding:
    // [31:28] Opcode
    // [27:24] rd
    // [23:20] rs1
    // [19:16] rs2
    // [15:0]  imm

    assign opcode = opcode_t'(instruction[31:28]);
    assign rd     = instruction[27:24];
    assign rs1    = instruction[23:20];
    assign rs2    = instruction[19:16];
    assign imm    = instruction[15:0];

endmodule

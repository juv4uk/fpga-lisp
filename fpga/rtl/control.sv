`include "lisp_word.sv"

module control (
    input  logic         clk,
    input  logic         rst_n,
    
    // Instruction memory (ROM for now)
    output logic [7:0]   imem_addr,
    input  logic [31:0]  imem_data,
    
    // Register file interface
    output logic [3:0]   reg_rd_addr_a,
    output logic [3:0]   reg_rd_addr_b,
    input  lisp_word_t   reg_rd_data_a,
    input  lisp_word_t   reg_rd_data_b,
    output logic         reg_we,
    output logic [3:0]   reg_wr_addr,
    output lisp_word_t   reg_wr_data,
    
    // Lisp Data Unit interface
    output logic         ldu_cmd_cons,
    output logic         ldu_cmd_car,
    output logic         ldu_cmd_cdr,
    input  lisp_word_t   ldu_result,
    input  logic         ldu_valid,
    input  logic         ldu_error,
    
    // UART TX interface
    output logic [7:0]   out_data,
    output logic         out_valid,
    input  logic         out_busy,
    
    // UART RX interface
    input  logic [7:0]   in_data,
    input  logic         in_valid,
    output logic         in_ack,
    
    output logic         halted
);

    typedef enum logic [3:0] {
        ST_FETCH,
        ST_DECODE,
        ST_EXECUTE,
        ST_WAIT_LDU,
        ST_OUT_START,
        ST_OUT_WAIT,
        ST_IN_WAIT,
        ST_HALT
    } state_t;
    
    state_t state, next_state;
    
    logic [7:0] pc;
    logic [31:0] instruction;
    
    opcode_t opcode;
    logic [3:0] rd, rs1, rs2;
    logic [15:0] imm;
    
    instruction_decoder dec (
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm(imm)
    );
    
    assign imem_addr = pc;
    assign reg_rd_addr_a = rs1;
    assign reg_rd_addr_b = rs2;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_FETCH;
            pc <= 0;
            instruction <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                ST_FETCH: begin
                    instruction <= imem_data;
                end
                ST_EXECUTE: begin
                    if (opcode == OP_JMP) begin
                        pc <= imm[7:0];
                    end else if (opcode == OP_JF) begin
                        if (reg_rd_data_a.tag == TAG_NIL || (reg_rd_data_a.tag == TAG_FIXNUM && reg_rd_data_a.value == 0)) begin
                            pc <= imm[7:0];
                        end else begin
                            pc <= pc + 1;
                        end
                    end else if (!ldu_cmd_cons && !ldu_cmd_car && !ldu_cmd_cdr && opcode != OP_HALT && opcode != OP_OUT && opcode != OP_IN) begin
                        pc <= pc + 1;
                    end
                end
                ST_WAIT_LDU: begin
                    if (ldu_valid) begin
                        pc <= pc + 1;
                    end
                end
                ST_OUT_WAIT: begin
                    if (!out_busy) begin
                        pc <= pc + 1;
                    end
                end
                ST_IN_WAIT: begin
                    if (in_valid) begin
                        pc <= pc + 1;
                    end
                end
            endcase
        end
    end
    
    always_comb begin
        next_state = state;
        reg_we = 0;
        reg_wr_addr = rd;
        reg_wr_data = '0;
        
        ldu_cmd_cons = 0;
        ldu_cmd_car = 0;
        ldu_cmd_cdr = 0;
        
        halted = 0;
        out_valid = 0;
        out_data = 8'd0;
        in_ack = 0;
        
        case (state)
            ST_FETCH: begin
                next_state = ST_DECODE;
            end
            ST_DECODE: begin
                next_state = ST_EXECUTE;
            end
            ST_EXECUTE: begin
                case (opcode)
                    OP_NOP: begin
                        next_state = ST_FETCH;
                    end
                    OP_LOADI: begin // Load immediate as FIXNUM
                        reg_we = 1;
                        reg_wr_data.tag = TAG_FIXNUM;
                        reg_wr_data.value = {12'd0, imm};
                        next_state = ST_FETCH;
                    end
                    OP_LOADSYM: begin // Load immediate as SYMBOL
                        reg_we = 1;
                        reg_wr_data.tag = TAG_SYMBOL;
                        reg_wr_data.value = {12'd0, imm};
                        next_state = ST_FETCH;
                    end
                    OP_MOV: begin
                        reg_we = 1;
                        reg_wr_data = reg_rd_data_a;
                        next_state = ST_FETCH;
                    end
                    OP_CONS: begin
                        ldu_cmd_cons = 1;
                        next_state = ST_WAIT_LDU;
                    end
                    OP_CAR: begin
                        ldu_cmd_car = 1;
                        next_state = ST_WAIT_LDU;
                    end
                    OP_CDR: begin
                        ldu_cmd_cdr = 1;
                        next_state = ST_WAIT_LDU;
                    end
                    OP_OUT: begin
                        next_state = ST_OUT_START;
                    end
                    OP_IN: begin
                        next_state = ST_IN_WAIT;
                    end
                    OP_ADD: begin
                        reg_we = 1;
                        reg_wr_data.tag = TAG_FIXNUM;
                        reg_wr_data.value = reg_rd_data_a.value + reg_rd_data_b.value;
                        next_state = ST_FETCH;
                    end
                    OP_SUB: begin
                        reg_we = 1;
                        reg_wr_data.tag = TAG_FIXNUM;
                        reg_wr_data.value = reg_rd_data_a.value - reg_rd_data_b.value;
                        next_state = ST_FETCH;
                    end
                    OP_EQ: begin
                        reg_we = 1;
                        if (reg_rd_data_a == reg_rd_data_b) begin
                            reg_wr_data.tag = TAG_TRUE;
                            reg_wr_data.value = 28'd1;
                        end else begin
                            reg_wr_data.tag = TAG_NIL;
                            reg_wr_data.value = 28'd0;
                        end
                        next_state = ST_FETCH;
                    end
                    OP_JMP: begin
                        next_state = ST_FETCH;
                    end
                    OP_JF: begin
                        next_state = ST_FETCH;
                    end
                    OP_HALT: begin
                        next_state = ST_HALT;
                    end
                    default: next_state = ST_FETCH;
                endcase
            end
            ST_OUT_START: begin
                out_valid = 1;
                out_data = reg_rd_data_a.value[7:0];
                next_state = ST_OUT_WAIT;
            end
            ST_OUT_WAIT: begin
                if (!out_busy) begin
                    next_state = ST_FETCH;
                end
            end
            ST_IN_WAIT: begin
                if (in_valid) begin
                    reg_we = 1;
                    reg_wr_data.tag = TAG_FIXNUM;
                    reg_wr_data.value = {20'd0, in_data};
                    in_ack = 1;
                    next_state = ST_FETCH;
                end
            end
            ST_WAIT_LDU: begin
                if (ldu_valid) begin
                    reg_we = 1;
                    reg_wr_data = ldu_result;
                    next_state = ST_FETCH;
                end
            end
            ST_HALT: begin
                halted = 1;
            end
        endcase
    end

endmodule

`include "lisp_word.sv"

module control (
    input  logic         clk,
    input  logic         rst_n,
    
    // Instruction memory (ROM for now)
    output logic [11:0]  imem_addr,
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
    output logic         ldu_cmd_setcdr,
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

    // Debug/monitor: raw heap peek (active only after HALT)
    output logic         mon_peek_cmd,
    output logic [11:0]  mon_peek_addr,
    input  lisp_word_t   mon_peek_car,
    input  lisp_word_t   mon_peek_cdr,
    input  logic         mon_peek_valid,

    // Debug/monitor: current heap pointer, zero-extended to 16 bits
    input  logic [15:0]  hp_in,

    output logic         halted
);

    // Post-HALT diagnostic monitor protocol (binary, one command at a time):
    //   0x01 <reg>        -> replies with the 4-byte register word (LE)
    //   0x02 <lo> <hi>    -> replies with CAR (4B LE) then CDR (4B LE) at heap[addr]
    //   0x03              -> replies with the 4-byte heap pointer (LE)
    //   0x04              -> replies with {19'd0, err_flag, err_pc} (LE): a
    //                        CAR/CDR/CONS type error (e.g. CAR of a non-CONS)
    //                        halts the machine like HALT rather than hanging
    //                        forever in ST_WAIT_LDU; this command tells you
    //                        whether that happened and at which PC.
    // Unknown command bytes are ignored (monitor keeps waiting for the next byte).
    typedef enum logic [4:0] {
        ST_FETCH,
        ST_DECODE,
        ST_EXECUTE,
        ST_WAIT_LDU,
        ST_OUT_START,
        ST_OUT_WAIT,
        ST_IN_WAIT,
        ST_HALT,
        ST_MON_CMD,
        ST_MON_ARG1,
        ST_MON_ARG2,
        ST_MON_HEAP_WAIT,
        ST_MON_REG_SEND,
        ST_MON_HP_SEND,
        ST_MON_ERR_SEND,
        ST_MON_TX_START,
        ST_MON_TX_WAIT
    } state_t;

    state_t state, next_state;

    logic [11:0] pc;
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

    // Monitor scratch registers
    logic [7:0]  mon_cmd;
    logic [7:0]  mon_arg1;
    logic [7:0]  mon_arg2;
    logic [63:0] mon_tx_buf;
    logic [3:0]  mon_tx_remaining;

    // Latched by a CAR/CDR/CONS type error (see ST_WAIT_LDU below), read
    // back via monitor command 0x04 instead of hanging forever.
    logic        err_flag;
    logic [11:0] err_pc;

    assign imem_addr = pc;
    assign reg_rd_addr_a = (state == ST_MON_REG_SEND) ? mon_arg1[3:0] : rs1;
    assign reg_rd_addr_b = rs2;
    assign mon_peek_addr = {mon_arg2[3:0], mon_arg1};
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_FETCH;
            pc <= 0;
            instruction <= 0;
            mon_cmd <= 0;
            mon_arg1 <= 0;
            mon_arg2 <= 0;
            mon_tx_buf <= 0;
            mon_tx_remaining <= 0;
            err_flag <= 0;
            err_pc <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                ST_FETCH: begin
                    instruction <= imem_data;
                end
                ST_EXECUTE: begin
                    if (opcode == OP_JMP) begin
                        // rd=0,rs1=0: plain JMP addr.
                        // rd!=0,rs1=0: CALL rd,addr (reg[rd] <= return addr, jump).
                        // rd=0,rs1!=0: RET rs1 (jump to address held in rs1).
                        if (rs1 != 0) begin
                            pc <= reg_rd_data_a.value[11:0];
                        end else begin
                            pc <= imm[11:0];
                        end
                    end else if (opcode == OP_JF) begin
                        if (reg_rd_data_a.tag == TAG_NIL || (reg_rd_data_a.tag == TAG_FIXNUM && reg_rd_data_a.value == 0)) begin
                            pc <= imm[11:0];
                        end else begin
                            pc <= pc + 1;
                        end
                    end else if (!ldu_cmd_cons && !ldu_cmd_car && !ldu_cmd_cdr && !ldu_cmd_setcdr && opcode != OP_HALT && opcode != OP_OUT && opcode != OP_IN) begin
                        pc <= pc + 1;
                    end
                end
                ST_WAIT_LDU: begin
                    if (ldu_error) begin
                        err_flag <= 1;
                        err_pc <= pc;
                    end else if (ldu_valid) begin
                        pc <= pc + 1;
                    end
                end
                ST_MON_ERR_SEND: begin
                    mon_tx_buf <= {32'd0, 19'd0, err_flag, err_pc};
                    mon_tx_remaining <= 4;
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
                ST_MON_CMD: begin
                    if (in_valid) mon_cmd <= in_data;
                end
                ST_MON_ARG1: begin
                    if (in_valid) mon_arg1 <= in_data;
                end
                ST_MON_ARG2: begin
                    if (in_valid) mon_arg2 <= in_data;
                end
                ST_MON_REG_SEND: begin
                    mon_tx_buf <= {32'd0, reg_rd_data_a};
                    mon_tx_remaining <= 4;
                end
                ST_MON_HP_SEND: begin
                    mon_tx_buf <= {32'd0, 16'd0, hp_in};
                    mon_tx_remaining <= 4;
                end
                ST_MON_HEAP_WAIT: begin
                    if (mon_peek_valid) begin
                        mon_tx_buf <= {mon_peek_cdr, mon_peek_car};
                        mon_tx_remaining <= 8;
                    end
                end
                ST_MON_TX_WAIT: begin
                    if (!out_busy) begin
                        mon_tx_buf <= mon_tx_buf >> 8;
                        mon_tx_remaining <= mon_tx_remaining - 1;
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
        ldu_cmd_setcdr = 0;
        
        halted = 0;
        out_valid = 0;
        out_data = 8'd0;
        in_ack = 0;
        mon_peek_cmd = 0;

        // Machine reports halted from the moment HALT executes through the
        // whole post-halt monitor session (the monitor never resumes ST_FETCH).
        if (state == ST_HALT || state == ST_MON_CMD || state == ST_MON_ARG1 ||
            state == ST_MON_ARG2 || state == ST_MON_HEAP_WAIT ||
            state == ST_MON_REG_SEND || state == ST_MON_HP_SEND ||
            state == ST_MON_ERR_SEND ||
            state == ST_MON_TX_START || state == ST_MON_TX_WAIT) begin
            halted = 1;
        end

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
                        // rs2==1: GETTAG rd,rs1   -- rd = FIXNUM(tag of rs1).
                        // rs2==2: MAKEPRIM rd,rs1 -- rd = PRIMITIVE(value of rs1).
                        // rs2==3: GETVAL rd,rs1   -- rd = FIXNUM(value of rs1).
                        // rs2==0 (the assembler's default): plain MOV rd,rs1.
                        reg_we = 1;
                        case (rs2)
                            4'd1: begin
                                reg_wr_data.tag = TAG_FIXNUM;
                                reg_wr_data.value = {24'd0, reg_rd_data_a.tag};
                            end
                            4'd2: begin
                                reg_wr_data.tag = TAG_PRIMITIVE;
                                reg_wr_data.value = reg_rd_data_a.value;
                            end
                            4'd3: begin
                                reg_wr_data.tag = TAG_FIXNUM;
                                reg_wr_data.value = reg_rd_data_a.value;
                            end
                            default: begin
                                reg_wr_data = reg_rd_data_a;
                            end
                        endcase
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
                    OP_ATOM: begin
                        // rs2==0 (the assembler's default for plain ATOM
                        // rd,rs1): ordinary ATOM check on rs1 into rd.
                        // rs2!=0: SETCDR rd,rs1,rs2 -- an internal,
                        // bootstrap-only capability (never reachable from
                        // eval/apply as an ordinary primitive) that
                        // overwrites an EXISTING cons cell's CDR in place,
                        // needed for letrec-style self-referential
                        // closures (see lisp_data_unit.sv's cmd_setcdr).
                        // rs1 = the cons cell to mutate, rs2 = the new CDR
                        // value, rd = receives the new CDR value back as
                        // confirmation. Same "reuse an unused field as a
                        // mode selector" pattern as OP_MOV's GETTAG/
                        // MAKEPRIM/GETVAL, with the one caveat that rs2
                        // doubles as real data here: rs2 can never be R0
                        // for this instruction (R0 there means "plain
                        // ATOM", the same accepted constraint CALL/RET
                        // already place on rd/rs1 being nonzero).
                        if (rs2 != 0) begin
                            ldu_cmd_setcdr = 1;
                            next_state = ST_WAIT_LDU;
                        end else begin
                            reg_we = 1;
                            if (reg_rd_data_a.tag == TAG_CONS) begin
                                reg_wr_data.tag = TAG_NIL;
                                reg_wr_data.value = 28'd0;
                            end else begin
                                reg_wr_data.tag = TAG_TRUE;
                                reg_wr_data.value = 28'd1;
                            end
                            next_state = ST_FETCH;
                        end
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
                        // CALL form (rd!=0, rs1==0): link register gets the
                        // return address (pc+1) before the jump takes effect.
                        if (rd != 0 && rs1 == 0) begin
                            reg_we = 1;
                            reg_wr_data.tag = TAG_FIXNUM;
                            reg_wr_data.value = {16'd0, pc} + 28'd1;
                        end
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
                if (ldu_error) begin
                    // Unrecoverable type error (e.g. CAR of a non-CONS):
                    // halt like HALT instead of waiting for a ldu_valid
                    // that will never come. Inspect via monitor cmd 0x04.
                    next_state = ST_HALT;
                end else if (ldu_valid) begin
                    reg_we = 1;
                    reg_wr_data = ldu_result;
                    next_state = ST_FETCH;
                end
            end
            ST_HALT: begin
                if (in_valid) begin
                    next_state = ST_MON_CMD;
                end
            end
            ST_MON_CMD: begin
                if (in_valid) begin
                    in_ack = 1;
                    case (in_data)
                        8'h01:   next_state = ST_MON_ARG1; // REG <idx>
                        8'h02:   next_state = ST_MON_ARG1; // HEAP <lo> <hi>
                        8'h03:   next_state = ST_MON_HP_SEND; // HP
                        8'h04:   next_state = ST_MON_ERR_SEND; // ERR
                        default: next_state = ST_MON_CMD; // unknown, ignore
                    endcase
                end
            end
            ST_MON_ARG1: begin
                if (in_valid) begin
                    in_ack = 1;
                    if (mon_cmd == 8'h02) begin
                        next_state = ST_MON_ARG2;
                    end else begin
                        next_state = ST_MON_REG_SEND;
                    end
                end
            end
            ST_MON_ARG2: begin
                if (in_valid) begin
                    in_ack = 1;
                    mon_peek_cmd = 1;
                    next_state = ST_MON_HEAP_WAIT;
                end
            end
            ST_MON_HEAP_WAIT: begin
                if (mon_peek_valid) begin
                    next_state = ST_MON_TX_START;
                end
            end
            ST_MON_REG_SEND: begin
                next_state = ST_MON_TX_START;
            end
            ST_MON_HP_SEND: begin
                next_state = ST_MON_TX_START;
            end
            ST_MON_ERR_SEND: begin
                next_state = ST_MON_TX_START;
            end
            ST_MON_TX_START: begin
                out_valid = 1;
                out_data = mon_tx_buf[7:0];
                next_state = ST_MON_TX_WAIT;
            end
            ST_MON_TX_WAIT: begin
                if (!out_busy) begin
                    if (mon_tx_remaining > 1) begin
                        next_state = ST_MON_TX_START;
                    end else begin
                        next_state = ST_MON_CMD;
                    end
                end
            end
        endcase
    end

endmodule

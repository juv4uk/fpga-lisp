// ============================================================================
// sandhi_engine.sv — Sequential Sūtra-Processor (sandhi rule engine)
// ============================================================================
// Epistemic status: embryo sūtra-processor (Step C, ISA 1.3 sandhi mode)
// Integration: fpga-lisp encoded-mode primitive via MOV rs2=7
// Target: Gowin GW5A-LV25MG121 (Tang Primer 25K)
//
// Semantics: applies one Pāṇinian sandhi rule to a PAIR of UPC-8 sounds.
// Unlike upc8_unit (combinational, single code), this engine is SEQUENTIAL:
// it walks a fixed rule table (ROM constants) rule-by-rule, 3-4 cycles each:
//
//     IDLE ──start──► LOAD_RULE(0) ──► APPLY ──► CHECK_NEXT ──► OUTPUT ──► IDLE
//                           ▲                                   │
//                           └──────────── rule++ (no match) ─────┘
//
// Rule order (owner-confirmed 2026-09-06): SAVARNA→GUNA→YAṆ
//   * SAVARNA-DĪRGHA (6.1.101 akai savarṇe dīrghaḥ):
//       same-row class-10 non-nasal pair -> long vowel of that row
//       a+a, a+ā, ā+a -> ā ; i+i, i+ī -> ī ; u+u, u+ū -> ū
//   * GUNA (6.1.87 ād guṇaḥ):
//       a/ā + i/ī -> e ; a/ā + u/ū -> o
//   * YAṆ (6.1.77 iko yaṇ aci), embryo i/y + u/v:
//       i/ī + vowel -> y + vowel ; u/ū + vowel -> v + vowel
//
// Result modes:
//   2'b00 = passthrough (no rule matched; pair returned unchanged)
//   2'b01 = single output code in result_0
//   2'b10 = two output codes: result_0, result_1 (yaṇ: semivowel + vowel)
//
// Interface via MOV rs2=7:
//   input : rs1.value[15:8] = prev_code, rs1.value[7:0] = curr_code
//   output: rd.value[17:16] = result_mode, [15:8] = result_1, [7:0] = result_0
// ============================================================================

module sandhi_engine (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,        // pulse: begin computation
    input  logic [7:0] code_prev,    // previous sound
    input  logic [7:0] code_curr,    // current sound
    output logic       done,         // pulse: result ready (1 cycle, state OUTPUT)
    output logic [1:0] result_mode,  // 00=passthrough, 01=1 code, 10=2 codes
    output logic [7:0] result_0,     // first output code
    output logic [7:0] result_1,     // second output code (yaṇ)
    output logic       error         // reserved (always 0 in embryo)
);

    // ------------------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------------------
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_LOAD_RULE,
        ST_APPLY,
        ST_CHECK_NEXT,
        ST_OUTPUT
    } state_t;

    state_t state;

    logic [1:0] rule_idx;          // 0..2 (3 rules)
    logic       matched;           // current run already matched a rule
    logic [1:0] m_mode;            // latched result mode
    logic [7:0] m_out0;            // latched result_0
    logic [7:0] m_out1;            // latched result_1

    // Latched input pair (the CPU holds rs1 stable, but latch for safety)
    reg  [7:0] prev_q;
    reg  [7:0] curr_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_q <= 8'h00;
            curr_q <= 8'h00;
        end else if (state == ST_IDLE && start) begin
            prev_q <= code_prev;
            curr_q <= code_curr;
        end
    end

    // ------------------------------------------------------------------------
    // Rule evaluation (combinational, indexed by rule_idx). This is the
    // ROM-constant rule table: fixed pattern -> fixed output, no runtime state.
    // ------------------------------------------------------------------------
    logic       r_match;
    logic [1:0] r_mode;
    logic [7:0] r_out0;
    logic [7:0] r_out1;

    always_comb begin
        // defaults: passthrough
        r_match = 1'b0;
        r_mode  = 2'b00;
        r_out0  = prev_q;
        r_out1  = curr_q;

        // class 10 "skt layer": cls=10, free_bit=0, non-nasal
        if (prev_q[7:6] == 2'b10 && !prev_q[2] && !prev_q[1] &&
            curr_q[7:6] == 2'b10 && !curr_q[2] && !curr_q[1]) begin
            case (rule_idx)
                // Rule 0: SAVARNA-DĪRGHA — same row -> long (len=1)
                2'd0: begin
                    if (prev_q[5:3] == curr_q[5:3]) begin
                        r_match = 1'b1;
                        r_mode  = 2'b01;
                        r_out0  = {2'b10, prev_q[5:3], 3'b001}; // {cls,row,free=0,nasal=0,len=1}
                        r_out1  = 8'h00;
                    end
                end

                // Rule 1: GUNA — a/ā(row0) + i/ī(row1) -> e(0xA8);
                //                  a/ā(row0) + u/ū(row2) -> o(0xB0)
                2'd1: begin
                    if (prev_q[5:3] == 3'd0) begin
                        if (curr_q[5:3] == 3'd1) begin
                            r_match = 1'b1;
                            r_mode  = 2'b01;
                            r_out0  = 8'hA8; // e
                            r_out1  = 8'h00;
                        end else if (curr_q[5:3] == 3'd2) begin
                            r_match = 1'b1;
                            r_mode  = 2'b01;
                            r_out0  = 8'hB0; // o
                            r_out1  = 8'h00;
                        end
                    end
                end

                // Rule 2: YAṆ — embryo i→y, u→v before a (different) vowel
                2'd2: begin
                    if (prev_q[5:3] == 3'd1 && curr_q[5:3] != 3'd1) begin
                        r_match = 1'b1;
                        r_mode  = 2'b10;
                        r_out0  = 8'h0A; // y
                        r_out1  = curr_q;
                    end else if (prev_q[5:3] == 3'd2 && curr_q[5:3] != 3'd2) begin
                        r_match = 1'b1;
                        r_mode  = 2'b10;
                        r_out0  = 8'h0B; // v
                        r_out1  = curr_q;
                    end
                end

                default: begin end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Main FSM
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            rule_idx <= 2'd0;
            matched  <= 1'b0;
            m_mode   <= 2'b00;
            m_out0   <= 8'h00;
            m_out1   <= 8'h00;
        end else begin
            case (state)
                ST_IDLE: begin
                    rule_idx <= 2'd0;
                    matched  <= 1'b0;
                    if (start) state <= ST_LOAD_RULE;
                end

                ST_LOAD_RULE: begin
                    state <= ST_APPLY;
                end

                ST_APPLY: begin
                    if (r_match) begin
                        matched <= 1'b1;
                        m_mode  <= r_mode;
                        m_out0  <= r_out0;
                        m_out1  <= r_out1;
                    end
                    state <= ST_CHECK_NEXT;
                end

                ST_CHECK_NEXT: begin
                    if (matched) begin
                        state <= ST_OUTPUT;
                    end else if (rule_idx == 2'd2) begin
                        // rule table exhausted: passthrough pair unchanged
                        m_mode <= 2'b00;
                        m_out0 <= prev_q;
                        m_out1 <= curr_q;
                        state  <= ST_OUTPUT;
                    end else begin
                        rule_idx <= rule_idx + 1'b1;
                        state    <= ST_LOAD_RULE;
                    end
                end

                ST_OUTPUT: begin
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    assign done         = (state == ST_OUTPUT);
    assign result_mode  = m_mode;
    assign result_0     = m_out0;
    assign result_1     = m_out1;
    assign error        = 1'b0;   // reserved for invalid-code detection

endmodule
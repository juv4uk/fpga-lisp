`include "lisp_word.sv"

// Target-private exact-D1 mechanism witness.
//
// This unit is intentionally isolated from the legacy instruction decoder and
// control path. It proves that the substrate can carry and consume current
// PredicateBit values without redefining OP_ATOM, OP_EQ or OP_JF.
//
// op:
//   0 = ATOM_D1  : result = PredicateBit(a is not CONS)
//   1 = EQ_D1    : atom-only equality; non-atom input -> named error
//   2 = GATE_D1  : consume exact PredicateBit from a; gate_take = payload bit
module predicate_bit_unit (
    input  logic [1:0] op,
    input  lisp_word_t a,
    input  lisp_word_t b,
    output lisp_word_t result,
    output logic       gate_take,
    output logic       valid,
    output logic       error
);

    localparam logic [1:0] OP_ATOM_D1 = 2'd0;
    localparam logic [1:0] OP_EQ_D1   = 2'd1;
    localparam logic [1:0] OP_GATE_D1 = 2'd2;

    function automatic logic canonical_predicate(input lisp_word_t value);
        canonical_predicate =
            value.tag == TAG_PREDICATE_BIT &&
            value.value[27:1] == 27'd0;
    endfunction

    always_comb begin
        result.tag = TAG_PREDICATE_BIT;
        result.value = 28'd0;
        gate_take = 1'b0;
        valid = 1'b0;
        error = 1'b0;

        case (op)
            OP_ATOM_D1: begin
                result.value[0] = (a.tag != TAG_CONS);
                valid = 1'b1;
            end

            OP_EQ_D1: begin
                if (a.tag == TAG_CONS || b.tag == TAG_CONS) begin
                    // Contract 11.8: current EQ is defined only on admitted
                    // atoms. Pair/out-of-domain input fails closed; EMPTY is
                    // not an EQ result and must not alias PredicateBit(0).
                    error = 1'b1;
                end else begin
                    result.value[0] = (a == b);
                    valid = 1'b1;
                end
            end

            OP_GATE_D1: begin
                if (!canonical_predicate(a)) begin
                    error = 1'b1;
                end else begin
                    result = a;
                    gate_take = a.value[0];
                    valid = 1'b1;
                end
            end

            default: error = 1'b1;
        endcase
    end
endmodule

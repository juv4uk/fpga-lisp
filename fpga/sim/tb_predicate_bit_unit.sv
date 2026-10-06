`include "lisp_word.sv"

module tb_predicate_bit_unit;
    logic [1:0] op;
    lisp_word_t a;
    lisp_word_t b;
    lisp_word_t result;
    logic gate_take;
    logic valid;
    logic error;
    integer failures;

    predicate_bit_unit dut (
        .op(op),
        .a(a),
        .b(b),
        .result(result),
        .gate_take(gate_take),
        .valid(valid),
        .error(error)
    );

    task automatic expect_d1(input logic expected, input [255:0] label_text);
        begin
            #1;
            if (error || !valid ||
                result.tag != TAG_PREDICATE_BIT ||
                result.value[27:1] != 27'd0 ||
                result.value[0] != expected) begin
                $display("FAILED %0s: tag=%0d value=%0d valid=%0d error=%0d",
                         label_text, result.tag, result.value, valid, error);
                failures = failures + 1;
            end
        end
    endtask

    task automatic expect_gate(
        input logic expected_take,
        input logic expected_error,
        input [255:0] label_text
    );
        begin
            #1;
            if (gate_take != expected_take || error != expected_error ||
                valid != !expected_error) begin
                $display("FAILED %0s: take=%0d valid=%0d error=%0d",
                         label_text, gate_take, valid, error);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        a = '{tag: TAG_SYMBOL, value: 28'd79};
        b = '{tag: TAG_NIL, value: 28'd0};

        // ATOM_D1 produces an exact PredicateBit, never Symbol(t)/NIL.
        op = 2'd0;
        expect_d1(1'b1, "ATOM_D1 symbol -> YES");
        a = '{tag: TAG_CONS, value: 28'd7};
        expect_d1(1'b0, "ATOM_D1 cons -> NO");

        // EQ_D1 is atom-only and preserves exact D1 result representation.
        op = 2'd1;
        a = '{tag: TAG_SYMBOL, value: 28'd2};
        b = '{tag: TAG_SYMBOL, value: 28'd2};
        expect_d1(1'b1, "EQ_D1 equal atoms -> YES");
        b = '{tag: TAG_SYMBOL, value: 28'd3};
        expect_d1(1'b0, "EQ_D1 unequal atoms -> NO");
        a = '{tag: TAG_CONS, value: 28'd1};
        #1;
        if (!error || valid) begin
            $display("FAILED EQ_D1 cons input must reject");
            failures = failures + 1;
        end

        // Exact gate accepts only canonical PredicateBit payloads.
        op = 2'd2;
        a = '{tag: TAG_PREDICATE_BIT, value: 28'd1};
        expect_gate(1'b1, 1'b0, "GATE_D1 YES");
        a = '{tag: TAG_PREDICATE_BIT, value: 28'd0};
        expect_gate(1'b0, 1'b0, "GATE_D1 NO");

        // Wider/historical values are not D1, even when they look truthy/falsy.
        a = '{tag: TAG_FIXNUM, value: 28'd1};
        expect_gate(1'b0, 1'b1, "GATE_D1 rejects fixnum 1");
        a = '{tag: TAG_FIXNUM, value: 28'd0};
        expect_gate(1'b0, 1'b1, "GATE_D1 rejects fixnum 0");
        a = '{tag: TAG_NIL, value: 28'd0};
        expect_gate(1'b0, 1'b1, "GATE_D1 rejects NIL");
        a = '{tag: TAG_SYMBOL, value: 28'd79};
        expect_gate(1'b0, 1'b1, "GATE_D1 rejects Symbol(t)");
        a = '{tag: TAG_PREDICATE_BIT, value: 28'd2};
        expect_gate(1'b0, 1'b1, "GATE_D1 rejects noncanonical payload");

        if (failures == 0)
            $display("D1-PREDICATE-CARRIER PASSED");
        else
            $display("D1-PREDICATE-CARRIER FAILED: %0d failure(s)", failures);

        $finish;
    end
endmodule

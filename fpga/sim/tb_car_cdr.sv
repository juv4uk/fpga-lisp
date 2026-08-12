`include "lisp_word.sv"

// M04: dedicated CAR/CDR coverage at the lisp_data_unit level. tb_cons.sv
// (M03) already exercises CAR once as part of proving CONS works; this
// fills the actual gap noted in docs/lisp-machine-plan.md's status
// section -- CDR has never been checked directly at this level (only
// indirectly, later, through the bootloader in tb_list.sv). Two
// independent cons cells, CAR and CDR checked on each.
module tb_car_cdr;

    logic clk;
    logic rst_n;

    logic cmd_cons;
    logic cmd_car;
    logic cmd_cdr;

    lisp_word_t op_a;
    lisp_word_t op_b;

    lisp_word_t result;
    logic valid;
    logic error;

    lisp_data_unit u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_cons(cmd_cons),
        .cmd_car(cmd_car),
        .cmd_cdr(cmd_cdr),
        .op_a(op_a),
        .op_b(op_b),
        .result(result),
        .valid(valid),
        .error(error)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    lisp_word_t pair1, pair2;
    integer fail_count;

    initial begin
        fail_count = 0;
        rst_n = 0;
        cmd_cons = 0;
        cmd_car = 0;
        cmd_cdr = 0;
        op_a = '0;
        op_b = '0;

        #20 rst_n = 1;

        // pair1 = (cons 'a 'b), symbols 2/3
        #10;
        op_a.tag = TAG_SYMBOL; op_a.value = 28'd2;
        op_b.tag = TAG_SYMBOL; op_b.value = 28'd3;
        cmd_cons = 1;
        #10 cmd_cons = 0;
        wait(valid); #10;
        pair1 = result;
        $display("pair1 = cons('a,'b) -> TAG:%0d VAL:%0d", pair1.tag, pair1.value);

        // pair2 = (cons 'c 'd), symbols 4/5 -- a second, independent cell
        op_a.tag = TAG_SYMBOL; op_a.value = 28'd4;
        op_b.tag = TAG_SYMBOL; op_b.value = 28'd5;
        cmd_cons = 1;
        #10 cmd_cons = 0;
        wait(valid); #10;
        pair2 = result;
        $display("pair2 = cons('c,'d) -> TAG:%0d VAL:%0d", pair2.tag, pair2.value);

        if (pair1.value == pair2.value) begin
            $display("FAILED: pair1 and pair2 landed on the same heap cell (%0d) -- bump allocator not advancing", pair1.value);
            fail_count = fail_count + 1;
        end

        // CAR(pair1) == 'a
        op_a = pair1;
        cmd_car = 1;
        #10 cmd_car = 0;
        wait(valid); #10;
        $display("CAR(pair1) = TAG:%0d VAL:%0d", result.tag, result.value);
        if (!(result.tag == TAG_SYMBOL && result.value == 28'd2)) begin
            $display("FAILED: CAR(pair1) != 'a");
            fail_count = fail_count + 1;
        end

        // CDR(pair1) == 'b -- the actual gap this testbench exists to close
        op_a = pair1;
        cmd_cdr = 1;
        #10 cmd_cdr = 0;
        wait(valid); #10;
        $display("CDR(pair1) = TAG:%0d VAL:%0d", result.tag, result.value);
        if (!(result.tag == TAG_SYMBOL && result.value == 28'd3)) begin
            $display("FAILED: CDR(pair1) != 'b");
            fail_count = fail_count + 1;
        end

        // CAR(pair2) == 'c
        op_a = pair2;
        cmd_car = 1;
        #10 cmd_car = 0;
        wait(valid); #10;
        $display("CAR(pair2) = TAG:%0d VAL:%0d", result.tag, result.value);
        if (!(result.tag == TAG_SYMBOL && result.value == 28'd4)) begin
            $display("FAILED: CAR(pair2) != 'c");
            fail_count = fail_count + 1;
        end

        // CDR(pair2) == 'd
        op_a = pair2;
        cmd_cdr = 1;
        #10 cmd_cdr = 0;
        wait(valid); #10;
        $display("CDR(pair2) = TAG:%0d VAL:%0d", result.tag, result.value);
        if (!(result.tag == TAG_SYMBOL && result.value == 28'd5)) begin
            $display("FAILED: CDR(pair2) != 'd");
            fail_count = fail_count + 1;
        end

        if (fail_count == 0) begin
            $display("M04 PASSED: CAR and CDR both correct on two independent cons cells");
        end else begin
            $display("M04 FAILED: %0d check(s) failed", fail_count);
        end

        #50 $finish;
    end

endmodule

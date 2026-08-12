`include "lisp_word.sv"

// M02: dedicated heap/bump-allocator coverage. tb_cons.sv (M03) and
// tb_car_cdr.sv (M04) both prove CONS/CAR/CDR work through
// lisp_data_unit's command interface, but neither ever looks at the
// heap memory itself -- they trust CAR/CDR readback. This testbench
// bypasses that: builds three cons cells, confirms the heap pointer
// (`hp`) bumps by exactly one per CONS (not reused, not skipped), and
// reads car_ram/cdr_ram directly at each returned address to confirm
// the actual stored words, independent of whatever CAR/CDR's own logic
// does afterward.
module tb_heap;

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

    integer addr0, addr1, addr2;
    integer fail_count;
    lisp_word_t car_check, cdr_check;

    initial begin
        fail_count = 0;
        rst_n = 0;
        cmd_cons = 0;
        cmd_car = 0;
        cmd_cdr = 0;
        op_a = '0;
        op_b = '0;

        #20 rst_n = 1;

        $display("Initial hp = %0d (expect 0, fresh reset)", u_dut.hp);
        if (u_dut.hp != 0) begin
            $display("FAILED: hp not 0 after reset");
            fail_count = fail_count + 1;
        end

        // cons #1: (10 . 20), plain fixnums so the raw stored words are
        // trivially readable in the $display output
        #10;
        op_a.tag = TAG_FIXNUM; op_a.value = 28'd10;
        op_b.tag = TAG_FIXNUM; op_b.value = 28'd20;
        cmd_cons = 1;
        #10 cmd_cons = 0;
        wait(valid); #10;
        addr0 = result.value;
        $display("cons#1 -> addr %0d, hp now %0d", addr0, u_dut.hp);

        // cons #2: (30 . 40)
        op_a.tag = TAG_FIXNUM; op_a.value = 28'd30;
        op_b.tag = TAG_FIXNUM; op_b.value = 28'd40;
        cmd_cons = 1;
        #10 cmd_cons = 0;
        wait(valid); #10;
        addr1 = result.value;
        $display("cons#2 -> addr %0d, hp now %0d", addr1, u_dut.hp);

        // cons #3: (50 . 60)
        op_a.tag = TAG_FIXNUM; op_a.value = 28'd50;
        op_b.tag = TAG_FIXNUM; op_b.value = 28'd60;
        cmd_cons = 1;
        #10 cmd_cons = 0;
        wait(valid); #10;
        addr2 = result.value;
        $display("cons#3 -> addr %0d, hp now %0d", addr2, u_dut.hp);

        if (!(addr1 == addr0 + 1 && addr2 == addr1 + 1)) begin
            $display("FAILED: addresses not sequential bump allocation (%0d, %0d, %0d)", addr0, addr1, addr2);
            fail_count = fail_count + 1;
        end
        if (u_dut.hp != addr2 + 1) begin
            $display("FAILED: hp (%0d) doesn't reflect three allocations from addr0=%0d", u_dut.hp, addr0);
            fail_count = fail_count + 1;
        end

        // Direct memory check, bypassing CAR/CDR entirely -- confirms the
        // heap module itself stored the right words, not just that
        // lisp_data_unit's CAR/CDR logic can read something plausible back.
        car_check = u_dut.u_heap.car_ram[addr0];
        cdr_check = u_dut.u_heap.cdr_ram[addr0];
        $display("heap[addr0] direct: car=TAG:%0d VAL:%0d cdr=TAG:%0d VAL:%0d",
                 car_check.tag, car_check.value, cdr_check.tag, cdr_check.value);
        if (!(car_check.tag == TAG_FIXNUM && car_check.value == 28'd10 &&
              cdr_check.tag == TAG_FIXNUM && cdr_check.value == 28'd20)) begin
            $display("FAILED: heap[addr0] direct read doesn't match (10 . 20)");
            fail_count = fail_count + 1;
        end

        car_check = u_dut.u_heap.car_ram[addr2];
        cdr_check = u_dut.u_heap.cdr_ram[addr2];
        $display("heap[addr2] direct: car=TAG:%0d VAL:%0d cdr=TAG:%0d VAL:%0d",
                 car_check.tag, car_check.value, cdr_check.tag, cdr_check.value);
        if (!(car_check.tag == TAG_FIXNUM && car_check.value == 28'd50 &&
              cdr_check.tag == TAG_FIXNUM && cdr_check.value == 28'd60)) begin
            $display("FAILED: heap[addr2] direct read doesn't match (50 . 60)");
            fail_count = fail_count + 1;
        end

        // addr0's cell must be untouched by the later allocations --
        // confirms cons#2/cons#3 didn't overwrite cons#1's cell.
        car_check = u_dut.u_heap.car_ram[addr0];
        if (car_check.value != 28'd10) begin
            $display("FAILED: heap[addr0] was overwritten by a later CONS");
            fail_count = fail_count + 1;
        end

        if (fail_count == 0) begin
            $display("M02 PASSED: heap bump-allocates sequentially, stores/preserves distinct cells correctly");
        end else begin
            $display("M02 FAILED: %0d check(s) failed", fail_count);
        end

        #50 $finish;
    end

endmodule

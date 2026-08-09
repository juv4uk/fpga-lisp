`include "lisp_word.sv"

// M22 bootstrap: pair -- (def pair (lambda (left right) (cons left
// (cons right '())))) from my-lisp's lib/core.my. First two-parameter
// closure: params is a 2-element list (param1 param2) instead of a
// bare symbol, distinguished from the 1-arg shape via ATOM(params).
// do_closure_apply gained a second path that evaluates both
// eagerly-extracted argument expressions and binds both parameters.
//
// (pair (quote a) (quote b)) => (a . b)
module tb_bootstrap_pair;

    logic clk;
    logic rst_n;
    logic halted;
    logic uart_tx;
    logic uart_rx;

    lisp_machine u_mac (
        .clk(clk),
        .rst_n(rst_n),
        .halted(halted),
        .uart_rx_in(uart_rx),
        .uart_tx_out(uart_tx)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    integer fd;
    integer n_bytes;
    byte prog_bytes[0:2047];
    integer n_words;
    integer outer_addr, inner_addr;
    lisp_word_t outer_car, outer_cdr, inner_car, inner_cdr;

    initial begin
        $dumpfile("tb_bootstrap_pair.vcd");
        $dumpvars(0, tb_bootstrap_pair);

        fd = $fopen("bootstrap_pair_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open bootstrap_pair_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from bootstrap_pair_demo.bin", n_bytes, n_words);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(n_words[7:0]);
        send_uart_byte(n_words[15:8]);
        for (int i = 0; i < n_bytes; i = i + 1) begin
            send_uart_byte(prog_bytes[i]);
        end

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R9 (pair 'a 'b) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        // pair builds a proper list (a b) = (cons a (cons b NIL)),
        // not a dotted pair -- outer.car='a, outer.cdr=inner CONS,
        // inner.car='b, inner.cdr=NIL.
        if (u_mac.u_regs.regs[9][31:28] == TAG_CONS) begin
            outer_addr = u_mac.u_regs.regs[9][27:0];
            outer_car = u_mac.u_ldu.u_heap.car_ram[outer_addr];
            outer_cdr = u_mac.u_ldu.u_heap.cdr_ram[outer_addr];
            $display("  outer[%0d] = (TAG:%0d VAL:%0d . TAG:%0d VAL:%0d)",
                outer_addr, outer_car.tag, outer_car.value, outer_cdr.tag, outer_cdr.value);
            if (outer_car.tag == TAG_SYMBOL && outer_car.value == 28'd1030 &&
                outer_cdr.tag == TAG_CONS) begin
                inner_addr = outer_cdr.value;
                inner_car = u_mac.u_ldu.u_heap.car_ram[inner_addr];
                inner_cdr = u_mac.u_ldu.u_heap.cdr_ram[inner_addr];
                $display("  inner[%0d] = (TAG:%0d VAL:%0d . TAG:%0d VAL:%0d)",
                    inner_addr, inner_car.tag, inner_car.value, inner_cdr.tag, inner_cdr.value);
                if (inner_car.tag == TAG_SYMBOL && inner_car.value == 28'd1031 &&
                    inner_cdr.tag == TAG_NIL) begin
                    $display("M22 PASSED: bootstrapped pair (two-parameter closure) works");
                end else begin
                    $display("M22 FAILED: wrong inner car/cdr");
                end
            end else begin
                $display("M22 FAILED: wrong outer car/cdr");
            end
        end else begin
            $display("M22 FAILED: result is not a CONS");
        end

        $finish;
    end

    initial begin
        #115_000_000; // watchdog (296-instruction upload alone takes ~103ms)
        $display("WATCHDOG TIMEOUT: test hung");
        $finish;
    end

    task send_uart_byte(input [7:0] b);
        integer i;
        begin
            uart_rx = 0; // Start bit
            #(8680);
            for (i=0; i<8; i=i+1) begin
                uart_rx = b[i];
                #(8680);
            end
            uart_rx = 1; // Stop bit
            #(8680);
        end
    endtask

endmodule

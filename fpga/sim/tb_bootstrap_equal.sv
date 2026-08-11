`include "lisp_word.sv"

// M32: canonical core.my `equal?`, structural equality via single-
// placeholder letrec self-recursion (unlike M29/M30's mutually-recursive
// pairs, equal? only ever calls itself). See bootstrap_equal_demo.asm's
// header for the full three-clause-cond mechanism and the edge-case
// checklist gathered from my-lisp's TCP oracle (mailbox ids 15/16/19).
// (equal? '(p . q) '(p . q)) => t, using two SEPARATE cons cells with the
// same content -- proves real structural comparison, not `eq` pointer
// identity. Unlike M28/M29 (fixnum result) this reads TRUE/NIL from R9
// directly (both are atoms, no heap walk needed, same pattern as M05's
// tb_atom_eq.sv).
module tb_bootstrap_equal;

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

    lisp_word_t r9;

    initial begin
        fd = $fopen("bootstrap_equal_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open bootstrap_equal_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from bootstrap_equal_demo.bin", n_bytes, n_words);

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
        r9 = u_mac.u_regs.regs[9];
        $display("R9 (equal? '(p . q) '(p . q)) = TAG:%0d VAL:%0d", r9.tag, r9.value);

        // TRUE is represented the same way every other bootstrap demo's
        // `EQ` result is: not TAG_NIL. A structural mismatch would halt
        // with r9 == NIL instead.
        if (r9.tag != TAG_NIL) begin
            $display("M32 PASSED: equal? via letrec self-recursion works, (equal? '(p . q) '(p . q)) => t");
        end else begin
            $display("M32 FAILED: expected TRUE (non-NIL), got NIL");
        end

        $finish;
    end

    initial begin
        #150_000_000;
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

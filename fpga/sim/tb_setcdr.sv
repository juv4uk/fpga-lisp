`include "lisp_word.sv"

// M26: SETCDR -- a new internal, bootstrap-only capability (ATOM with
// rs2 != 0, never reachable from eval/apply as an ordinary primitive):
// overwrites the CDR of an EXISTING cons cell in place, rather than
// allocating a new one. This is the one deliberate exception to "the
// heap never mutates a cell after CONS allocates it" -- needed so a
// closure can later be backpatched to see itself in its own captured
// environment (letrec-style self-reference), the mechanism confirmed
// with the my-lisp session (2026-08-10) as the only known-working
// approach (matching my-lisp's own Rust-host def, which mutates a
// shared Rc<RefCell<Frame>> in place -- lib/meta-eval.my's pure-cons,
// no-mutation metacircular evaluator documents this exact case as an
// unsolved gap for the same reason).
//
// Test: CONS (a . b), then SETCDR that same cell's cdr to 'z, then CDR
// it back out. Expect 'z, not 'b -- and the cell's CAR ('a) must be
// unchanged by the SETCDR (per-field write, not a whole-cell overwrite).
module tb_setcdr;

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
    byte prog_bytes[0:1023];
    integer n_words;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_setcdr.vcd");
            $dumpvars(0, tb_setcdr);
        end

        fd = $fopen("setcdr_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open setcdr_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from setcdr_demo.bin", n_bytes, n_words);

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
        $display("R9 (cdr after SETCDR) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);
        $display("R8 (car, must be unchanged) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[8][31:28], u_mac.u_regs.regs[8][27:0]);

        if (u_mac.u_regs.regs[9][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[9][27:0] == 28'd3 &&
            u_mac.u_regs.regs[8][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[8][27:0] == 28'd1) begin
            $display("M26 PASSED: SETCDR mutates an existing cell's cdr, leaves car untouched");
        end else begin
            $display("M26 FAILED");
        end

        $finish;
    end

    initial begin
        #50_000_000;
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

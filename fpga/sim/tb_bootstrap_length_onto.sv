`include "lisp_word.sv"

// M29 (WIP): canonical core.my `length`, via the real tail-recursive,
// mutually-recursive length/length-onto pair -- the follow-up M28's
// header deferred (see bootstrap_length_onto_demo.asm for the full
// mechanism: two letrec placeholders sharing one env frame, closure_onto
// exercising eval_core.inc's n-ary closure_nary binding loop for the
// first time in a bootstrap demo). (length '(a b c)) => 3, this time
// through three tail calls to length-onto rather than three nested
// `(add 1 (length ...))` frames.
//
// STATUS: WIP, NOT YET RUN on this machine (same Python/iverilog
// availability blocker as M28 -- see the .asm file's header).
module tb_bootstrap_length_onto;

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

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_bootstrap_length_onto.vcd");
            $dumpvars(0, tb_bootstrap_length_onto);
        end

        fd = $fopen("bootstrap_length_onto_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open bootstrap_length_onto_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from bootstrap_length_onto_demo.bin", n_bytes, n_words);

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
        $display("R9 (length '(a b c)) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[9][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[9][27:0] == 28'd3) begin
            $display("M29 PASSED: canonical tail-recursive length/length-onto via letrec works");
        end else begin
            $display("M29 FAILED");
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

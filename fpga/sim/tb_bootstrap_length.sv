`include "lisp_word.sv"

// M28: letrec via SETCDR backpatch -- the first self-referential closure.
// A simplified, NON-tail-recursive `length` (not the canonical core.my
// tail-recursive length/length-onto pair -- see bootstrap_length_demo.asm's
// header) whose body calls itself by name through a
// placeholder-pair-then-SETCDR-backpatch env frame. Proves the
// architectural gap noted at the end of M25 (docs/lisp-machine-plan.md) is
// closed: (length '(a b c)) => 3, three self-recursive eval calls deep.
// Matches tests/fixtures/conformance.my fixture #37's expected value.
module tb_bootstrap_length;

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
            $dumpfile("tb_bootstrap_length.vcd");
            $dumpvars(0, tb_bootstrap_length);
        end

        fd = $fopen("bootstrap_length_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open bootstrap_length_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from bootstrap_length_demo.bin", n_bytes, n_words);

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
            $display("M28 PASSED: letrec self-recursion via SETCDR backpatch works");
        end else begin
            $display("M28 FAILED");
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

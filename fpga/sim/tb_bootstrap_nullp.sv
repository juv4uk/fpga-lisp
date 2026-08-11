`include "lisp_word.sv"

// M19 bootstrap: the first function ported from my-lisp's lib/core.my,
// `(defun null? (x) (eq x nil))`, represented as an M11 closure whose
// body calls the `eq` primitive (M16/M18) and applied (M15) to two
// arguments: NIL itself (expect TRUE) and (quote a) (expect NIL).
// Nothing here is new hardware or new eval logic -- it is the first
// payload assembled entirely from pieces already verified individually.
//
// Program assembled externally (214 instructions); read via $fread
// like M16/M18's testbenches rather than hand-transcribed.
module tb_bootstrap_nullp;

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
            $dumpfile("tb_bootstrap_nullp.vcd");
            $dumpvars(0, tb_bootstrap_nullp);
        end

        fd = $fopen("bootstrap_nullp_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open bootstrap_nullp_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from bootstrap_nullp_demo.bin", n_bytes, n_words);

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
        $display("R8 (null? NIL)        = TAG:%0d VAL:%0d", u_mac.u_regs.regs[8][31:28], u_mac.u_regs.regs[8][27:0]);
        $display("R9 (null? (quote a))  = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[8][31:28] == TAG_TRUE &&
            u_mac.u_regs.regs[9][31:28] == TAG_NIL) begin
            $display("M19 PASSED: bootstrapped null? (closure + primitive + application) works");
        end else begin
            $display("M19 FAILED");
        end

        $finish;
    end

    initial begin
        #80_000_000; // watchdog (214-instruction upload alone takes ~75ms)
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

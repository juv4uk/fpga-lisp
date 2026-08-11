`include "lisp_word.sv"

// M21 bootstrap: not -- (def not (lambda (value) (cond (value '())
// (t t)))) from my-lisp's lib/core.my. First closure body built from
// `cond` (a special form) rather than a primitive application, so its
// captured env can be NIL -- it never needs to look anything up.
// (not NIL) => TRUE, (not (quote a)) => NIL.
module tb_bootstrap_not;

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
            $dumpfile("tb_bootstrap_not.vcd");
            $dumpvars(0, tb_bootstrap_not);
        end

        fd = $fopen("bootstrap_not_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open bootstrap_not_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from bootstrap_not_demo.bin", n_bytes, n_words);

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
        $display("R8 (not NIL)        = TAG:%0d VAL:%0d", u_mac.u_regs.regs[8][31:28], u_mac.u_regs.regs[8][27:0]);
        $display("R9 (not (quote a))  = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[8][31:28] == TAG_TRUE &&
            u_mac.u_regs.regs[9][31:28] == TAG_NIL) begin
            $display("M21 PASSED: bootstrapped not (cond inside closure body) works");
        end else begin
            $display("M21 FAILED");
        end

        $finish;
    end

    initial begin
        #90_000_000; // watchdog (229-instruction upload alone takes ~82ms)
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

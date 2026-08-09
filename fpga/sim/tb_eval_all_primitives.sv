`include "lisp_word.sv"

// M18 eval-all-primitives: extends M16's primitive dispatch (car,
// cons) with the three remaining hardware primitives -- cdr, atom,
// eq -- bound in a base environment as TAG_PRIMITIVE markers.
// Together M16+M18 make all five hardware primitives callable from
// eval as ordinary procedures.
//
// (eq (atom (cdr (quote (a . b)))) (atom (quote c))) => TRUE
//
// Program assembled externally (216 instructions); read via $fread
// like M16's tb_eval_primitive.sv rather than hand-transcribed.
module tb_eval_all_primitives;

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
        $dumpfile("tb_eval_all_primitives.vcd");
        $dumpvars(0, tb_eval_all_primitives);

        fd = $fopen("eval_all_primitives_demo.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open eval_all_primitives_demo.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from eval_all_primitives_demo.bin", n_bytes, n_words);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(n_words[7:0]);
        for (int i = 0; i < n_bytes; i = i + 1) begin
            send_uart_byte(prog_bytes[i]);
        end

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R9 = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[9][31:28] == TAG_TRUE) begin
            $display("M18 PASSED: eval-all-primitives (cdr/atom/eq as procedures) works");
        end else begin
            $display("M18 FAILED");
        end

        $finish;
    end

    initial begin
        #80_000_000; // watchdog (216-instruction upload alone takes ~75ms)
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

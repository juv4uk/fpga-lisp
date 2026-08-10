`include "lisp_word.sv"

module tb_cml_e2e;

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
        fd = $fopen("cml_e2e.bin", "rb");
        if (fd == 0) begin
            $display("FAILED: could not open cml_e2e.bin");
            $finish;
        end
        n_bytes = $fread(prog_bytes, fd);
        $fclose(fd);
        n_words = n_bytes / 4;
        $display("Loaded %0d bytes (%0d instructions) from cml_e2e.bin", n_bytes, n_words);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(n_words[7:0]);
        send_uart_byte(n_words[15:8]); // program length hi byte
        for (int i = 0; i < n_bytes; i = i + 1) begin
            send_uart_byte(prog_bytes[i]);
        end

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R15 = TAG:%0d VAL:%0d", u_mac.u_regs.regs[15][31:28], u_mac.u_regs.regs[15][27:0]);

        // TEST is defined as 7 in our compiler test
        if (u_mac.u_regs.regs[15][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[15][27:0] == 28'd7) begin
            $display("CML E2E PASSED");
        end else begin
            $display("CML E2E FAILED");
        end

        $finish;
    end

    initial begin
        #70_000_000;
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

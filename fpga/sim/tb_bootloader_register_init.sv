`timescale 1ns/1ps

module tb_bootloader_register_init;
    logic clk = 0;
    logic rst_n = 0;
    logic uart_rx = 1;
    logic uart_tx;
    logic halted;

    lisp_machine dut (
        .clk(clk),
        .rst_n(rst_n),
        .halted(halted),
        .uart_rx_in(uart_rx),
        .uart_tx_out(uart_tx)
    );

    always #10 clk = ~clk;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_bootloader_register_init.vcd");
            $dumpvars(0, tb_bootloader_register_init);
        end

        #100;
        rst_n = 1;
        #100;

        // Extended header: bit 15 set, two program words.
        send_uart_byte(8'h02);
        send_uart_byte(8'h80);
        send_uart_byte(8'h02); // two register initializers

        send_uart_byte(8'h00); // R0 = FIXNUM(3)
        send_uart_word(32'h00000003);
        send_uart_byte(8'h01); // R1 = FIXNUM(4)
        send_uart_word(32'h00000004);

        send_uart_word(32'hD2010000); // ADD R2, R0, R1
        send_uart_word(32'hB0000000); // HALT

        wait (halted);
        #100;
        if (dut.u_regs.regs[0] !== 32'h00000003 ||
            dut.u_regs.regs[1] !== 32'h00000004 ||
            dut.u_regs.regs[2] !== 32'h00000007) begin
            $display("FAILED: R0=%h R1=%h R2=%h", dut.u_regs.regs[0], dut.u_regs.regs[1], dut.u_regs.regs[2]);
            $fatal(1);
        end
        $display("PASSED: extended boot initialized R0=3 R1=4 and FPGA computed R2=7");
        $finish;
    end

    initial begin
        #20_000_000;
        $fatal(1, "TIMEOUT");
    end

    task send_uart_byte(input [7:0] value);
        integer bit_index;
        begin
            uart_rx = 0;
            #8680;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx = value[bit_index];
                #8680;
            end
            uart_rx = 1;
            #8680;
        end
    endtask

    task send_uart_word(input [31:0] word);
        begin
            send_uart_byte(word[7:0]);
            send_uart_byte(word[15:8]);
            send_uart_byte(word[23:16]);
            send_uart_byte(word[31:24]);
        end
    endtask
endmodule

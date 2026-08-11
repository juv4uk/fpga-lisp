`include "lisp_word.sv"

// ISA 1.0 / my-lisp G8: JF branches only on NIL. Fixnum zero is truthy.
// R2 is a progress marker: 0 means zero branched incorrectly, 1 means NIL
// failed to branch, and 2 proves both sides of the contract.
module tb_jf_truthiness;

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

    initial begin
        uart_rx = 1;
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd11);
        send_uart_byte(8'd0);
        send_uart_word(32'h11000000); // 0: LOADI R1, 0 (truthy under G8)
        send_uart_word(32'h12000000); // 1: LOADI R2, 0 (failure marker)
        send_uart_word(32'hA010000A); // 2: JF R1, fail(10) -- must fall through
        send_uart_word(32'h12000001); // 3: LOADI R2, 1
        send_uart_word(32'h9300000A); // 4: LOADSYM R3, 10
        send_uart_word(32'h9400000B); // 5: LOADSYM R4, 11
        send_uart_word(32'h75340000); // 6: EQ R5, R3, R4 -> NIL
        send_uart_word(32'hA0500009); // 7: JF R5, nil_ok(9) -- must branch
        send_uart_word(32'h8000000A); // 8: JMP fail(10)
        send_uart_word(32'h12000002); // 9: nil_ok: LOADI R2, 2
        send_uart_word(32'hB0000000); // 10: fail/done: HALT

        wait(halted);
        #50;

        if (u_mac.u_regs.regs[2][31:28] == TAG_FIXNUM &&
            u_mac.u_regs.regs[2][27:0] == 28'd2) begin
            $display("G8 PASSED: JF branches only on NIL");
        end else begin
            $display("G8 FAILED: R2 = TAG:%0d VAL:%0d",
                     u_mac.u_regs.regs[2][31:28],
                     u_mac.u_regs.regs[2][27:0]);
        end
        $finish;
    end

    initial begin
        #6_000_000;
        $display("WATCHDOG TIMEOUT: G8 test hung");
        $finish;
    end

    task send_uart_byte(input [7:0] b);
        integer i;
        begin
            uart_rx = 0;
            #(8680);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = b[i];
                #(8680);
            end
            uart_rx = 1;
            #(8680);
        end
    endtask

    task send_uart_word(input [31:0] w);
        begin
            send_uart_byte(w[7:0]);
            send_uart_byte(w[15:8]);
            send_uart_byte(w[23:16]);
            send_uart_byte(w[31:24]);
        end
    endtask

endmodule

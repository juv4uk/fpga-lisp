`include "lisp_word.sv"

// M07 CONTROL: countdown loop exercising JF (falsy branch) and JMP
// (forward skip + backward loop), plus SUB/ADD/EQ.
// R1 counts down 3->0, R2 counts up 0->3; expect R1=0, R2=3 at HALT.
module tb_control;

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
        $dumpfile("tb_control.vcd");
        $dumpvars(0, tb_control);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd11);
        send_uart_byte(8'd0); // program length hi byte
        send_uart_word(32'h11000003); // 0: LOADI R1, 3
        send_uart_word(32'h12000000); // 1: LOADI R2, 0
        send_uart_word(32'h13000001); // 2: LOADI R3, 1
        send_uart_word(32'h10000000); // 3: LOADI R0, 0
        send_uart_word(32'h74100000); // 4: loop: EQ R4, R1, R0
        send_uart_word(32'hA0400007); // 5: JF R4, body(7)
        send_uart_word(32'h8000000A); // 6: JMP done(10)
        send_uart_word(32'hE1130000); // 7: body: SUB R1, R1, R3
        send_uart_word(32'hD2230000); // 8: ADD R2, R2, R3
        send_uart_word(32'h80000004); // 9: JMP loop(4)
        send_uart_word(32'hB0000000); // 10: done: HALT

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R1 (countdown) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[1][31:28], u_mac.u_regs.regs[1][27:0]);
        $display("R2 (count up)  = TAG:%0d VAL:%0d", u_mac.u_regs.regs[2][31:28], u_mac.u_regs.regs[2][27:0]);

        if (u_mac.u_regs.regs[1][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[1][27:0] == 28'd0 &&
            u_mac.u_regs.regs[2][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[2][27:0] == 28'd3) begin
            $display("M07 PASSED: JF/JMP control flow works");
        end else begin
            $display("M07 FAILED");
        end

        $finish;
    end

    initial begin
        #6_000_000; // watchdog
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

    task send_uart_word(input [31:0] w);
        begin
            send_uart_byte(w[7:0]);
            send_uart_byte(w[15:8]);
            send_uart_byte(w[23:16]);
            send_uart_byte(w[31:24]);
        end
    endtask

endmodule

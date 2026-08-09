`include "lisp_word.sv"

// M09 CALL/RET: RISC-V-JAL-style subroutine call reusing OP_JMP.
// CALL rd,addr writes the return address into rd then jumps; RET rs1
// jumps to the address held in rs1. A subroutine doubles R2 via ADD
// and returns to the instruction right after the call site.
module tb_call;

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
        $dumpfile("tb_call.vcd");
        $dumpvars(0, tb_call);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd5);
        send_uart_word(32'h12000005); // 0: LOADI R2, 5
        send_uart_word(32'h81000003); // 1: CALL R1, func(3)
        send_uart_word(32'hB0000000); // 2: HALT  (returned-to here)
        send_uart_word(32'hD2220000); // 3: func: ADD R2, R2, R2
        send_uart_word(32'h80100000); // 4: RET R1

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R1 (return addr) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[1][31:28], u_mac.u_regs.regs[1][27:0]);
        $display("R2 (doubled)     = TAG:%0d VAL:%0d", u_mac.u_regs.regs[2][31:28], u_mac.u_regs.regs[2][27:0]);

        if (u_mac.u_regs.regs[1][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[1][27:0] == 28'd2 &&
            u_mac.u_regs.regs[2][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[2][27:0] == 28'd10) begin
            $display("M09 PASSED: CALL/RET subroutine call works");
        end else begin
            $display("M09 FAILED");
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

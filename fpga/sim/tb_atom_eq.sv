`include "lisp_word.sv"

// M05: ATOM / EQ
module tb_atom_eq;

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
        $dumpfile("tb_atom_eq.vcd");
        $dumpvars(0, tb_atom_eq);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;

        #100;

        send_uart_byte(8'd7);

        // 0: LOADSYM R1, #2 (symbol A)
        send_uart_word(32'h91000002);
        // 1: LOADSYM R2, #2 (symbol A, same as R1)
        send_uart_word(32'h92000002);
        // 2: CONS R3, R1, R2
        send_uart_word(32'h33120000);
        // 3: ATOM R4, R1  -> expect TRUE ('a is not a cons)
        send_uart_word(32'h64100000);
        // 4: ATOM R5, R3  -> expect NIL (R3 is a cons)
        send_uart_word(32'h65300000);
        // 5: EQ R6, R1, R2 -> expect TRUE (same symbol)
        send_uart_word(32'h76120000);
        // 6: HALT
        send_uart_word(32'hB0000000);

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R4 (atom 'a)          = TAG:%0d VAL:%0d", u_mac.u_regs.regs[4][31:28], u_mac.u_regs.regs[4][27:0]);
        $display("R5 (atom (cons a a))  = TAG:%0d VAL:%0d", u_mac.u_regs.regs[5][31:28], u_mac.u_regs.regs[5][27:0]);
        $display("R6 (eq 'a 'a)         = TAG:%0d VAL:%0d", u_mac.u_regs.regs[6][31:28], u_mac.u_regs.regs[6][27:0]);

        if (u_mac.u_regs.regs[4][31:28] == TAG_TRUE &&
            u_mac.u_regs.regs[5][31:28] == TAG_NIL &&
            u_mac.u_regs.regs[6][31:28] == TAG_TRUE) begin
            $display("M05 PASSED: ATOM/EQ behave correctly");
        end else begin
            $display("M05 FAILED");
        end

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

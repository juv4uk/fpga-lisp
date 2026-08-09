`include "lisp_word.sv"

// M06 LIST: build (radio antenna signal) as a CONS chain and walk it
// back with CAR/CDR, verifying the classic (a . (b . (c . nil))) shape.
module tb_list;

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
        $dumpfile("tb_list.vcd");
        $dumpvars(0, tb_list);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd16);
        send_uart_byte(8'd0); // program length hi byte
        send_uart_word(32'h91000002); // LOADSYM R1, 2  ('radio)
        send_uart_word(32'h92000003); // LOADSYM R2, 3  ('antenna)
        send_uart_word(32'h93000004); // LOADSYM R3, 4  ('signal)
        send_uart_word(32'h95000009); // LOADSYM R5, 9  (dummy A)
        send_uart_word(32'h9600000A); // LOADSYM R6, 10 (dummy B)
        send_uart_word(32'h77560000); // EQ R7, R5, R6  -> NIL
        send_uart_word(32'h38370000); // CONS R8, R3, R7  (signal . NIL)
        send_uart_word(32'h39280000); // CONS R9, R2, R8  (antenna . cell2)
        send_uart_word(32'h3A190000); // CONS R10, R1, R9 (radio . cell1) <- head
        send_uart_word(32'h4BA00000); // CAR R11, R10 -> radio
        send_uart_word(32'h5CA00000); // CDR R12, R10 -> cell1
        send_uart_word(32'h4DC00000); // CAR R13, R12 -> antenna
        send_uart_word(32'h5EC00000); // CDR R14, R12 -> cell2
        send_uart_word(32'h4FE00000); // CAR R15, R14 -> signal
        send_uart_word(32'h50E00000); // CDR R0, R14  -> NIL
        send_uart_word(32'hB0000000); // HALT

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R11 (car list)        = TAG:%0d VAL:%0d", u_mac.u_regs.regs[11][31:28], u_mac.u_regs.regs[11][27:0]);
        $display("R13 (car (cdr list))  = TAG:%0d VAL:%0d", u_mac.u_regs.regs[13][31:28], u_mac.u_regs.regs[13][27:0]);
        $display("R15 (caddr list)      = TAG:%0d VAL:%0d", u_mac.u_regs.regs[15][31:28], u_mac.u_regs.regs[15][27:0]);
        $display("R0  (cdddr list)      = TAG:%0d VAL:%0d", u_mac.u_regs.regs[0][31:28], u_mac.u_regs.regs[0][27:0]);

        if (u_mac.u_regs.regs[11][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[11][27:0] == 28'd2 &&
            u_mac.u_regs.regs[13][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[13][27:0] == 28'd3 &&
            u_mac.u_regs.regs[15][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[15][27:0] == 28'd4 &&
            u_mac.u_regs.regs[0][31:28]  == TAG_NIL) begin
            $display("M06 PASSED: 3-element list built and walked correctly");
        end else begin
            $display("M06 FAILED");
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

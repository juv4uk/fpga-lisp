`include "lisp_word.sv"

// M10 ENVIRONMENT: build ((x . 10) (y . 20)) as an alist of CONS pairs
// (no special ENV hardware type -- just cons structure, per the plan),
// then CALL a hand-written `lookup` subroutine that walks the alist
// with CAR/CDR/EQ and RETs the value bound to 'y.
module tb_env;

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
        $dumpfile("tb_env.vcd");
        $dumpvars(0, tb_env);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd23);
        send_uart_byte(8'd0); // program length hi byte
        send_uart_word(32'h91000005); // 0:  LOADSYM R1, 5   ('x)
        send_uart_word(32'h1200000A); // 1:  LOADI   R2, 10
        send_uart_word(32'h93000006); // 2:  LOADSYM R3, 6   ('y)
        send_uart_word(32'h14000014); // 3:  LOADI   R4, 20
        send_uart_word(32'h95000009); // 4:  LOADSYM R5, 9   (dummy A)
        send_uart_word(32'h9600000A); // 5:  LOADSYM R6, 10  (dummy B)
        send_uart_word(32'h77560000); // 6:  EQ R7, R5, R6   -> NIL
        send_uart_word(32'h38120000); // 7:  CONS R8, R1, R2  (x . 10)
        send_uart_word(32'h39340000); // 8:  CONS R9, R3, R4  (y . 20)
        send_uart_word(32'h3A970000); // 9:  CONS R10, R9, R7 (pair2 . NIL)
        send_uart_word(32'h3B8A0000); // 10: CONS R11, R8, R10 (pair1 . tail) = env
        send_uart_word(32'h9C000006); // 11: LOADSYM R12, 6  (search key 'y)
        send_uart_word(32'h2DB00000); // 12: MOV R13, R11    (env cursor = env)
        send_uart_word(32'h8E00000F); // 13: CALL R14, lookup(15)
        send_uart_word(32'hB0000000); // 14: HALT (return site)
        send_uart_word(32'h40D00000); // 15: lookup: CAR R0, R13
        send_uart_word(32'h41000000); // 16: CAR R1, R0
        send_uart_word(32'h721C0000); // 17: EQ R2, R1, R12
        send_uart_word(32'hA0200015); // 18: JF R2, next(21)
        send_uart_word(32'h5F000000); // 19: CDR R15, R0 (found)
        send_uart_word(32'h80E00000); // 20: RET R14
        send_uart_word(32'h5DD00000); // 21: next: CDR R13, R13
        send_uart_word(32'h8000000F); // 22: JMP lookup(15)

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R15 (lookup 'y) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[15][31:28], u_mac.u_regs.regs[15][27:0]);

        if (u_mac.u_regs.regs[15][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[15][27:0] == 28'd20) begin
            $display("M10 PASSED: alist environment lookup works");
        end else begin
            $display("M10 FAILED");
        end

        $finish;
    end

    initial begin
        #10_000_000; // watchdog
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

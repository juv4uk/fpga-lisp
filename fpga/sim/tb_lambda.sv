`include "lisp_word.sv"

// M11 LAMBDA: represent a closure as (params . (body . env)) -- pure
// CONS structure, no special hardware type. "Calling" it extracts
// params, extends the captured env with (param . arg), then looks the
// param up in the new env to confirm the binding -- standing in for
// what eval will later do when it evaluates the body in that extended
// environment (eval itself is the next milestone).
module tb_lambda;

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
        $dumpfile("tb_lambda.vcd");
        $dumpvars(0, tb_lambda);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd25);
        send_uart_word(32'h93000005); // 0:  LOADSYM R3, 5   (param name 'x)
        send_uart_word(32'h1400002A); // 1:  LOADI   R4, 42  (arg value)
        send_uart_word(32'h95000009); // 2:  LOADSYM R5, 9   (dummy A)
        send_uart_word(32'h9600000A); // 3:  LOADSYM R6, 10  (dummy B)
        send_uart_word(32'h77560000); // 4:  EQ R7, R5, R6   -> NIL (outer env)
        send_uart_word(32'h98000007); // 5:  LOADSYM R8, 7   (body placeholder)
        send_uart_word(32'h39870000); // 6:  CONS R9, R8, R7  (body . env)
        send_uart_word(32'h3A390000); // 7:  CONS R10, R3, R9 closure=(params.(body.env))
        send_uart_word(32'h4BA00000); // 8:  CAR R11, R10 -> params
        send_uart_word(32'h56A00000); // 9:  CDR R6, R10  -> rest = (body . env)
        send_uart_word(32'h55600000); // 10: CDR R5, R6   -> env
        send_uart_word(32'h39B40000); // 11: CONS R9, R11, R4 -> pair=(params.arg)
        send_uart_word(32'h38950000); // 12: CONS R8, R9, R5  -> new_env=(pair.env)
        send_uart_word(32'h2CB00000); // 13: MOV R12, R11 (lookup key = params)
        send_uart_word(32'h2D800000); // 14: MOV R13, R8  (lookup env = new_env)
        send_uart_word(32'h8E000011); // 15: CALL R14, lookup(17)
        send_uart_word(32'hB0000000); // 16: HALT (return site)
        send_uart_word(32'h40D00000); // 17: lookup: CAR R0, R13
        send_uart_word(32'h41000000); // 18: CAR R1, R0
        send_uart_word(32'h721C0000); // 19: EQ R2, R1, R12
        send_uart_word(32'hA0200017); // 20: JF R2, next(23)
        send_uart_word(32'h5F000000); // 21: CDR R15, R0 (found)
        send_uart_word(32'h80E00000); // 22: RET R14
        send_uart_word(32'h5DD00000); // 23: next: CDR R13, R13
        send_uart_word(32'h80000011); // 24: JMP lookup(17)

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R15 (bound 'x) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[15][31:28], u_mac.u_regs.regs[15][27:0]);

        if (u_mac.u_regs.regs[15][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[15][27:0] == 28'd42) begin
            $display("M11 PASSED: closure representation + parameter binding works");
        end else begin
            $display("M11 FAILED");
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

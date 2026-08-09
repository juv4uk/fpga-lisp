`include "lisp_word.sv"

// M12 eval-atom: eval(expr, env) for atoms only. Symbol -> looked up
// in env via the M10 `lookup` subroutine; non-symbol (fixnum) ->
// self-evaluating. Uses the new GETTAG mode of OP_MOV (rs2==1) to
// dispatch on the expression's tag. eval and lookup use disjoint
// register frames (no hardware call stack) so the nested eval->lookup
// call can't clobber eval's own expr/env/return-address/output.
module tb_eval_atom;

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
        $dumpfile("tb_eval_atom.vcd");
        $dumpvars(0, tb_eval_atom);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd40);
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
        send_uart_word(32'h3B8A0000); // 10: CONS R11, R8, R10 env
        send_uart_word(32'h90000006); // 11: LOADSYM R0, 6  (expr1 = 'y)
        send_uart_word(32'h23000000); // 12: MOV R3, R0
        send_uart_word(32'h24B00000); // 13: MOV R4, R11
        send_uart_word(32'h85000015); // 14: CALL R5, eval(21)
        send_uart_word(32'h2A900000); // 15: MOV R10, R9 (save result1)
        send_uart_word(32'h10000063); // 16: LOADI R0, 99 (expr2)
        send_uart_word(32'h23000000); // 17: MOV R3, R0
        send_uart_word(32'h24B00000); // 18: MOV R4, R11
        send_uart_word(32'h85000015); // 19: CALL R5, eval(21)
        send_uart_word(32'hB0000000); // 20: HALT
        send_uart_word(32'h26310000); // 21: eval: GETTAG R6, R3
        send_uart_word(32'h17000002); // 22: LOADI R7, 2 (TAG_SYMBOL)
        send_uart_word(32'h78670000); // 23: EQ R8, R6, R7
        send_uart_word(32'hA080001E); // 24: JF R8, not_symbol(30)
        send_uart_word(32'h2C300000); // 25: MOV R12, R3 (lookup key)
        send_uart_word(32'h2D400000); // 26: MOV R13, R4 (lookup env)
        send_uart_word(32'h8E000020); // 27: CALL R14, lookup(32)
        send_uart_word(32'h29F00000); // 28: MOV R9, R15
        send_uart_word(32'h8000001F); // 29: JMP eval_done(31)
        send_uart_word(32'h29300000); // 30: not_symbol: MOV R9, R3
        send_uart_word(32'h80500000); // 31: eval_done: RET R5
        send_uart_word(32'h40D00000); // 32: lookup: CAR R0, R13
        send_uart_word(32'h41000000); // 33: CAR R1, R0
        send_uart_word(32'h721C0000); // 34: EQ R2, R1, R12
        send_uart_word(32'hA0200026); // 35: JF R2, next(38)
        send_uart_word(32'h5F000000); // 36: CDR R15, R0
        send_uart_word(32'h80E00000); // 37: RET R14
        send_uart_word(32'h5DD00000); // 38: next: CDR R13, R13
        send_uart_word(32'h80000020); // 39: JMP lookup(32)

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R10 (eval 'y)  = TAG:%0d VAL:%0d", u_mac.u_regs.regs[10][31:28], u_mac.u_regs.regs[10][27:0]);
        $display("R9  (eval 99)  = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[10][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[10][27:0] == 28'd20 &&
            u_mac.u_regs.regs[9][31:28]  == TAG_FIXNUM && u_mac.u_regs.regs[9][27:0]  == 28'd99) begin
            $display("M12 PASSED: eval-atom (symbol lookup + self-evaluating) works");
        end else begin
            $display("M12 FAILED");
        end

        $finish;
    end

    initial begin
        #20_000_000; // watchdog (40-instruction upload alone takes ~14ms)
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

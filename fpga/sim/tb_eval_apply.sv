`include "lisp_word.sv"

// M15 eval-apply: eval(expr, env) handles application (f arg) where f
// evaluates to an M11 closure -- (params . (body . env)). Closes the
// loop the plan calls for: eval(operator), eval(arg), bind the
// parameter by extending the closure's captured env, then
// eval(body, new_env) -- three more recursive eval calls through the
// same CONS-based software stack (R11) built for M14's cond.
//
// Test: bind 'identity to the closure (n . (n . NIL)) in an outer env,
// then eval (identity 42). Exercises every eval path in one
// expression: self-evaluating (42), symbol lookup ('identity, then
// 'n inside the call), and application.
module tb_eval_apply;

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
        $dumpfile("tb_eval_apply.vcd");
        $dumpvars(0, tb_eval_apply);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd120);
        send_uart_byte(8'd0); // program length hi byte
        send_uart_word(32'h9100006E); // 0:  LOADSYM R1, 110
        send_uart_word(32'h9200006F); // 1:  LOADSYM R2, 111
        send_uart_word(32'h76120000); // 2:  EQ R6, R1, R2 -> NIL
        send_uart_word(32'h91000070); // 3:  LOADSYM R1, 112
        send_uart_word(32'h92000071); // 4:  LOADSYM R2, 113
        send_uart_word(32'h7B120000); // 5:  EQ R11, R1, R2 -> NIL (stack)
        send_uart_word(32'h91000028); // 6:  LOADSYM R1, 40 ('n)
        send_uart_word(32'h33160000); // 7:  CONS R3, R1, R6 (n . NIL)
        send_uart_word(32'h34130000); // 8:  CONS R4, R1, R3 closure=(n (n))
        send_uart_word(32'h97000029); // 9:  LOADSYM R7, 41 ('identity)
        send_uart_word(32'h38740000); // 10: CONS R8, R7, R4 (identity . closure)
        send_uart_word(32'h39860000); // 11: CONS R9, R8, R6 outer_env
        send_uart_word(32'h1A00002A); // 12: LOADI R10, 42
        send_uart_word(32'h31A60000); // 13: CONS R1, R10, R6 (42)
        send_uart_word(32'h32710000); // 14: CONS R2, R7, R1  expr=(identity 42)
        send_uart_word(32'h23200000); // 15: MOV R3, R2
        send_uart_word(32'h24900000); // 16: MOV R4, R9
        send_uart_word(32'h85000013); // 17: CALL R5, eval(19)
        send_uart_word(32'hB0000000); // 18: HALT
        send_uart_word(32'h66300000); // 19: eval: ATOM R6, R3
        send_uart_word(32'hA0600020); // 20: JF R6, is_cons(32)
        send_uart_word(32'h26310000); // 21: GETTAG R6, R3
        send_uart_word(32'h17000002); // 22: LOADI R7, 2
        send_uart_word(32'h78670000); // 23: EQ R8, R6, R7
        send_uart_word(32'hA080001E); // 24: JF R8, self_eval(30)
        send_uart_word(32'h2C300000); // 25: MOV R12, R3
        send_uart_word(32'h2D400000); // 26: MOV R13, R4
        send_uart_word(32'h8E000070); // 27: CALL R14, lookup(112)
        send_uart_word(32'h29F00000); // 28: MOV R9, R15
        send_uart_word(32'h8000006F); // 29: JMP done(111)
        send_uart_word(32'h29300000); // 30: self_eval: MOV R9, R3
        send_uart_word(32'h8000006F); // 31: JMP done(111)
        send_uart_word(32'h46300000); // 32: is_cons: CAR R6, R3
        send_uart_word(32'h97000032); // 33: LOADSYM R7, 50 ('quote)
        send_uart_word(32'h78670000); // 34: EQ R8, R6, R7
        send_uart_word(32'hA0800027); // 35: JF R8, check_cond(39)
        send_uart_word(32'h5A300000); // 36: CDR R10, R3
        send_uart_word(32'h49A00000); // 37: CAR R9, R10
        send_uart_word(32'h8000006F); // 38: JMP done(111)
        send_uart_word(32'h97000050); // 39: check_cond: LOADSYM R7, 80 ('cond)
        send_uart_word(32'h78670000); // 40: EQ R8, R6, R7
        send_uart_word(32'hA0800049); // 41: JF R8, try_apply(73)
        send_uart_word(32'h56300000); // 42: CDR R6, R3 (clauses)
        send_uart_word(32'h68600000); // 43: cond_loop: ATOM R8, R6
        send_uart_word(32'hA0800031); // 44: JF R8, has_clause(49)
        send_uart_word(32'h9600005A); // 45: LOADSYM R6, 90
        send_uart_word(32'h9700005B); // 46: LOADSYM R7, 91
        send_uart_word(32'h79670000); // 47: EQ R9, R6, R7 -> NIL
        send_uart_word(32'h8000006F); // 48: JMP done(111)
        send_uart_word(32'h4A600000); // 49: has_clause: CAR R10, R6
        send_uart_word(32'h47A00000); // 50: CAR R7, R10 (test)
        send_uart_word(32'h3B5B0000); // 51: CONS R11, R5, R11 (push retaddr)
        send_uart_word(32'h3B6B0000); // 52: CONS R11, R6, R11 (push clauses)
        send_uart_word(32'h3BAB0000); // 53: CONS R11, R10, R11 (push clause)
        send_uart_word(32'h23700000); // 54: MOV R3, R7 (expr=test)
        send_uart_word(32'h85000013); // 55: CALL R5, eval(19) [recursive]
        send_uart_word(32'h4AB00000); // 56: CAR R10, R11 (pop clause)
        send_uart_word(32'h5BB00000); // 57: CDR R11, R11
        send_uart_word(32'h46B00000); // 58: CAR R6, R11 (pop clauses)
        send_uart_word(32'h5BB00000); // 59: CDR R11, R11
        send_uart_word(32'h45B00000); // 60: CAR R5, R11 (pop retaddr)
        send_uart_word(32'h5BB00000); // 61: CDR R11, R11
        send_uart_word(32'hA0900047); // 62: JF R9, clause_false(71)
        send_uart_word(32'h58A00000); // 63: CDR R8, R10 (rest-of-clause)
        send_uart_word(32'h48800000); // 64: CAR R8, R8 (value-expr)
        send_uart_word(32'h3B5B0000); // 65: CONS R11, R5, R11 (push retaddr)
        send_uart_word(32'h23800000); // 66: MOV R3, R8 (expr=value)
        send_uart_word(32'h85000013); // 67: CALL R5, eval(19) [recursive]
        send_uart_word(32'h45B00000); // 68: CAR R5, R11 (pop retaddr)
        send_uart_word(32'h5BB00000); // 69: CDR R11, R11
        send_uart_word(32'h8000006F); // 70: JMP done(111)
        send_uart_word(32'h56600000); // 71: clause_false: CDR R6, R6
        send_uart_word(32'h8000002B); // 72: JMP cond_loop(43)
        send_uart_word(32'h5A300000); // 73: try_apply: CDR R10, R3 (args)
        send_uart_word(32'h47A00000); // 74: CAR R7, R10 (arg_expr)
        send_uart_word(32'h3B5B0000); // 75: CONS R11, R5, R11 (push retaddr)
        send_uart_word(32'h3B4B0000); // 76: CONS R11, R4, R11 (push env)
        send_uart_word(32'h3B7B0000); // 77: CONS R11, R7, R11 (push arg_expr)
        send_uart_word(32'h23600000); // 78: MOV R3, R6 (expr=operator)
        send_uart_word(32'h85000013); // 79: CALL R5, eval(19) [eval operator]
        send_uart_word(32'h47B00000); // 80: CAR R7, R11 (pop arg_expr)
        send_uart_word(32'h5BB00000); // 81: CDR R11, R11
        send_uart_word(32'h44B00000); // 82: CAR R4, R11 (pop env)
        send_uart_word(32'h5BB00000); // 83: CDR R11, R11
        send_uart_word(32'h45B00000); // 84: CAR R5, R11 (pop retaddr)
        send_uart_word(32'h5BB00000); // 85: CDR R11, R11
        send_uart_word(32'h26900000); // 86: MOV R6, R9 (closure)
        send_uart_word(32'h3B5B0000); // 87: CONS R11, R5, R11 (push retaddr)
        send_uart_word(32'h3B4B0000); // 88: CONS R11, R4, R11 (push env)
        send_uart_word(32'h3B6B0000); // 89: CONS R11, R6, R11 (push closure)
        send_uart_word(32'h23700000); // 90: MOV R3, R7 (expr=arg_expr)
        send_uart_word(32'h85000013); // 91: CALL R5, eval(19) [eval arg]
        send_uart_word(32'h46B00000); // 92: CAR R6, R11 (pop closure)
        send_uart_word(32'h5BB00000); // 93: CDR R11, R11
        send_uart_word(32'h44B00000); // 94: CAR R4, R11 (pop env)
        send_uart_word(32'h5BB00000); // 95: CDR R11, R11
        send_uart_word(32'h45B00000); // 96: CAR R5, R11 (pop retaddr)
        send_uart_word(32'h5BB00000); // 97: CDR R11, R11
        send_uart_word(32'h28900000); // 98: MOV R8, R9 (arg value)
        send_uart_word(32'h47600000); // 99: CAR R7, R6 (params)
        send_uart_word(32'h5A600000); // 100: CDR R10, R6 (rest)
        send_uart_word(32'h46A00000); // 101: CAR R6, R10 (body)
        send_uart_word(32'h5AA00000); // 102: CDR R10, R10 (captured_env)
        send_uart_word(32'h39780000); // 103: CONS R9, R7, R8 (pair)
        send_uart_word(32'h349A0000); // 104: CONS R4, R9, R10 (new_env)
        send_uart_word(32'h3B5B0000); // 105: CONS R11, R5, R11 (push retaddr)
        send_uart_word(32'h23600000); // 106: MOV R3, R6 (expr=body)
        send_uart_word(32'h85000013); // 107: CALL R5, eval(19) [eval body]
        send_uart_word(32'h45B00000); // 108: CAR R5, R11 (pop retaddr)
        send_uart_word(32'h5BB00000); // 109: CDR R11, R11
        send_uart_word(32'h8000006F); // 110: JMP done(111)
        send_uart_word(32'h80500000); // 111: done: RET R5
        send_uart_word(32'h40D00000); // 112: lookup: CAR R0, R13
        send_uart_word(32'h41000000); // 113: CAR R1, R0
        send_uart_word(32'h721C0000); // 114: EQ R2, R1, R12
        send_uart_word(32'hA0200076); // 115: JF R2, next(118)
        send_uart_word(32'h5F000000); // 116: CDR R15, R0
        send_uart_word(32'h80E00000); // 117: RET R14
        send_uart_word(32'h5DD00000); // 118: next: CDR R13, R13
        send_uart_word(32'h80000070); // 119: JMP lookup(112)

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R9 (eval apply identity 42) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[9][31:28] == TAG_FIXNUM && u_mac.u_regs.regs[9][27:0] == 28'd42) begin
            $display("M15 PASSED: eval-apply (closure application) works");
        end else begin
            $display("M15 FAILED");
        end

        $finish;
    end

    initial begin
        #55_000_000; // watchdog (120-instruction upload alone takes ~42ms)
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

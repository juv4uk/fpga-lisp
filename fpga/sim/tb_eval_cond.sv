`include "lisp_word.sv"

// M14 eval-cond: eval(expr, env) recognizes (cond (t1 v1) (t2 v2) ...)
// and recurses into itself to evaluate each clause's test and value --
// eval's first genuine self-recursion. A fixed register frame cannot
// survive that (the recursive call clobbers the same registers), so
// this uses a software call stack built from CONS cells: R11 is the
// stack-top pointer, push(v) = R11<-CONS(v,R11), pop = CAR/CDR(R11).
// Clause values are (quote X) sub-expressions, not bare symbols -- a
// bare symbol value would make eval look it up as a variable (M12's
// own rule); 'right is reader shorthand for (quote right).
// Mirrors conformance.my: (cond (() 'wrong) (t 'right)) => right.
module tb_eval_cond;

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
        $dumpfile("tb_eval_cond.vcd");
        $dumpvars(0, tb_eval_cond);

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd94);
        send_uart_word(32'h91000064); // 0:  LOADSYM R1, 100
        send_uart_word(32'h92000065); // 1:  LOADSYM R2, 101
        send_uart_word(32'h7B120000); // 2:  EQ R11, R1, R2 -> NIL (stack)
        send_uart_word(32'h91000066); // 3:  LOADSYM R1, 102
        send_uart_word(32'h72110000); // 4:  EQ R2, R1, R1 -> TRUE
        send_uart_word(32'h93000067); // 5:  LOADSYM R3, 103
        send_uart_word(32'h94000068); // 6:  LOADSYM R4, 104
        send_uart_word(32'h75340000); // 7:  EQ R5, R3, R4 -> NIL
        send_uart_word(32'h96000051); // 8:  LOADSYM R6, 81 ('wrong)
        send_uart_word(32'h37650000); // 9:  CONS R7, R6, R5  (wrong)
        send_uart_word(32'h96000032); // 10: LOADSYM R6, 50 ('quote)
        send_uart_word(32'h37670000); // 11: CONS R7, R6, R7  value1=(quote wrong)
        send_uart_word(32'h38750000); // 12: CONS R8, R7, R5  (value1)
        send_uart_word(32'h38580000); // 13: CONS R8, R5, R8  clause1=(NIL (quote wrong))
        send_uart_word(32'h99000052); // 14: LOADSYM R9, 82 ('right)
        send_uart_word(32'h3A950000); // 15: CONS R10, R9, R5 (right)
        send_uart_word(32'h99000032); // 16: LOADSYM R9, 50 ('quote)
        send_uart_word(32'h3A9A0000); // 17: CONS R10, R9, R10 value2=(quote right)
        send_uart_word(32'h31A50000); // 18: CONS R1, R10, R5 (value2)
        send_uart_word(32'h31210000); // 19: CONS R1, R2, R1  clause2=(TRUE (quote right))
        send_uart_word(32'h33150000); // 20: CONS R3, R1, R5  (clause2)
        send_uart_word(32'h34830000); // 21: CONS R4, R8, R3  clauses
        send_uart_word(32'h96000050); // 22: LOADSYM R6, 80 ('cond)
        send_uart_word(32'h39640000); // 23: CONS R9, R6, R4  cond-expr
        send_uart_word(32'h23900000); // 24: MOV R3, R9 (expr)
        send_uart_word(32'h24500000); // 25: MOV R4, R5 (env = NIL)
        send_uart_word(32'h8500001C); // 26: CALL R5, eval(28)
        send_uart_word(32'hB0000000); // 27: HALT
        send_uart_word(32'h66300000); // 28: eval: ATOM R6, R3
        send_uart_word(32'hA0600029); // 29: JF R6, is_cons(41)
        send_uart_word(32'h26310000); // 30: GETTAG R6, R3
        send_uart_word(32'h17000002); // 31: LOADI R7, 2
        send_uart_word(32'h78670000); // 32: EQ R8, R6, R7
        send_uart_word(32'hA0800027); // 33: JF R8, self_eval(39)
        send_uart_word(32'h2C300000); // 34: MOV R12, R3
        send_uart_word(32'h2D400000); // 35: MOV R13, R4
        send_uart_word(32'h8E000056); // 36: CALL R14, lookup(86)
        send_uart_word(32'h29F00000); // 37: MOV R9, R15
        send_uart_word(32'h80000055); // 38: JMP done(85)
        send_uart_word(32'h29300000); // 39: self_eval: MOV R9, R3
        send_uart_word(32'h80000055); // 40: JMP done(85)
        send_uart_word(32'h46300000); // 41: is_cons: CAR R6, R3
        send_uart_word(32'h97000032); // 42: LOADSYM R7, 50 ('quote)
        send_uart_word(32'h78670000); // 43: EQ R8, R6, R7
        send_uart_word(32'hA0800030); // 44: JF R8, check_cond(48)
        send_uart_word(32'h5A300000); // 45: CDR R10, R3
        send_uart_word(32'h49A00000); // 46: CAR R9, R10
        send_uart_word(32'h80000055); // 47: JMP done(85)
        send_uart_word(32'h97000050); // 48: check_cond: LOADSYM R7, 80 ('cond)
        send_uart_word(32'h78670000); // 49: EQ R8, R6, R7
        send_uart_word(32'hA0800052); // 50: JF R8, unknown_form(82)
        send_uart_word(32'h56300000); // 51: CDR R6, R3 (clauses)
        send_uart_word(32'h68600000); // 52: cond_loop: ATOM R8, R6
        send_uart_word(32'hA080003A); // 53: JF R8, has_clause(58)
        send_uart_word(32'h9600005A); // 54: LOADSYM R6, 90
        send_uart_word(32'h9700005B); // 55: LOADSYM R7, 91
        send_uart_word(32'h79670000); // 56: EQ R9, R6, R7 -> NIL (exhausted)
        send_uart_word(32'h80000055); // 57: JMP done(85)
        send_uart_word(32'h4A600000); // 58: has_clause: CAR R10, R6
        send_uart_word(32'h47A00000); // 59: CAR R7, R10 (test)
        send_uart_word(32'h3B5B0000); // 60: CONS R11, R5, R11 (push retaddr)
        send_uart_word(32'h3B6B0000); // 61: CONS R11, R6, R11 (push clauses)
        send_uart_word(32'h3BAB0000); // 62: CONS R11, R10, R11 (push clause)
        send_uart_word(32'h23700000); // 63: MOV R3, R7 (expr=test)
        send_uart_word(32'h8500001C); // 64: CALL R5, eval(28) [recursive]
        send_uart_word(32'h4AB00000); // 65: CAR R10, R11 (pop clause)
        send_uart_word(32'h5BB00000); // 66: CDR R11, R11
        send_uart_word(32'h46B00000); // 67: CAR R6, R11 (pop clauses)
        send_uart_word(32'h5BB00000); // 68: CDR R11, R11
        send_uart_word(32'h45B00000); // 69: CAR R5, R11 (pop retaddr)
        send_uart_word(32'h5BB00000); // 70: CDR R11, R11
        send_uart_word(32'hA0900050); // 71: JF R9, clause_false(80)
        send_uart_word(32'h58A00000); // 72: CDR R8, R10 (rest-of-clause)
        send_uart_word(32'h48800000); // 73: CAR R8, R8 (value-expr)
        send_uart_word(32'h3B5B0000); // 74: CONS R11, R5, R11 (push retaddr)
        send_uart_word(32'h23800000); // 75: MOV R3, R8 (expr=value)
        send_uart_word(32'h8500001C); // 76: CALL R5, eval(28) [recursive]
        send_uart_word(32'h45B00000); // 77: CAR R5, R11 (pop retaddr)
        send_uart_word(32'h5BB00000); // 78: CDR R11, R11
        send_uart_word(32'h80000055); // 79: JMP done(85)
        send_uart_word(32'h56600000); // 80: clause_false: CDR R6, R6
        send_uart_word(32'h80000034); // 81: JMP cond_loop(52)
        send_uart_word(32'h9600005C); // 82: unknown_form: LOADSYM R6, 92
        send_uart_word(32'h9700005D); // 83: LOADSYM R7, 93
        send_uart_word(32'h79670000); // 84: EQ R9, R6, R7 -> NIL
        send_uart_word(32'h80500000); // 85: done: RET R5
        send_uart_word(32'h40D00000); // 86: lookup: CAR R0, R13
        send_uart_word(32'h41000000); // 87: CAR R1, R0
        send_uart_word(32'h721C0000); // 88: EQ R2, R1, R12
        send_uart_word(32'hA020005C); // 89: JF R2, next(92)
        send_uart_word(32'h5F000000); // 90: CDR R15, R0
        send_uart_word(32'h80E00000); // 91: RET R14
        send_uart_word(32'h5DD00000); // 92: next: CDR R13, R13
        send_uart_word(32'h80000056); // 93: JMP lookup(86)

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R9 (eval cond) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[9][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[9][27:0] == 28'd82) begin
            $display("M14 PASSED: eval-cond (recursive eval via CONS-based stack) works");
        end else begin
            $display("M14 FAILED");
        end

        $finish;
    end

    initial begin
        #45_000_000; // watchdog (94-instruction upload alone takes ~33ms)
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

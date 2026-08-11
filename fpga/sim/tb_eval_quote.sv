`include "lisp_word.sv"

// M13 eval-quote: eval(expr, env) now dispatches on ATOM vs CONS via
// OP_ATOM. Atoms behave as in M12 (symbol -> lookup, else
// self-evaluating). For a CONS expr, eval checks car(expr) == 'quote
// and if so returns car(cdr(expr)) unevaluated -- the first dispatch
// on expression *shape*, not just atom tag. Anything else falls back
// to NIL (no other special forms exist until M14/M15).
module tb_eval_quote;

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
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_eval_quote.vcd");
            $dumpvars(0, tb_eval_quote);
        end

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd59);
        send_uart_byte(8'd0); // program length hi byte
        send_uart_word(32'h9100003C); // 0:  LOADSYM R1, 60 (dummy A)
        send_uart_word(32'h9200003D); // 1:  LOADSYM R2, 61 (dummy B)
        send_uart_word(32'h76120000); // 2:  EQ R6, R1, R2 -> NIL
        send_uart_word(32'h97000033); // 3:  LOADSYM R7, 51 ('radio)
        send_uart_word(32'h38760000); // 4:  CONS R8, R7, R6  (radio . NIL)
        send_uart_word(32'h99000032); // 5:  LOADSYM R9, 50 ('quote)
        send_uart_word(32'h3A980000); // 6:  CONS R10, R9, R8 (quote radio)
        send_uart_word(32'h23A00000); // 7:  MOV R3, R10 (expr)
        send_uart_word(32'h24600000); // 8:  MOV R4, R6  (env = NIL)
        send_uart_word(32'h8500001B); // 9:  CALL R5, eval(27)
        send_uart_word(32'h2B900000); // 10: MOV R11, R9 (save result1)
        send_uart_word(32'h91000005); // 11: LOADSYM R1, 5 ('x)
        send_uart_word(32'h1200000A); // 12: LOADI R2, 10
        send_uart_word(32'h93000006); // 13: LOADSYM R3, 6 ('y)
        send_uart_word(32'h14000014); // 14: LOADI R4, 20
        send_uart_word(32'h95000040); // 15: LOADSYM R5, 64 (dummy A2)
        send_uart_word(32'h96000041); // 16: LOADSYM R6, 65 (dummy B2)
        send_uart_word(32'h77560000); // 17: EQ R7, R5, R6 -> NIL
        send_uart_word(32'h38120000); // 18: CONS R8, R1, R2 (x . 10)
        send_uart_word(32'h39340000); // 19: CONS R9, R3, R4 (y . 20)
        send_uart_word(32'h3A970000); // 20: CONS R10, R9, R7 (pair2 . NIL)
        send_uart_word(32'h308A0000); // 21: CONS R0, R8, R10 env
        send_uart_word(32'h92000006); // 22: LOADSYM R2, 6 (expr2='y)
        send_uart_word(32'h23200000); // 23: MOV R3, R2
        send_uart_word(32'h24000000); // 24: MOV R4, R0
        send_uart_word(32'h8500001B); // 25: CALL R5, eval(27)
        send_uart_word(32'hB0000000); // 26: HALT
        send_uart_word(32'h66300000); // 27: eval: ATOM R6, R3
        send_uart_word(32'hA0600028); // 28: JF R6, is_cons(40)
        send_uart_word(32'h26310000); // 29: GETTAG R6, R3
        send_uart_word(32'h17000002); // 30: LOADI R7, 2
        send_uart_word(32'h78670000); // 31: EQ R8, R6, R7
        send_uart_word(32'hA0800026); // 32: JF R8, self_eval(38)
        send_uart_word(32'h2C300000); // 33: MOV R12, R3
        send_uart_word(32'h2D400000); // 34: MOV R13, R4
        send_uart_word(32'h8E000033); // 35: CALL R14, lookup(51)
        send_uart_word(32'h29F00000); // 36: MOV R9, R15
        send_uart_word(32'h80000032); // 37: JMP done(50)
        send_uart_word(32'h29300000); // 38: self_eval: MOV R9, R3
        send_uart_word(32'h80000032); // 39: JMP done(50)
        send_uart_word(32'h46300000); // 40: is_cons: CAR R6, R3
        send_uart_word(32'h97000032); // 41: LOADSYM R7, 50 ('quote)
        send_uart_word(32'h78670000); // 42: EQ R8, R6, R7
        send_uart_word(32'hA080002F); // 43: JF R8, not_quote(47)
        send_uart_word(32'h5A300000); // 44: CDR R10, R3
        send_uart_word(32'h49A00000); // 45: CAR R9, R10
        send_uart_word(32'h80000032); // 46: JMP done(50)
        send_uart_word(32'h96000046); // 47: not_quote: LOADSYM R6, 70
        send_uart_word(32'h97000047); // 48: LOADSYM R7, 71
        send_uart_word(32'h79670000); // 49: EQ R9, R6, R7 -> NIL
        send_uart_word(32'h80500000); // 50: done: RET R5
        send_uart_word(32'h40D00000); // 51: lookup: CAR R0, R13
        send_uart_word(32'h41000000); // 52: CAR R1, R0
        send_uart_word(32'h721C0000); // 53: EQ R2, R1, R12
        send_uart_word(32'hA0200039); // 54: JF R2, next(57)
        send_uart_word(32'h5F000000); // 55: CDR R15, R0
        send_uart_word(32'h80E00000); // 56: RET R14
        send_uart_word(32'h5DD00000); // 57: next: CDR R13, R13
        send_uart_word(32'h80000033); // 58: JMP lookup(51)

        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R11 (eval quote radio) = TAG:%0d VAL:%0d", u_mac.u_regs.regs[11][31:28], u_mac.u_regs.regs[11][27:0]);
        $display("R9  (eval 'y)          = TAG:%0d VAL:%0d", u_mac.u_regs.regs[9][31:28], u_mac.u_regs.regs[9][27:0]);

        if (u_mac.u_regs.regs[11][31:28] == TAG_SYMBOL && u_mac.u_regs.regs[11][27:0] == 28'd51 &&
            u_mac.u_regs.regs[9][31:28]  == TAG_FIXNUM && u_mac.u_regs.regs[9][27:0]  == 28'd20) begin
            $display("M13 PASSED: eval-quote (and atom-path regression) works");
        end else begin
            $display("M13 FAILED");
        end

        $finish;
    end

    initial begin
        #26_000_000; // watchdog (59-instruction upload alone takes ~20ms)
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

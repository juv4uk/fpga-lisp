`include "lisp_word.sv"

// M17 error recovery: a CAR/CDR/CONS type error (e.g. CAR of a
// non-CONS) used to hang forever in ST_WAIT_LDU since ldu_valid never
// pulses on error -- bit twice during eval development (M12, M16).
// Now it halts like HALT instead, and monitor command 0x04 reports
// {err_flag, err_pc} so the failure is diagnosable instead of a silent
// hang. Program: build NIL, then CAR it (pc=3) -- an unrecoverable
// type error since NIL isn't a CONS.
module tb_error_recovery;

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

    logic [31:0] word0;
    integer errors;

    initial begin
        $dumpfile("tb_error_recovery.vcd");
        $dumpvars(0, tb_error_recovery);

        errors = 0;
        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd4);
        send_uart_byte(8'd0); // program length hi byte
        send_uart_word(32'h91000000 | 16'd60); // 0: LOADSYM R1, 60
        send_uart_word(32'h92000000 | 16'd61); // 1: LOADSYM R2, 61
        send_uart_word(32'h73120000);          // 2: EQ R3, R1, R2 -> NIL
        send_uart_word(32'h44300000);          // 3: CAR R4, R3    -> type error

        wait(halted);
        #50;
        $display("Machine halted after the CAR-of-NIL type error (as expected).");

        // --- ERR command: expect err_flag=1, err_pc=3 ---
        fork
            send_uart_byte(8'h04);
            recv_word(word0);
        join
        $display("ERR = 0x%08x (err_flag=%0d err_pc=%0d)", word0, word0[12], word0[11:0]);
        if (word0[12] !== 1'b1 || word0[11:0] !== 12'd3) begin
            $display("FAIL: expected err_flag=1 err_pc=3");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("M17 PASSED: type errors halt cleanly and are diagnosable via monitor cmd 0x04");
        end else begin
            $display("M17 FAILED: %0d error(s)", errors);
        end

        $finish;
    end

    initial begin
        #3_000_000; // watchdog
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

    task recv_uart_byte(output [7:0] b);
        integer i;
        begin
            @(negedge uart_tx);
            #(8680 + 8680/2);
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = uart_tx;
                #(8680);
            end
        end
    endtask

    task recv_word(output [31:0] w);
        logic [7:0] b0, b1, b2, b3;
        begin
            recv_uart_byte(b0);
            recv_uart_byte(b1);
            recv_uart_byte(b2);
            recv_uart_byte(b3);
            w = {b3, b2, b1, b0};
        end
    endtask

endmodule

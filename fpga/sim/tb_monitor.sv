`include "lisp_word.sv"

// Post-HALT diagnostic monitor: REG / HEAP / HP commands over UART.
module tb_monitor;

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

    logic [7:0] rx_byte;
    logic [31:0] word0, word1;
    integer errors;

    initial begin
        $dumpfile("tb_monitor.vcd");
        $dumpvars(0, tb_monitor);

        errors = 0;
        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        // Program: LOADSYM R1,#2 ; LOADSYM R2,#3 ; CONS R3,R1,R2 ; HALT
        send_uart_byte(8'd4);
        send_uart_byte(8'd0); // program length hi byte
        send_uart_word(32'h91000002); // LOADSYM R1, #2
        send_uart_word(32'h92000003); // LOADSYM R2, #3
        send_uart_word(32'h33120000); // CONS R3, R1, R2
        send_uart_word(32'hB0000000); // HALT

        wait(halted);
        #50;

        // --- HP command: expect 1 (one CONS allocated) ---
        // fork/join: the DUT can start replying within a handful of clock
        // cycles, so the receiver must already be armed (waiting on the
        // negedge) before the send task finishes, not started after.
        fork
            send_uart_byte(8'h03);
            recv_word(word0);
        join
        $display("HP = 0x%08x", word0);
        if (word0 !== 32'd1) begin
            $display("FAIL: expected HP=1");
            errors = errors + 1;
        end

        // --- REG command: dump R3 (the CONS pointer, tag=1 value=0) ---
        fork
            begin
                send_uart_byte(8'h01);
                send_uart_byte(8'd3);
            end
            recv_word(word0);
        join
        $display("R3 = 0x%08x", word0);
        if (word0 !== 32'h10000000) begin
            $display("FAIL: expected R3=0x10000000");
            errors = errors + 1;
        end

        // --- HEAP command: dump heap[0] -> CAR (symbol #2), CDR (symbol #3) ---
        fork
            begin
                send_uart_byte(8'h02);
                send_uart_byte(8'd0); // addr lo
                send_uart_byte(8'd0); // addr hi
            end
            begin
                recv_word(word0); // CAR
                recv_word(word1); // CDR
            end
        join
        $display("HEAP[0] CAR=0x%08x CDR=0x%08x", word0, word1);
        if (word0 !== 32'h20000002 || word1 !== 32'h20000003) begin
            $display("FAIL: expected CAR=0x20000002 CDR=0x20000003");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("M08 PASSED: UART monitor (REG/HEAP/HP) works");
        end else begin
            $display("M08 FAILED: %0d error(s)", errors);
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

    // Bit-bang receive of one byte from uart_tx (board -> host direction)
    task recv_uart_byte(output [7:0] b);
        integer i;
        begin
            @(negedge uart_tx); // start bit begins
            #(8680 + 8680/2); // skip start bit, sample mid first data bit
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = uart_tx;
                #(8680);
            end
            // now in stop bit
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

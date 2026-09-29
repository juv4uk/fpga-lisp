`include "lisp_word.sv"

// ISA 1.4: exact HALT mode B0010000 is a target-owned Type trap.
module tb_type_trap;
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

    integer errors;
    initial begin
        errors = 0;
        uart_rx = 1;
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(8'd1);
        send_uart_byte(8'd0);
        send_uart_word(32'hB0010000);

        wait(halted);
        #50;

        if (u_mac.u_ctrl.err_flag !== 1'b1) begin
            $display("FAIL: Type trap did not latch err_flag");
            errors = errors + 1;
        end
        if (u_mac.u_ctrl.err_pc !== 12'd0) begin
            $display("FAIL: Type trap err_pc=%0d, expected 0", u_mac.u_ctrl.err_pc);
            errors = errors + 1;
        end
        if (errors == 0) begin
            $display("RESULT_ERROR:Type");
            $display("RESULT_ERROR_PC:%0d", u_mac.u_ctrl.err_pc);
            $display("TYPE-TRAP PASSED: B0010000 target mechanism");
        end
        else
            $display("TYPE-TRAP FAILED: %0d error(s)", errors);
        $finish;
    end

    initial begin
        #2_000_000;
        $display("WATCHDOG TIMEOUT: Type trap did not halt");
        $finish;
    end

    task send_uart_byte(input [7:0] b);
        integer i;
        begin
            uart_rx = 0;
            #(8680);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = b[i];
                #(8680);
            end
            uart_rx = 1;
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

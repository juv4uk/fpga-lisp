`include "lisp_word.sv"

// ============================================================================
// tb_upc8_machine.sv — End-to-end UPC-8 integration through lisp_machine
// ============================================================================
// Boots a program via UART that exercises the three encoded-mode MOV forms:
//   rs2=4 (UPC8_DECODE), rs2=5 (UPC8_TRANSFORM), rs2=6 (UPC8_PREDICATE).
// Checks register results after HALT.
// ============================================================================

module tb_upc8_machine;

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

    // Expect register values
    localparam [27:0] EXP_R2 = 28'h0000183; // decode 0x83: cc10=1, echo code
    localparam [27:0] EXP_R3 = 28'h0002182; // toggled length: valid + out=0x82
    localparam [27:0] EXP_R4 = 28'h0000780; // decode 0x80: ac_14+an_pred set
    localparam [27:0] EXP_R5 = 28'h0000007; // predicate 0x80: cc10+ac_14+an

    initial begin
        integer failures;
        failures = 0;
        uart_rx = 1; // Default to IDLE state
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        // Program: 8 instructions
        send_uart_byte(8'd8);
        send_uart_byte(8'd0); // program length hi byte

        // 0: LOADI R1, 0x83  -> 32'h11000083
        send_uart_word(32'h11000083);
        // 1: MOV R2, R1, rs2=4 (UPC8_DECODE)  -> 32'h22140000
        send_uart_word(32'h22140000);
        // 2: LOADI R1, 0x183 (op=001 toggle-length [10:8], code=0x83 [7:0]) -> 32'h11000183
        send_uart_word(32'h11000183);
        // 3: MOV R3, R1, rs2=5 (UPC8_TRANSFORM) -> 32'h23150000
        send_uart_word(32'h23150000);
        // 4: LOADI R1, 0x80 -> 32'h11000080
        send_uart_word(32'h11000080);
        // 5: MOV R4, R1, rs2=4 (UPC8_DECODE) -> 32'h24140000
        send_uart_word(32'h24140000);
        // 6: MOV R5, R1, rs2=6 (UPC8_PREDICATE) -> 32'h25160000
        send_uart_word(32'h25160000);
        // 7: HALT -> 32'hB0000000
        send_uart_word(32'hB0000000);

        // Wait until halted
        wait(halted);
        #50;

        $display("Machine Halted.");
        $display("R1 = TAG:%0d VAL:%h", u_mac.u_regs.regs[1][31:28], u_mac.u_regs.regs[1][27:0]);
        $display("R2 = TAG:%0d VAL:%h", u_mac.u_regs.regs[2][31:28], u_mac.u_regs.regs[2][27:0]);
        $display("R3 = TAG:%0d VAL:%h", u_mac.u_regs.regs[3][31:28], u_mac.u_regs.regs[3][27:0]);
        $display("R4 = TAG:%0d VAL:%h", u_mac.u_regs.regs[4][31:28], u_mac.u_regs.regs[4][27:0]);
        $display("R5 = TAG:%0d VAL:%h", u_mac.u_regs.regs[5][31:28], u_mac.u_regs.regs[5][27:0]);

        if (u_mac.u_regs.regs[2][31:28] != TAG_FIXNUM || u_mac.u_regs.regs[2][27:0] != EXP_R2) begin
            $display("FAIL R2 upc8-decode: got %h exp %h", u_mac.u_regs.regs[2][27:0], EXP_R2);
            failures = failures + 1;
        end else begin
            $display("PASS R2 upc8-decode 0x83 -> %h", EXP_R2);
        end

        if (u_mac.u_regs.regs[3][31:28] != TAG_FIXNUM || u_mac.u_regs.regs[3][27:0] != EXP_R3) begin
            $display("FAIL R3 upc8-transform: got %h exp %h", u_mac.u_regs.regs[3][27:0], EXP_R3);
            failures = failures + 1;
        end else begin
            $display("PASS R3 upc8-transform toggle-length -> %h", EXP_R3);
        end

        if (u_mac.u_regs.regs[4][31:28] != TAG_FIXNUM || u_mac.u_regs.regs[4][27:0] != EXP_R4) begin
            $display("FAIL R4 upc8-decode ac14: got %h exp %h", u_mac.u_regs.regs[4][27:0], EXP_R4);
            failures = failures + 1;
        end else begin
            $display("PASS R4 upc8-decode ac14 0x80 -> %h", EXP_R4);
        end

        if (u_mac.u_regs.regs[5][31:28] != TAG_FIXNUM || u_mac.u_regs.regs[5][27:0] != EXP_R5) begin
            $display("FAIL R5 upc8-predicate: got %h exp %h", u_mac.u_regs.regs[5][27:0], EXP_R5);
            failures = failures + 1;
        end else begin
            $display("PASS R5 upc8-predicate 0x80 -> %h", EXP_R5);
        end

        if (failures == 0) begin
            $display("=== UPC-8 machine integration: ALL PASS ===");
            $finish;
        end else begin
            $display("=== UPC-8 machine integration: %0d FAIL ===", failures);
            $fatal(1, "UPC-8 machine integration FAILED");
        end
    end

    task send_uart_byte(input [7:0] b);
        integer i;
        begin
            uart_rx = 0; // Start bit
            #(8680); // 1 / 115200 * 1e9 ns = 8680.5 ns
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
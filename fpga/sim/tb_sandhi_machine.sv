`include "lisp_word.sv"

// ============================================================================
// tb_sandhi_machine.sv — End-to-end sandhi engine through lisp_machine
// ============================================================================
// Boots via UART a program using MOV rs1->rd, rs2=7 (UPC8_SANDHI):
//   input  pair  = rs1.value[15:8] = prev_code, [7:0] = curr_code
//   output value = rd.value[17:16] = result_mode,
//                  [15:8] = result_1, [7:0] = result_0
// Checks register results after HALT.
// ============================================================================

module tb_sandhi_machine;

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

    // Expected outcomes (packed 28-bit values):
    // yaṇ:   MODE=10, result_1=curr, result_0=y/v
    // GUNA:  a+i->e  MODE=01, result_1=0, result_0=0xA8(e)
    // SAV:   aa+a->aa MODE=01, result_1=0, result_0=0x81(a)
    //	(passth) k+a -> MODE=00, pair unchanged
    localparam [27:0] EXP_R2 = 28'h002800A; // i+a -> y, a  (0x0A, 0x80)
    localparam [27:0] EXP_R3 = 28'h000100A8; // a+i -> e     (0xA8)
    localparam [27:0] EXP_R4 = 28'h00010081; // aa+a -> aa   (0x81)
    localparam [27:0] EXP_R5 = 28'h00008023; // k+a passthrough (0x23, 0x80)

    initial begin
        integer failures;
        integer cycle_count;
        failures = 0;
        uart_rx = 1; // Default to IDLE state
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        // Program: 9 instructions
        send_uart_byte(8'd9);
        send_uart_byte(8'd0); // program length hi byte

        // 0: LOADI R1, 0x8880 (prev=i 0x88, curr=a 0x80) -> 32'h11008880
        send_uart_word(32'h11008880);
        // 1: MOV R2, R1, rs2=7 (UPC8_SANDHI) -> 32'h22170000
        send_uart_word(32'h22170000);
        // 2: LOADI R1, 0x8088 (prev=a, curr=i) -> 32'h11008088
        send_uart_word(32'h11008088);
        // 3: MOV R3, R1, rs2=7 -> 32'h23170000
        send_uart_word(32'h23170000);
        // 4: LOADI R1, 0x8180 (prev=aa, curr=a) -> 32'h11008180
        send_uart_word(32'h11008180);
        // 5: MOV R4, R1, rs2=7 -> 32'h24170000
        send_uart_word(32'h24170000);
        // 6: LOADI R1, 0x2380 (prev=k 0x23, curr=a) -> 32'h11002380
        send_uart_word(32'h11002380);
        // 7: MOV R5, R1, rs2=7 -> 32'h25170000
        send_uart_word(32'h25170000);
        // 8: HALT -> 32'hB0000000
        send_uart_word(32'hB0000000);

        // Wait until halted with timeout
        cycle_count = 0;
        while (!halted && cycle_count < 500000) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (cycle_count % 50000 == 0) begin
                $display("DEBUG: cycle=%0d, state=%0d, pc=%0d, halted=%b, sandhi_done=%b",
                    cycle_count, u_mac.u_ctrl.state, u_mac.u_ctrl.pc, halted,
                    u_mac.u_ctrl.u_sandhi.done);
            end
        end
        
        if (!halted) begin
            $display("TIMEOUT: machine did not halt after %0d cycles", cycle_count);
            $fatal(1, "TIMEOUT");
        end

        #50;

        $display("Machine Halted.");
        $display("R1 = TAG:%0d VAL:%h", u_mac.u_regs.regs[1][31:28], u_mac.u_regs.regs[1][27:0]);
        $display("R2 = TAG:%0d VAL:%h", u_mac.u_regs.regs[2][31:28], u_mac.u_regs.regs[2][27:0]);
        $display("R3 = TAG:%0d VAL:%h", u_mac.u_regs.regs[3][31:28], u_mac.u_regs.regs[3][27:0]);
        $display("R4 = TAG:%0d VAL:%h", u_mac.u_regs.regs[4][31:28], u_mac.u_regs.regs[4][27:0]);
        $display("R5 = TAG:%0d VAL:%h", u_mac.u_regs.regs[5][31:28], u_mac.u_regs.regs[5][27:0]);

        if (u_mac.u_regs.regs[2][31:28] != TAG_FIXNUM || u_mac.u_regs.regs[2][27:0] != EXP_R2) begin
            $display("FAIL R2 sandhi i+a: got %h exp %h", u_mac.u_regs.regs[2][27:0], EXP_R2);
            failures = failures + 1;
        end else begin
            $display("PASS R2 sandhi i+a -> y+a (%h)", EXP_R2);
        end

        if (u_mac.u_regs.regs[3][31:28] != TAG_FIXNUM || u_mac.u_regs.regs[3][27:0] != EXP_R3) begin
            $display("FAIL R3 sandhi a+i: got %h exp %h", u_mac.u_regs.regs[3][27:0], EXP_R3);
            failures = failures + 1;
        end else begin
            $display("PASS R3 sandhi a+i -> e (%h)", EXP_R3);
        end

        if (u_mac.u_regs.regs[4][31:28] != TAG_FIXNUM || u_mac.u_regs.regs[4][27:0] != EXP_R4) begin
            $display("FAIL R4 sandhi aa+a: got %h exp %h", u_mac.u_regs.regs[4][27:0], EXP_R4);
            failures = failures + 1;
        end else begin
            $display("PASS R4 sandhi aa+a -> aa (%h)", EXP_R4);
        end

        if (u_mac.u_regs.regs[5][31:28] != TAG_FIXNUM || u_mac.u_regs.regs[5][27:0] != EXP_R5) begin
            $display("FAIL R5 sandhi k+a: got %h exp %h", u_mac.u_regs.regs[5][27:0], EXP_R5);
            failures = failures + 1;
        end else begin
            $display("PASS R5 sandhi k+a passthrough (%h)", EXP_R5);
        end

        if (failures == 0) begin
            $display("=== Sandhi machine integration: ALL PASS ===");
            $finish;
        end else begin
            $display("=== Sandhi machine integration: %0d FAIL ===", failures);
            $fatal(1, "Sandhi machine integration FAILED");
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
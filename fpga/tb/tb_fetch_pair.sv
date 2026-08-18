`include "lisp_word.sv"

// Testbench for FETCH_PAIR: verifies CAR+CDR are both returned correctly
// AND that the instruction following FETCH_PAIR executes (PC invariant).
//
// Program:
//   0: LOADI   R1, 10       (fixnum 10)
//   1: LOADI   R2, 20       (fixnum 20)
//   2: CONS    R3, R1, R2   (heap[0] = (10 . 20))
//   3: CAR     R4, R3, R5   (FETCH_PAIR: R4=CAR=10, R5=CDR=20)
//   4: LOADI   R6, 123      (if PC skipped, R6 won't be set)
//   5: HALT
//
// Pass conditions:
//   R4.tag == TAG_FIXNUM && R4.value == 10
//   R5.tag == TAG_FIXNUM && R5.value == 20
//   R6.tag == TAG_FIXNUM && R6.value == 123
//
// If R6 != 123, the double-PC++ bug is present.
//
// Loads through the real UART bootloader, same as every other
// testbench in this repo (tb_bootstrap_add.sv etc.) -- an earlier
// version of this file tried to bypass the bootloader by white-box
// poking dut.boot_done/dut.u_ctrl.state directly. That approach never
// actually compiled under iverilog (only ever verified against a
// Python behavioral model, not real RTL -- see
// docs/test-report-2026-08-17.md's own MODEL-PASS-not-RTL-SIM-PASS
// caveat): `boot_done` is a wire continuously driven by the
// bootloader submodule's output port, and `state` is an enum-typed
// signal iverilog won't accept a bare bit-literal assignment to from
// outside its declaring module, even under `force` -- and there's no
// way to name `state_t` hierarchically from a testbench to cast
// against it. Going through the real bootloader avoids both problems
// and matches how this machine is actually used.

module tb_fetch_pair;

    logic clk;
    logic rst_n;
    logic halted;
    logic uart_tx;
    logic uart_rx;

    lisp_machine dut (
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

    // Instruction encoding helpers. Format per instruction_decoder.sv
    // (the authoritative layout -- an earlier version of this file had
    // opcode/operand positions backwards, e.g. opcode at [3:0] instead
    // of [31:28], which silently produced NOP/garbage instructions and
    // made the whole test hang on wait(halted) with no compile-time
    // signal anything was wrong):
    //   [31:28] opcode | [27:24] rd | [23:20] rs1 | [19:16] rs2 | [15:0] imm
    function [31:0] encode_3r(input [3:0] op, input [3:0] rd, input [3:0] rs1, input [3:0] rs2);
        encode_3r = {op, rd, rs1, rs2, 16'b0};
    endfunction

    function [31:0] encode_imm(input [3:0] op, input [3:0] rd, input [15:0] imm);
        encode_imm = {op, rd, 8'b0, imm};
    endfunction

    // Opcode constants -- must match instruction_decoder.sv's opcode_t
    // enum exactly. An earlier version of this file had these wrong
    // (OP_CONS/OP_CAR/OP_HALT all off by one or more) -- the exact class
    // of bug this file's own original header comment warned about for
    // TAG_* constants, now found in OP_* too. Values below verified
    // directly against instruction_decoder.sv, 2026-08-18.
    localparam OP_LOADI = 4'd1;
    localparam OP_CONS  = 4'd3;
    localparam OP_CAR   = 4'd4;
    localparam OP_HALT  = 4'd11;

    localparam int N_WORDS = 6;
    logic [31:0] prog_words [0:N_WORDS-1];
    byte prog_bytes [0:N_WORDS*4-1];

    initial begin
        prog_words[0] = encode_imm(OP_LOADI, 4'd1, 16'd10);   // R1 = 10
        prog_words[1] = encode_imm(OP_LOADI, 4'd2, 16'd20);   // R2 = 20
        prog_words[2] = encode_3r(OP_CONS, 4'd3, 4'd1, 4'd2);  // R3 = (cons R1 R2)
        prog_words[3] = encode_3r(OP_CAR, 4'd4, 4'd3, 4'd5);   // FETCH_PAIR R4,R3,R5
        prog_words[4] = encode_imm(OP_LOADI, 4'd6, 16'd123);   // R6 = 123 (PC skip detector)
        prog_words[5] = encode_3r(OP_HALT, 4'd0, 4'd0, 4'd0);  // HALT

        for (int i = 0; i < N_WORDS; i = i + 1) begin
            prog_bytes[i*4]   = prog_words[i][7:0];
            prog_bytes[i*4+1] = prog_words[i][15:8];
            prog_bytes[i*4+2] = prog_words[i][23:16];
            prog_bytes[i*4+3] = prog_words[i][31:24];
        end

        uart_rx = 1; // IDLE
        rst_n = 0;
        #20 rst_n = 1;
        #100;

        send_uart_byte(N_WORDS[7:0]);
        send_uart_byte(N_WORDS[15:8]);
        for (int i = 0; i < N_WORDS*4; i = i + 1) begin
            send_uart_byte(prog_bytes[i]);
        end

        wait(halted);
        #50;

        $display("=== FETCH_PAIR Testbench Results ===");
        $display("");

        // R4 should be CAR of (10 . 20) = fixnum 10
        $display("R4: tag=%0d value=%0d (expected tag=%0d value=10)",
                 dut.u_regs.regs[4][31:28], dut.u_regs.regs[4][27:0], TAG_FIXNUM);
        if (dut.u_regs.regs[4][31:28] == TAG_FIXNUM && dut.u_regs.regs[4][27:0] == 28'd10)
            $display("  PASS: R4 = CAR = 10");
        else
            $display("  FAIL: R4 != 10");

        // R5 should be CDR of (10 . 20) = fixnum 20
        $display("R5: tag=%0d value=%0d (expected tag=%0d value=20)",
                 dut.u_regs.regs[5][31:28], dut.u_regs.regs[5][27:0], TAG_FIXNUM);
        if (dut.u_regs.regs[5][31:28] == TAG_FIXNUM && dut.u_regs.regs[5][27:0] == 28'd20)
            $display("  PASS: R5 = CDR = 20");
        else
            $display("  FAIL: R5 != 20");

        // R6 should be 123 -- this verifies PC wasn't skipped
        $display("R6: tag=%0d value=%0d (expected tag=%0d value=123)",
                 dut.u_regs.regs[6][31:28], dut.u_regs.regs[6][27:0], TAG_FIXNUM);
        if (dut.u_regs.regs[6][31:28] == TAG_FIXNUM && dut.u_regs.regs[6][27:0] == 28'd123)
            $display("  PASS: R6 = 123 (next instruction executed)");
        else
            $display("  FAIL: R6 != 123 (FETCH_PAIR skipped next instruction!)");

        $display("");

        if (dut.u_regs.regs[4][31:28] == TAG_FIXNUM && dut.u_regs.regs[4][27:0] == 28'd10 &&
            dut.u_regs.regs[5][31:28] == TAG_FIXNUM && dut.u_regs.regs[5][27:0] == 28'd20 &&
            dut.u_regs.regs[6][31:28] == TAG_FIXNUM && dut.u_regs.regs[6][27:0] == 28'd123)
            $display("OVERALL: ALL TESTS PASSED");
        else
            $display("OVERALL: TESTS FAILED");

        $finish;
    end

    initial begin
        #50_000_000;
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

endmodule

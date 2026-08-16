`timescale 1ns / 1ps
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
// NOTE: TAG_* constants come from lisp_word.sv (via `include).
//       Do NOT duplicate them locally — that caused a bug where
//       TAG_FIXNUM was 2 here but 0 in the actual ISA.
//
//       OP_* constants are local because opcodes are not yet
//       defined in a shared include file. If they ever are,
//       remove these and use the authoritative ones.

module tb_fetch_pair;

    logic clk = 0;
    logic rst_n = 0;
    logic halted;
    logic uart_tx_out;

    // Instruction encoding helpers
    // Format: [3:0] opcode | [7:4] rd | [11:8] rs1 | [15:12] rs2 | [31:16] imm
    function [31:0] encode_3r(input [3:0] op, input [3:0] rd, input [3:0] rs1, input [3:0] rs2);
        encode_3r = {16'b0, rs2, rs1, rd, op};
    endfunction

    function [31:0] encode_imm(input [3:0] op, input [3:0] rd, input [15:0] imm);
        encode_imm = {imm, 4'b0, 4'b0, rd, op};
    endfunction

    // Opcode constants — must match instruction_decoder.sv
    localparam OP_LOADI = 4'h1;
    localparam OP_CONS  = 4'h4;
    localparam OP_CAR   = 4'h5;
    localparam OP_HALT  = 4'hF;

    // TAG_* come from lisp_word.sv — no local duplicates

    lisp_machine dut (
        .clk(clk),
        .rst_n(rst_n),
        .halted(halted),
        .uart_rx_in(1'b1),   // idle high
        .uart_tx_out(uart_tx_out)
    );

    // Clock
    always #5 clk = ~clk;

    // Test program
    initial begin
        #20 rst_n = 1;
        #100;

        // Force boot_done so cpu_rst_n goes high
        dut.boot_done = 1;
        #2;

        // Load program directly into IMEM
        dut.imem[0] = encode_imm(OP_LOADI, 4'd1, 16'd10);    // R1 = 10
        dut.imem[1] = encode_imm(OP_LOADI, 4'd2, 16'd20);    // R2 = 20
        dut.imem[2] = encode_3r(OP_CONS, 4'd3, 4'd1, 4'd2);   // R3 = (cons R1 R2)
        dut.imem[3] = encode_3r(OP_CAR, 4'd4, 4'd3, 4'd5);    // FETCH_PAIR R4,R3,R5
        dut.imem[4] = encode_imm(OP_LOADI, 4'd6, 16'd123);    // R6 = 123 (PC skip detector)
        dut.imem[5] = encode_3r(OP_HALT, 4'd0, 4'd0, 4'd0);   // HALT

        // Reset PC to 0
        // ST_FETCH = 0 in the state_t enum (control.sv).
        // Cannot use dut.u_ctrl.ST_FETCH — iverilog does not support
        // hierarchical access to enum/localparam members.
        dut.u_ctrl.pc = 0;
        dut.u_ctrl.state = 5'd0;

        // Run
        #5000;

        $display("=== FETCH_PAIR Testbench Results ===");
        $display("");

        // R4 should be CAR of (10 . 20) = fixnum 10
        $display("R4: tag=%0d value=%0d (expected tag=%0d value=10)",
                 dut.u_regs.regs[4].tag, dut.u_regs.regs[4].value, TAG_FIXNUM);
        if (dut.u_regs.regs[4].tag == TAG_FIXNUM && dut.u_regs.regs[4].value == 28'd10)
            $display("  PASS: R4 = CAR = 10");
        else
            $display("  FAIL: R4 != 10");

        // R5 should be CDR of (10 . 20) = fixnum 20
        $display("R5: tag=%0d value=%0d (expected tag=%0d value=20)",
                 dut.u_regs.regs[5].tag, dut.u_regs.regs[5].value, TAG_FIXNUM);
        if (dut.u_regs.regs[5].tag == TAG_FIXNUM && dut.u_regs.regs[5].value == 28'd20)
            $display("  PASS: R5 = CDR = 20");
        else
            $display("  FAIL: R5 != 20");

        // R6 should be 123 — this verifies PC wasn't skipped
        $display("R6: tag=%0d value=%0d (expected tag=%0d value=123)",
                 dut.u_regs.regs[6].tag, dut.u_regs.regs[6].value, TAG_FIXNUM);
        if (dut.u_regs.regs[6].tag == TAG_FIXNUM && dut.u_regs.regs[6].value == 28'd123)
            $display("  PASS: R6 = 123 (next instruction executed)");
        else
            $display("  FAIL: R6 != 123 (FETCH_PAIR skipped next instruction!)");

        $display("");

        if (dut.u_regs.regs[4].tag == TAG_FIXNUM && dut.u_regs.regs[4].value == 28'd10 &&
            dut.u_regs.regs[5].tag == TAG_FIXNUM && dut.u_regs.regs[5].value == 28'd20 &&
            dut.u_regs.regs[6].tag == TAG_FIXNUM && dut.u_regs.regs[6].value == 28'd123)
            $display("OVERALL: ALL TESTS PASSED");
        else
            $display("OVERALL: TESTS FAILED");

        $finish;
    end

endmodule

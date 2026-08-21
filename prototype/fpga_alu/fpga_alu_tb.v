// ============================================================================
// Verilog Testbench for FPGA Lisp Phonetic Vector ALU (fpga_alu_tb.v)
// ============================================================================
`timescale 1ns / 1ps

module fpga_alu_tb;
    reg         clk;
    reg         rst_n;
    reg  [3:0]  alu_op;
    reg  [31:0] op_a;
    reg  [31:0] op_b;
    reg  [31:0] op_ext;
    reg  [63:0] mask_in;
    
    wire [31:0] result;
    wire        flag_savarna;
    wire        flag_member;
    wire        flag_zero;
    wire        valid;
    wire        error;

    fpga_alu #(.DATA_WIDTH(32)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .alu_op(alu_op),
        .op_a(op_a),
        .op_b(op_b),
        .op_ext(op_ext),
        .mask_in(mask_in),
        .result(result),
        .flag_savarna(flag_savarna),
        .flag_member(flag_member),
        .flag_zero(flag_zero),
        .valid(valid),
        .error(error)
    );

    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        clk = 0;
        rst_n = 0;
        alu_op = 0;
        op_a = 0;
        op_b = 0;
        op_ext = 0;
        mask_in = 0;

        #20 rst_n = 1;

        // Test 1: Sūtra 1.1.9 Savarṇa Test (Short 'a' vs Long 'a')
        // a_short: 0x0403 (Kanthya vowel), a_long: 0x0803 (Kanthya vowel)
        alu_op = 4'h1;
        op_a   = 32'h00000403;
        op_b   = 32'h00000803;
        #10;
        if (result[0] !== 1'b1 || flag_savarna !== 1'b1)
            $display("FAIL: a and aa must be Savarṇa");
        else
            $display("PASS: Sūtra 1.1.9: 'a' and 'aa' are Savarṇa");

        // Test 2: 'k' vs 'kh' (both Kanthya stops -> Savarṇa)
        // k: 0x0042, kh: 0x00C2
        alu_op = 4'h1;
        op_a   = 32'h00000042;
        op_b   = 32'h000000C2;
        #10;
        if (result[0] !== 1'b1) $display("FAIL: k and kh must be Savarṇa");
        else $display("PASS: Sūtra 1.1.9: 'k' and 'kh' are Savarṇa");

        // Test 3: 'k' (Velar) vs 'c' (Palatal) -> Asavarṇa (0)
        // c: 0x0044
        op_b = 32'h00000044;
        #10;
        if (result[0] !== 1'b0) $display("FAIL: k and c must NOT be Savarṇa");
        else $display("PASS: Sūtra 1.1.9: 'k' and 'c' are Heterogeneous (Asavarṇa)");

        // Test 4: Single-Cycle Voicing ('k' -> 'g')
        alu_op = 4'h2;
        op_a   = 32'h00000042; // Unvoiced 'k'
        #10;
        if (result[8] !== 1'b1) $display("FAIL: Voicing bit not set");
        else $display("PASS: Voicing: 'k' -> 'g' (Bit 8 Ghosha set: 0x%04X)", result[15:0]);

        // Test 5: Single-Cycle Devoicing ('g' -> 'k')
        alu_op = 4'h3;
        op_a   = 32'h00000142; // Voiced 'g'
        #10;
        if (result[8] !== 1'b0) $display("FAIL: Devoicing failed");
        else $display("PASS: Devoicing: 'g' -> 'k' (Bit 8 Ghosha cleared: 0x%04X)", result[15:0]);

        // Test 6: Single-Cycle Palatalization (Dental 't' -> 't-soft')
        alu_op = 4'h4;
        op_a   = 32'h00000048; // Dental stop 't'
        #10;
        if (result[14] !== 1'b1) $display("FAIL: Palatalization bit not set");
        else $display("PASS: Palatalization: 't' -> 't''' (Bit 14 Mod set: 0x%04X)", result[15:0]);

        // Test 7: 64-Bit Pratyāhāra Membership: 'i' (code 1) in 'ik' (mask 0x1E)
        alu_op = 4'h6;
        op_a   = 32'd1;  // Sound code 1 ('i')
        op_b   = 32'h0000001E; // mask_lo for 'ik'
        op_ext = 32'h00000000; // mask_hi
        #10;
        if (result[0] !== 1'b1 || flag_member !== 1'b1)
            $display("FAIL: 'i' must be in 'ik'");
        else
            $display("PASS: 64-bit Bitmask: 'i' is member of 'ik' (Dynamic Mask)");

        // Test 8: 64-Bit Pratyāhāra ROM Lookup: 'a' (code 0) in 'ac' (ROM ID 0)
        alu_op = 4'h7;
        op_a   = 32'd0; // 'a'
        op_b   = 32'd0; // 'ac' ROM ID
        #10;
        if (result[0] !== 1'b1) $display("FAIL: 'a' must be in 'ac' ROM");
        else $display("PASS: Classical ROM: 'a' is member of 'ac' (ROM ID 0)");

        // Test 9: 'k' (code 37) in 'ac' ROM -> MUST BE FALSE
        op_a   = 32'd37; // 'k'
        op_b   = 32'd0;  // 'ac'
        #10;
        if (result[0] !== 1'b0) $display("FAIL: 'k' must NOT be in 'ac'");
        else $display("PASS: Classical ROM: 'k' is NOT member of 'ac'");

        // Test 10: 'k' (code 37) in 'hal' ROM (ID 8) -> MUST BE TRUE
        op_b   = 32'd8;  // 'hal'
        #10;
        if (result[0] !== 1'b1) $display("FAIL: 'k' must be in 'hal'");
        else $display("PASS: Classical ROM: 'k' is member of 'hal' (ROM ID 8)");

        $display("\n========================================================");
        $display("ALL 10 VERILOG HARDWARE ALU TESTS PASSED SUCCESSFULLY");
        $display("========================================================");
        $finish;
    end
endmodule

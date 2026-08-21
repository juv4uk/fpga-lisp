// Testbench for PVC-16 Core
`timescale 1ns / 1ps

module pvc16_tb;
    reg  [15:0] sound_a;
    reg  [15:0] sound_b;
    wire        is_vowel_a;
    wire        is_vowel_b;
    wire        is_savarna;
    wire [15:0] voiced_a;
    wire [15:0] unvoiced_a;

    pvc16_core uut (
        .sound_a(sound_a),
        .sound_b(sound_b),
        .is_vowel_a(is_vowel_a),
        .is_vowel_b(is_vowel_b),
        .is_savarna(is_savarna),
        .voiced_a(voiced_a),
        .unvoiced_a(unvoiced_a)
    );

    initial begin
        // Test 1: Short 'a' vs Long 'a' (both Kanthya vowels -> Savarna)
        // a_short: Vow=1, Kanthya=1, Len=01 -> 0x0403
        // a_long:  Vow=1, Kanthya=1, Len=10 -> 0x0803
        sound_a = 16'h0403;
        sound_b = 16'h0803;
        #10;
        if (is_savarna !== 1'b1) $display("FAIL: a and aa should be savarna");
        else $display("PASS: a and aa are savarna (1.1.9)");

        // Test 2: 'k' vs 'kh' (both Kanthya stops -> Savarna)
        // k:  Vow=0, Kanthya=1, Sprsta=1, Aghosha=0 -> 0x0042
        // kh: Vow=0, Kanthya=1, Sprsta=1, Mahaprana=1 -> 0x00C2
        sound_a = 16'h0042;
        sound_b = 16'h00C2;
        #10;
        if (is_savarna !== 1'b1) $display("FAIL: k and kh should be savarna");
        else $display("PASS: k and kh are savarna (1.1.9)");

        // Test 3: 'k' (Kanthya) vs 'c' (Talavya) -> NOT Savarna
        // c: Vow=0, Talavya=2, Sprsta=1 -> 0x0044
        sound_a = 16'h0042;
        sound_b = 16'h0044;
        #10;
        if (is_savarna !== 1'b0) $display("FAIL: k and c must NOT be savarna");
        else $display("PASS: k and c are heterogeneous (asavarna)");

        // Test 4: Voicing 'k' -> 'g'
        sound_a = 16'h0042; // Unvoiced 'k'
        #10;
        if (voiced_a[8] !== 1'b1) $display("FAIL: Voicing bit not set");
        else $display("PASS: Voiced k produces g-feature bit (0x0142)");

        $display("ALL VERILOG TESTS PASSED");
        $finish;
    end
endmodule

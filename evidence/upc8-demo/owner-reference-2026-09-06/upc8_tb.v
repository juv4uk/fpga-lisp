// ============================================================================
// upc8_tb.v — UPC-8 Decode & Transform Testbench
// ============================================================================
// Golden values derived from upc8_class10_check.py (Python validation).
// Run with: iverilog -g2012 -o upc8_tb.vvp upc8_decode.v upc8_transform.v upc8_tb.v
//           vvp upc8_tb.vvp
// ============================================================================

`timescale 1ns / 1ps

module upc8_tb;

    // ------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------------
    reg  [7:0] code;
    wire [1:0] cls;
    wire [2:0] row;
    wire       free_bit, nasal, length;
    wire       is_class10, is_class00, is_class01, is_class11;
    wire       ac_14, an_pred, ik_pred, is_reserved_row;

    reg  [2:0] op;
    wire [7:0] code_out;
    wire       valid, error;

    // ------------------------------------------------------------------------
    // DUT instances
    // ------------------------------------------------------------------------
    upc8_decode decode (
        .code(code),
        .cls(cls),
        .row(row),
        .free_bit(free_bit),
        .nasal(nasal),
        .length(length),
        .is_class10(is_class10),
        .is_class00(is_class00),
        .is_class01(is_class01),
        .is_class11(is_class11),
        .ac_14(ac_14),
        .an_pred(an_pred),
        .ik_pred(ik_pred),
        .is_reserved_row(is_reserved_row)
    );

    upc8_transform transform (
        .code_in(code),
        .op(op),
        .code_out(code_out),
        .valid(valid),
        .error(error)
    );

    // ------------------------------------------------------------------------
    // Test tracking
    // ------------------------------------------------------------------------
    integer tests_run = 0;
    integer tests_passed = 0;
    integer tests_failed = 0;

    task check;
        input expected;
        input actual;
        input [255:0] msg;
        begin
            tests_run = tests_run + 1;
            if (expected === actual) begin
                tests_passed = tests_passed + 1;
            end else begin
                tests_failed = tests_failed + 1;
                $display("FAIL: %0s (expected %b, got %b)", msg, expected, actual);
            end
        end
    endtask

    task check_8;
        input [7:0] expected;
        input [7:0] actual;
        input [255:0] msg;
        begin
            tests_run = tests_run + 1;
            if (expected === actual) begin
                tests_passed = tests_passed + 1;
            end else begin
                tests_failed = tests_failed + 1;
                $display("FAIL: %0s (expected 0x%02X, got 0x%02X)", msg, expected, actual);
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------------------
    initial begin
        $display("========================================");
        $display("UPC-8 Decode & Transform Testbench");
        $display("========================================");

        // ================================================================
        // TEST SUITE 1: Field extraction for all 28 class-10 codes
        // ================================================================
        $display("\n--- Test Suite 1: Class 10 field extraction ---");

        // Row 0: a (0x80), ā (0x81), aṃ (0x82), āṃ (0x83)
        code = 8\'h80; #1;
        check_8(2\'b10, cls, "cls for 0x80");
        check_8(3\'d0, row, "row for 0x80");
        check(1\'b0, free_bit, "free for 0x80");
        check(1\'b0, nasal, "nasal for 0x80");
        check(1\'b0, length, "length for 0x80");
        check(1\'b1, is_class10, "is_class10 for 0x80");
        check(1\'b1, ac_14, "ac_14 for 0x80 (short a)");
        check(1\'b1, an_pred, "an_pred for 0x80");
        check(1\'b0, ik_pred, "ik_pred for 0x80");

        code = 8\'h81; #1;
        check(1\'b1, length, "length for 0x81 (long a)");
        check(1\'b1, ac_14, "ac_14 for 0x81");
        check(1\'b1, an_pred, "an_pred for 0x81");

        code = 8\'h82; #1;
        check(1\'b1, nasal, "nasal for 0x82");
        check(1\'b0, ac_14, "ac_14 for 0x82 (nasal excluded)");

        code = 8\'h83; #1;
        check(1\'b1, nasal, "nasal for 0x83");
        check(1\'b1, length, "length for 0x83");

        // Row 1: i (0x88), ī (0x89)
        code = 8\'h88; #1;
        check_8(3\'d1, row, "row for 0x88 (i)");
        check(1\'b1, ac_14, "ac_14 for 0x88");
        check(1\'b1, an_pred, "an_pred for 0x88");
        check(1\'b1, ik_pred, "ik_pred for 0x88");

        // Row 2: u (0x90), ū (0x91)
        code = 8\'h90; #1;
        check_8(3\'d2, row, "row for 0x90 (u)");
        check(1\'b1, ik_pred, "ik_pred for 0x90");

        // Row 3: ṛ (0x98), ṝ (0x99)
        code = 8\'h98; #1;
        check_8(3\'d3, row, "row for 0x98 (ṛ)");
        check(1\'b1, an_pred, "an_pred for 0x98");
        check(1\'b1, ik_pred, "ik_pred for 0x98");

        // Row 4: ḷ (0xA0), ḹ (0xA1)
        code = 8\'hA0; #1;
        check_8(3\'d4, row, "row for 0xA0 (ḷ)");
        check(1\'b1, an_pred, "an_pred for 0xA0");
        check(1\'b1, ik_pred, "ik_pred for 0xA0");

        // Row 5: e (0xA8), ai (0xA9)
        code = 8\'hA8; #1;
        check_8(3\'d5, row, "row for 0xA8 (e)");
        check(1\'b1, ac_14, "ac_14 for 0xA8");
        check(1\'b0, an_pred, "an_pred for 0xA8 (e not in aṇ)");

        // Row 6: o (0xB0), au (0xB1)
        code = 8\'hB0; #1;
        check_8(3\'d6, row, "row for 0xB0 (o)");
        check(1\'b1, ac_14, "ac_14 for 0xB0");

        // Row 7: reserved (0xB8–0xBF)
        code = 8\'hB8; #1;
        check_8(3\'d7, row, "row for 0xB8 (reserved)");
        check(1\'b1, is_reserved_row, "is_reserved_row for 0xB8");
        check(1\'b0, ac_14, "ac_14 for 0xB8 (reserved excluded)");

        // Non-class-10: 0x00 (canonical a)
        code = 8\'h00; #1;
        check(1\'b0, is_class10, "is_class10 for 0x00");
        check(1\'b0, ac_14, "ac_14 for 0x00 (not class 10)");
        check(1\'b1, is_class00, "is_class00 for 0x00");

        // ================================================================
        // TEST SUITE 2: Transform — toggle length
        // ================================================================
        $display("\n--- Test Suite 2: TOGGLE_LENGTH ---");
        op = 3\'b001;

        code = 8\'h80; #1;  // a -> ā
        check_8(8\'h81, code_out, "toggle length 0x80 -> 0x81");
        check(1\'b1, valid, "valid for toggle length");
        check(1\'b0, error, "error for toggle length");

        code = 8\'h81; #1;  // ā -> a
        check_8(8\'h80, code_out, "toggle length 0x81 -> 0x80");

        code = 8\'h82; #1;  // nasal a -> nasal ā
        check_8(8\'h83, code_out, "toggle length 0x82 -> 0x83");

        // Non-class-10 should error
        code = 8\'h00; #1;
        check(1\'b1, error, "error for toggle length on 0x00");

        // ================================================================
        // TEST SUITE 3: Transform — toggle nasal
        // ================================================================
        $display("\n--- Test Suite 3: TOGGLE_NASAL ---");
        op = 3\'b010;

        code = 8\'h80; #1;  // a -> aṃ
        check_8(8\'h82, code_out, "toggle nasal 0x80 -> 0x82");

        code = 8\'h82; #1;  // aṃ -> a
        check_8(8\'h80, code_out, "toggle nasal 0x82 -> 0x80");

        // ================================================================
        // TEST SUITE 4: Transform — next row (wrap)
        // ================================================================
        $display("\n--- Test Suite 4: NEXT_ROW ---");
        op = 3\'b011;

        code = 8\'h80; #1;  // a (row 0) -> i (row 1)
        check_8(8\'h88, code_out, "next row 0x80 -> 0x88");

        code = 8\'h88; #1;  // i -> u
        check_8(8\'h90, code_out, "next row 0x88 -> 0x90");

        code = 8\'hB0; #1;  // o (row 6) -> a (wrap to row 0)
        check_8(8\'h80, code_out, "next row wrap 0xB0 -> 0x80");

        // Reserved row should error
        code = 8\'hB8; #1;
        check(1\'b1, error, "error for next row on reserved 0xB8");

        // ================================================================
        // TEST SUITE 5: Transform — prev row (wrap)
        // ================================================================
        $display("\n--- Test Suite 5: PREV_ROW ---");
        op = 3\'b100;

        code = 8\'h88; #1;  // i -> a
        check_8(8\'h80, code_out, "prev row 0x88 -> 0x80");

        code = 8\'h80; #1;  // a (row 0) -> o (wrap to row 6)
        check_8(8\'hB0, code_out, "prev row wrap 0x80 -> 0xB0");

        // ================================================================
        // TEST SUITE 6: Transform — guṇa
        // ================================================================
        $display("\n--- Test Suite 6: GUNA ---");
        op = 3\'b101;

        code = 8\'h80; #1;  // a -> e
        check_8(8\'hA8, code_out, "guna 0x80 (a) -> 0xA8 (e)");

        code = 8\'h88; #1;  // i -> a
        check_8(8\'h80, code_out, "guna 0x88 (i) -> 0x80 (a)");

        code = 8\'h90; #1;  // u -> a
        check_8(8\'h80, code_out, "guna 0x90 (u) -> 0x80 (a)");

        code = 8\'h98; #1;  // ṛ -> a
        check_8(8\'h80, code_out, "guna 0x98 (ṛ) -> 0x80 (a)");

        code = 8\'hA0; #1;  // ḷ -> a
        check_8(8\'h80, code_out, "guna 0xA0 (ḷ) -> 0x80 (a)");

        code = 8\'hA8; #1;  // e -> ai (set length bit)
        check_8(8\'hA9, code_out, "guna 0xA8 (e) -> 0xA9 (ai)");

        code = 8\'hB0; #1;  // o -> au
        check_8(8\'hB1, code_out, "guna 0xB0 (o) -> 0xB1 (au)");

        // Nasal should error (guna undefined for nasalized)
        code = 8\'h82; #1;
        check(1\'b1, error, "error for guna on nasal 0x82");

        // ================================================================
        // TEST SUITE 7: Transform — voice (class 00 embryo)
        // ================================================================
        $display("\n--- Test Suite 7: VOICE (embryo) ---");
        op = 3\'b110;

        code = 8\'h23; #1;  // k -> g
        check_8(8\'h18, code_out, "voice 0x23 (k) -> 0x18 (g)");

        code = 8\'h22; #1;  // t -> d
        check_8(8\'h1A, code_out, "voice 0x22 (t) -> 0x1A (d)");

        code = 8\'h24; #1;  // p -> b
        check_8(8\'h17, code_out, "voice 0x24 (p) -> 0x17 (b)");

        // Non-stop should error
        code = 8\'h00; #1;
        check(1\'b1, error, "error for voice on vowel 0x00");

        // ================================================================
        // TEST SUITE 8: Transform — aspirate (class 00 embryo)
        // ================================================================
        $display("\n--- Test Suite 8: ASPIRATE (embryo) ---");
        op = 3\'b111;

        code = 8\'h23; #1;  // k -> kh
        check_8(8\'h1B, code_out, "aspirate 0x23 (k) -> 0x1B (kh)");

        code = 8\'h18; #1;  // g -> gh
        check_8(8\'h13, code_out, "aspirate 0x18 (g) -> 0x13 (gh)");

        // ================================================================
        // Summary
        // ================================================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total:  %0d", tests_run);
        $display("Passed: %0d", tests_passed);
        $display("Failed: %0d", tests_failed);
        if (tests_failed == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** SOME TESTS FAILED ***");
        $display("========================================");
        $finish;
    end

endmodule

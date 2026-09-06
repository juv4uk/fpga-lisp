// ============================================================================
// tb_upc8.sv — Testbench for the unified upc8_unit.sv engine
// ============================================================================
// Replaces the old tb (decode/transform standalone modules + demo board).
// Covers: DECODE (rs2=4), TRANSFORM (rs2=5), PREDICATE (rs2=6).
// Compile/run:
//   iverilog -g2012 -I fpga/rtl -o /tmp/tb_upc8.vvp \
//     fpga/rtl/lisp_word.sv fpga/rtl/upc8_unit.sv fpga/sim/tb_upc8.sv
//   vvp /tmp/tb_upc8.vvp
// ============================================================================

`include "lisp_word.sv"

module tb_upc8;
    lisp_word_t code_word;
    logic [3:0] rs2;
    lisp_word_t result;
    logic       valid;
    logic       error;

    upc8_unit u_dut (
        .code_word(code_word),
        .rs2(rs2),
        .result(result),
        .valid(valid),
        .error(error)
    );

    integer   pass = 0;
    integer   fail = 0;

    task automatic check;
        input [27:0]   code;    // value[7:0]=code, [10:8]=op for transform
        input [3:0]    sel;
        input [27:0]   exp_value;
        input          exp_valid;
        input          exp_error;
        input [255:0]  name;
        lisp_word_t cw;
    begin
        cw.tag   = TAG_FIXNUM;
        cw.value = code;
        code_word = cw;
        rs2 = sel;
        #1;
        if (result.tag == TAG_FIXNUM &&
            result.value == exp_value &&
            valid == exp_valid &&
            error == exp_error) begin
            pass = pass + 1;
            $display("PASS %s (value=%x valid=%b error=%b)",
                     name, result.value, valid, error);
        end else begin
            fail = fail + 1;
            $display("FAIL %s: got value=%x valid=%b error=%b (tag=%0d); exp value=%x valid=%b error=%b",
                     name, result.value, valid, error, result.tag,
                     exp_value, exp_valid, exp_error);
        end
    end
    endtask

    initial begin
        $display("=== UPC-8 unified unit tests ===");

        // ------------------------------------------------------------------
        // DECODE (rs2=4): result = {row[15:13], ir[12], ik[11], an[10],
        //                           ac[9], cc10[8], code[7:0]}
        // ------------------------------------------------------------------
        // code 0x87: cls=10 row=0 free=1(not skt) nasal=1 len=1 -> cc10 only
        check(28'h0000087, 4'd4, 28'h0000187, 1'b1, 1'b0, "decode-0x87-nonskt-cc10only");
        // code 0x80: cls=10 row=0 free=0 nasal=0 len=0 -> ac_14+an_pred set
        check(28'h0000080, 4'd4, 28'h0000780, 1'b1, 1'b0, "decode-0x80-ac14");
        // code 0x00: cls=00 -> nothing set
        check(28'h0000000, 4'd4, 28'h0000000, 1'b1, 1'b0, "decode-0x00-class00");

        // ------------------------------------------------------------------
        // TRANSFORM (rs2=5): result = {op[15:13], err[9], valid[8], out[7:0]}
        // NOTE: on error the RTL keeps valid=1 (transform_valid is only ever
        // deasserted by never being cleared) and echoes the unmodified code.
        // ------------------------------------------------------------------
        // TOGGLE_LENGTH (op=001) on 0x83 (skt nasal len1) -> 0x82
        check(28'h0000183, 4'd5, 28'h0002182, 1'b1, 1'b0, "transform-toggle-length-0x83");
        // TOGGLE_NASAL (op=010) on 0x83 (skt nasal len1) -> 0x81
        check(28'h0000283, 4'd5, 28'h0004181, 1'b1, 1'b0, "transform-toggle-nasal-0x83");
        // NEXT_ROW (op=011) on 0x80 (row 0) -> 0x88
        check(28'h0000380, 4'd5, 28'h0006188, 1'b1, 1'b0, "transform-next-row-0x80");
        // PREV_ROW (op=100) on 0x80 (row 0) -> row 6 -> 0xB0
        check(28'h0000480, 4'd5, 28'h00081B0, 1'b1, 1'b0, "transform-prev-row-wrap-0x80");
        // GUNA (op=101) on 0x80 (row 0, non-nasal) -> row5 -> 0xA8
        check(28'h0000580, 4'd5, 28'h000A1A8, 1'b1, 1'b0, "transform-guna-0x80");
        // GUNA on nasal in skt layer (0x83) -> error, code echoed
        check(28'h0000583, 4'd5, 28'h000A383, 1'b1, 1'b1, "transform-guna-nasal-error");
        // VOICE (op=110) on 0x23 -> 0x18
        check(28'h0000623, 4'd5, 28'h000C118, 1'b1, 1'b0, "transform-voice-0x23");
        // ASPIRATE (op=111) on 0x23 -> 0x1B
        check(28'h0000723, 4'd5, 28'h000E11B, 1'b1, 1'b0, "transform-aspirate-0x23");
        // TOGGLE_LENGTH on non-skt (0x87: free=1) -> error, code echoed
        check(28'h0000187, 4'd5, 28'h0002387, 1'b1, 1'b1, "transform-non-skt-error");

        // ------------------------------------------------------------------
        // PREDICATE (rs2=6): result = {ir[4], ik[3], an[2], ac[1], cc10[0]}
        // ------------------------------------------------------------------
        check(28'h0000080, 4'd6, 28'h0000007, 1'b1, 1'b0, "pred-0x80-ac-an");
        check(28'h0000088, 4'd6, 28'h000000F, 1'b1, 1'b0, "pred-0x88-ac-an-ik");
        check(28'h0000087, 4'd6, 28'h0000001, 1'b1, 1'b0, "pred-0x87-nasal-cc10only");
        check(28'h0000000, 4'd6, 28'h0000000, 1'b1, 1'b0, "pred-0x00-class00");

        // ------------------------------------------------------------------
        // Unknown rs2 -> safe pass-through + error
        // ------------------------------------------------------------------
        check(28'h0000042, 4'd7, 28'h0000042, 1'b1, 1'b1, "rs2-7-pass-through");

        $display("=== RESULT: %0d PASS, %0d FAIL ===", pass, fail);
        if (fail > 0) $fatal(1, "UPC-8 unified unit tests FAILED");
        else          $display("UPC-8 unified unit tests OK");
        $finish;
    end
endmodule
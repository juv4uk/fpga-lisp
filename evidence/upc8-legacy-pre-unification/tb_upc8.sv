// tb_upc8 -- testbench for the UPC-8 decode/transform demo.
//
// Three sections:
//   1. upc8_decode: exhaustive 0x00-0xFF comparison against the reference
//      ROM generated from the shiva-sutras registry oracle (upc8.py).
//   2. upc8_transform: direct units, 2/3/4-byte extensions, reserved lead,
//      truncated-at-eof.
//   3. upc8_demo: fast-parameterized run of the full bank walk, checking the
//      observed natural-class sequence on pmod_io and the error latches.
//
// Run from the repo root:
//   iverilog -g2012 -I fpga/rtl -o tb_upc8.vvp \
//     fpga/rtl/upc8_decode.sv fpga/rtl/upc8_transform.sv \
//     fpga/rtl/upc8_demo.sv fpga/sim/tb_upc8.sv
//   vvp tb_upc8.vvp

`timescale 1ns/1ps

module tb_upc8;
    integer failures = 0;

    // ====================================================================
    // 1. upc8_decode against the generated reference ROM
    // ====================================================================
    reg  [7:0] in_code;
    wire [1:0] d_l; wire [5:0] d_c; wire [1:0] d_s; wire d_v;

    upc8_decode dut_dc(in_code, d_l, d_c, d_s, d_v);

    reg [11:0] ref_mem[0:255];
    integer i;

    task check_decode; begin
        $readmemh("fpga/sim/upc8_expected.hex", ref_mem);
        for (i = 0; i < 256; i = i + 1) begin
            in_code = i[7:0];
            #1;
            if (d_v != ref_mem[i][10]) sk_fail("decode valid", i);
            if (d_l != ref_mem[i][1:0]) sk_fail("decode layer", i);
            if (d_s != ref_mem[i][3:2]) sk_fail("decode special", i);
            if (d_c != ref_mem[i][9:4]) sk_fail("decode cls", i);
        end
        $display("PASS decode 256/256 codes match registry oracle");
    end endtask

    // ====================================================================
    // 2. upc8_transform streaming decoder
    // ====================================================================
    reg t_clk = 0, t_rst, t_dv, t_eof;
    reg [7:0] t_din;
    wire [7:0] t_unit; wire t_valid; wire t_res; wire t_trunc;
    upc8_transform dut_tf(t_clk, t_rst, t_din, t_dv, t_eof,
                          t_unit, t_valid, t_res, t_trunc);

    always #5 t_clk = ~t_clk;

    reg [7:0] got[0:15];
    integer gotn;
    integer err_res_seen, err_trunc_seen;

    task feed_unit;
        input [7:0] byt;
        input is_eof;
        begin
            t_dv = 1; t_din = byt; t_eof = is_eof;
            @(posedge t_clk);
            @(negedge t_clk);   // one-cycle pulses have settled
            #1;
            if (t_valid && gotn < 16) got[gotn++] = t_unit;
            if (t_res) err_res_seen = 1;
            if (t_trunc) err_trunc_seen = 1;
            t_dv = 0;
        end
    endtask

    // Each scenario is a fresh bank starting at a known frame boundary
    // (the UPC v1 framing assumption). Reset the transform between banks.
    task tf_reset; begin
        t_rst = 1; t_dv = 0; t_eof = 0;
        @(negedge t_clk);
        t_rst = 0;
        @(negedge t_clk);
    end endtask

    task check_transform; begin
        // (a) direct-only bank
        gotn = 0; err_res_seen = 0; err_trunc_seen = 0;
        feed_unit(8'h00, 0);
        feed_unit(8'h25, 0);
        feed_unit(8'h0C, 1);
        ck(1, gotn === 3, "T-A unit count");
        ck(1, got[0]===8'h00 && got[1]===8'h25 && got[2]===8'h0C, "T-A unit seq");
        ck(1, !err_res_seen && !err_trunc_seen, "T-A no errors");

        tf_reset;
        // (b) extension bank: E0+t, E1+t+t, E2+t+t+t, direct tail
        gotn = 0; err_res_seen = 0; err_trunc_seen = 0;
        feed_unit(8'hE0, 0);
        feed_unit(8'hAA, 0);   // -> unit 0xE0
        feed_unit(8'hE1, 0);
        feed_unit(8'hBB, 0);
        feed_unit(8'hCC, 0);   // -> unit 0xE1
        feed_unit(8'hE2, 0);
        feed_unit(8'h11, 0);
        feed_unit(8'h22, 0);
        feed_unit(8'h33, 0);   // -> unit 0xE2
        feed_unit(8'hDF, 1);
        ck(1, gotn === 4, "T-B unit count");
        ck(1, got[0]===8'hE0 && got[1]===8'hE1 && got[2]===8'hE2 && got[3]===8'hDF, "T-B unit seq");
        ck(1, !err_res_seen && !err_trunc_seen, "T-B no errors");

        tf_reset;
        // (c) reserved lead
        gotn = 0; err_res_seen = 0; err_trunc_seen = 0;
        feed_unit(8'hF3, 1);
        ck(1, gotn === 0, "T-C no unit");
        ck(1, err_res_seen === 1, "T-C err_reserved");

        tf_reset;
        // (d) truncated extension at eof (E1 owes two, eof on first tail)
        gotn = 0; err_res_seen = 0; err_trunc_seen = 0;
        feed_unit(8'hE1, 0);
        feed_unit(8'hBB, 1);
        ck(1, gotn === 0, "T-D no unit");
        ck(1, err_trunc_seen === 1, "T-D err_truncated");

        tf_reset;
        // (e) truncated lead extension at eof (E2 is last byte, owes tails)
        gotn = 0; err_res_seen = 0; err_trunc_seen = 0;
        feed_unit(8'hE2, 1);
        ck(1, gotn === 0, "T-E no unit");
        ck(1, err_trunc_seen === 1, "T-E err_truncated");
        $display("PASS transform 5 scenario banks");
    end endtask

    // ====================================================================
    // 3. upc8_demo bank walk (fast parameters)
    // ====================================================================
    reg d_clk = 0, d_key = 1;
    wire d_led, d_done, d_ready;
    wire [5:0] d_io;
    upc8_demo #(.CLK_DIV(32'd16), .GAP_DIV(32'd8)) dut_demo(
        d_clk, d_key, d_led, d_done, d_ready, d_io);
    always #2 d_clk = ~d_clk;   // 4ns period, independent domain

    reg [5:0] cls_seen[0:31];
    integer n_cls;
    integer dem_err, d_done_seen;

    task check_demo; begin
        // expected class sequence per pass: a k a r n S, then E0-ext -> 0
        // cls: 32, 24, 32, 17, 18, 20, 0
        d_key = 1;
        n_cls = 0; dem_err = 0; d_done_seen = 0;

        // wait for the power-on reset to release
        while (dut_demo.rst) @(posedge d_clk);

        // sample several full passes
        repeat (3000) begin
            @(negedge d_clk);
            if (dut_demo.u_valid && n_cls < 32) cls_seen[n_cls++] = d_io;
            if (d_ready) dem_err = 1;
            if (d_done) d_done_seen = 1;
        end

        ck(1, n_cls >= 14, "D >= 2 passes sampled");
        ck(1, n_cls >= 7 &&
                  cls_seen[0]===6'd32 && cls_seen[1]===6'd24 &&
                  cls_seen[2]===6'd32 && cls_seen[3]===6'd17 &&
                  cls_seen[4]===6'd18 && cls_seen[5]===6'd20 &&
                  cls_seen[6]===6'd0,
                  "D class sequence");
        ck(1, n_cls >= 14 &&
                  cls_seen[7]===6'd32 && cls_seen[8]===6'd24,
                  "D second pass repeats");
        ck(1, dem_err === 1, "D error latch seen");
        ck(1, d_done_seen === 1, "D valid-unit LED seen");
        $display("PASS demo bank walk");
    end endtask

    // ====================================================================
    task sk_fail; input [255:0] msg; input [7:0] at;
        begin
            $display("FAIL %0s at code 0x%02X", msg, at);
            failures = failures + 1;
        end
    endtask

    task ck; input [7:0] id; input pass; input [255:0] label;
        begin
            if (pass) $display("ok   #%0d %0s", id, label);
            else begin $display("FAIL #%0d %0s", id, label); failures = failures + 1; end
        end
    endtask

    initial begin
        check_decode;
        #1;
        t_rst = 1; #10; t_rst = 0;
        check_transform;
        check_demo;
        if (failures === 0) begin
            $display("ALL PASS (%0d fails)", failures);
            $finish;
        end else begin
            $display("FAILURES: %0d", failures);
            $finish(2);
        end
    end
endmodule
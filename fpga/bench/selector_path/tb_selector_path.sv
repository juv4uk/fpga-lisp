module tb_selector_path;
    localparam int MAX_DEPTH = 64;
    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;

    logic dyn_start, dyn_root;
    logic [MAX_DEPTH-1:0] dyn_suffix;
    logic [$clog2(MAX_DEPTH+1)-1:0] dyn_depth;
    logic dyn_valid, dyn_op, dyn_done;

    selector_path_dynamic #(.MAX_DEPTH(MAX_DEPTH)) u_dyn (
        .clk(clk), .rst_n(rst_n), .start(dyn_start),
        .root_is_cdr(dyn_root), .suffix_outer_to_inner(dyn_suffix),
        .depth(dyn_depth), .op_valid(dyn_valid), .op_is_cdr(dyn_op), .done(dyn_done)
    );

    logic static_start, static_valid, static_op, static_done;
    selector_path_static #(
        .DEPTH(4), .ROOT_IS_CDR(1'b0), .SUFFIX_OUTER_TO_INNER(4'b0110)
    ) u_static (
        .clk(clk), .rst_n(rst_n), .start(static_start),
        .op_valid(static_valid), .op_is_cdr(static_op), .done(static_done)
    );

    integer failures = 0;
    integer dyn_i = 0;
    integer sta_i = 0;
    logic [4:0] expected = 5'b01100;

    always @(posedge clk) begin
        if (dyn_valid) begin
            if (dyn_i > 4 || dyn_op !== expected[4-dyn_i]) begin
                $display("DYNAMIC mismatch step=%0d got=%0d", dyn_i, dyn_op);
                failures = failures + 1;
            end
            dyn_i = dyn_i + 1;
        end
        if (static_valid) begin
            if (sta_i > 4 || static_op !== expected[4-sta_i]) begin
                $display("STATIC mismatch step=%0d got=%0d", sta_i, static_op);
                failures = failures + 1;
            end
            sta_i = sta_i + 1;
        end
    end

    initial begin
        dyn_start = 0; dyn_root = 0; dyn_suffix = '0; dyn_depth = 0; static_start = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        dyn_root = 0; dyn_suffix[3:0] = 4'b0110; dyn_depth = 4;
        dyn_start = 1; static_start = 1;
        @(posedge clk);
        dyn_start = 0; static_start = 0;
        wait(dyn_done && static_done);
        @(posedge clk);
        if (dyn_i != 5) begin
            $display("DYNAMIC wrong op count %0d expected 5", dyn_i); failures = failures + 1;
        end
        if (sta_i != 5) begin
            $display("STATIC wrong op count %0d expected 5", sta_i); failures = failures + 1;
        end
        if (failures == 0)
            $display("PASS selector path parity: dynamic bit-walk == static schedule");
        else
            $display("FAIL selector path parity failures=%0d", failures);
        $finish;
    end
endmodule

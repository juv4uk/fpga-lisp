module tb_address_map;
    localparam int DEPTH = 1024;
    localparam int INDEX_W = $clog2(DEPTH);

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic [INDEX_W-1:0] idx;

    logic [INDEX_W-1:0] naive_addr;
    logic [4:0] naive_off;
    logic naive_cross;

    logic [INDEX_W-1:0] a3_addr, a5_addr, a7_addr;
    logic [4:0] a3_off, a5_off, a7_off;
    logic a3_cross, a5_cross, a7_cross;

    logic [INDEX_W-1:0] t3_addr, t5_addr, t7_addr;
    logic [4:0] t3_off, t5_off, t7_off;
    logic t3_cross, t5_cross, t7_cross;

    always #5 clk = ~clk;

    pack_addr_naive #(.DEPTH(DEPTH)) u_naive (
        .clk, .rst_n, .value_index(idx),
        .word_addr(naive_addr), .bit_offset(naive_off), .crosses_word(naive_cross)
    );

    pack_addr_word_aligned #(.WIDTH(3), .DEPTH(DEPTH)) u_a3 (
        .clk, .rst_n, .value_index(idx),
        .word_addr(a3_addr), .bit_offset(a3_off), .crosses_word(a3_cross)
    );
    pack_addr_word_aligned #(.WIDTH(5), .DEPTH(DEPTH)) u_a5 (
        .clk, .rst_n, .value_index(idx),
        .word_addr(a5_addr), .bit_offset(a5_off), .crosses_word(a5_cross)
    );
    pack_addr_word_aligned #(.WIDTH(7), .DEPTH(DEPTH)) u_a7 (
        .clk, .rst_n, .value_index(idx),
        .word_addr(a7_addr), .bit_offset(a7_off), .crosses_word(a7_cross)
    );

    pack_addr_tight #(.WIDTH(3), .DEPTH(DEPTH)) u_t3 (
        .clk, .rst_n, .value_index(idx),
        .word_addr(t3_addr), .bit_offset(t3_off), .crosses_word(t3_cross)
    );
    pack_addr_tight #(.WIDTH(5), .DEPTH(DEPTH)) u_t5 (
        .clk, .rst_n, .value_index(idx),
        .word_addr(t5_addr), .bit_offset(t5_off), .crosses_word(t5_cross)
    );
    pack_addr_tight #(.WIDTH(7), .DEPTH(DEPTH)) u_t7 (
        .clk, .rst_n, .value_index(idx),
        .word_addr(t7_addr), .bit_offset(t7_off), .crosses_word(t7_cross)
    );

    task automatic check_aligned(
        input int i,
        input int width,
        input int got_addr,
        input int got_off,
        input bit got_cross
    );
        int slots;
        int exp_addr;
        int exp_off;
        begin
            slots = 32 / width;
            exp_addr = i / slots;
            exp_off = (i % slots) * width;
            if (got_addr != exp_addr || got_off != exp_off || got_cross != 0) begin
                $display("FAIL aligned W=%0d i=%0d got=(%0d,%0d,%0d) exp=(%0d,%0d,0)",
                         width, i, got_addr, got_off, got_cross, exp_addr, exp_off);
                $fatal(1);
            end
        end
    endtask

    task automatic check_tight(
        input int i,
        input int width,
        input int got_addr,
        input int got_off,
        input bit got_cross
    );
        int bitpos;
        int exp_addr;
        int exp_off;
        bit exp_cross;
        begin
            bitpos = i * width;
            exp_addr = bitpos / 32;
            exp_off = bitpos % 32;
            exp_cross = (exp_off + width) > 32;
            if (got_addr != exp_addr || got_off != exp_off || got_cross != exp_cross) begin
                $display("FAIL tight W=%0d i=%0d got=(%0d,%0d,%0d) exp=(%0d,%0d,%0d)",
                         width, i, got_addr, got_off, got_cross,
                         exp_addr, exp_off, exp_cross);
                $fatal(1);
            end
        end
    endtask

    integer i;
    initial begin
        idx = '0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        for (i = 0; i < DEPTH; i = i + 1) begin
            idx = i[INDEX_W-1:0];
            @(posedge clk);
            #1;

            if (naive_addr != i || naive_off != 0 || naive_cross != 0) begin
                $display("FAIL naive i=%0d got=(%0d,%0d,%0d)",
                         i, naive_addr, naive_off, naive_cross);
                $fatal(1);
            end

            check_aligned(i, 3, a3_addr, a3_off, a3_cross);
            check_aligned(i, 5, a5_addr, a5_off, a5_cross);
            check_aligned(i, 7, a7_addr, a7_off, a7_cross);

            check_tight(i, 3, t3_addr, t3_off, t3_cross);
            check_tight(i, 5, t5_addr, t5_off, t5_cross);
            check_tight(i, 7, t7_addr, t7_off, t7_cross);
        end

        $display("PASS dense-pack address maps for all %0d indices at D3/D5/D7", DEPTH);
        $finish;
    end
endmodule

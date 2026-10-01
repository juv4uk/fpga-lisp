module tb_d5_decoder;
    logic [4:0] word;

    logic flat_occupied, flat_selector, flat_root, flat_transformer, flat_fail;
    logic [1:0] flat_suffix;

    logic hybrid_occupied, hybrid_selector, hybrid_root, hybrid_transformer, hybrid_fail;
    logic [1:0] hybrid_suffix;

    logic selector_occupied, selector_selector, selector_root, selector_transformer, selector_fail;
    logic [1:0] selector_suffix;

    integer failures = 0;
    integer hybrid_occupied_count = 0;
    integer selector_occupied_count = 0;
    integer i;

    d5_flat_decoder u_flat (
        .word(word),
        .occupied(flat_occupied),
        .is_selector(flat_selector),
        .selector_root_is_cdr(flat_root),
        .selector_suffix(flat_suffix),
        .is_transformer(flat_transformer),
        .reserved_fail(flat_fail)
    );

    d5_hybrid_decoder u_hybrid (
        .word(word),
        .occupied(hybrid_occupied),
        .is_selector(hybrid_selector),
        .selector_root_is_cdr(hybrid_root),
        .selector_suffix(hybrid_suffix),
        .is_transformer(hybrid_transformer),
        .reserved_fail(hybrid_fail)
    );

    d5_selector_only_decoder u_selector (
        .word(word),
        .occupied(selector_occupied),
        .is_selector(selector_selector),
        .selector_root_is_cdr(selector_root),
        .selector_suffix(selector_suffix),
        .is_transformer(selector_transformer),
        .reserved_fail(selector_fail)
    );

    function automatic logic expected_selector(input logic [4:0] w);
        expected_selector = (w[4:2] == 3'b101) || (w[4:2] == 3'b110);
    endfunction

    function automatic logic expected_transformer(input logic [4:0] w);
        expected_transformer = (w == 5'b00101);
    endfunction

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            word = i[4:0];
            #1;

            if ({flat_occupied, flat_selector, flat_root, flat_suffix, flat_transformer, flat_fail}
                !==
                {hybrid_occupied, hybrid_selector, hybrid_root, hybrid_suffix, hybrid_transformer, hybrid_fail}) begin
                $display("FLAT/HYBRID mismatch word=%05b", word);
                failures = failures + 1;
            end

            if (hybrid_selector !== expected_selector(word)) begin
                $display("selector classification mismatch word=%05b", word);
                failures = failures + 1;
            end

            if (hybrid_transformer !== expected_transformer(word)) begin
                $display("transformer classification mismatch word=%05b", word);
                failures = failures + 1;
            end

            if (hybrid_occupied !== (expected_selector(word) | expected_transformer(word))) begin
                $display("occupied mismatch word=%05b", word);
                failures = failures + 1;
            end

            if (hybrid_fail !== ~hybrid_occupied) begin
                $display("fail-closed mismatch word=%05b", word);
                failures = failures + 1;
            end

            if (selector_selector !== expected_selector(word)
                || selector_occupied !== expected_selector(word)
                || selector_transformer !== 1'b0
                || selector_fail !== ~selector_occupied) begin
                $display("selector-only mismatch word=%05b", word);
                failures = failures + 1;
            end

            if (expected_selector(word)) begin
                if (hybrid_suffix !== word[1:0]) begin
                    $display("selector suffix mismatch word=%05b", word);
                    failures = failures + 1;
                end
                if (hybrid_root !== (word[4:2] == 3'b110)) begin
                    $display("selector root mismatch word=%05b", word);
                    failures = failures + 1;
                end
            end

            if (hybrid_occupied)
                hybrid_occupied_count = hybrid_occupied_count + 1;
            if (selector_occupied)
                selector_occupied_count = selector_occupied_count + 1;
        end

        if (hybrid_occupied_count != 9) begin
            $display("wrong hybrid occupied count=%0d expected=9", hybrid_occupied_count);
            failures = failures + 1;
        end

        if (selector_occupied_count != 8) begin
            $display("wrong selector-only occupied count=%0d expected=8", selector_occupied_count);
            failures = failures + 1;
        end

        if (failures == 0) begin
            $display("PASS D5 decoder: flat == hybrid for all 32 words");
            $display("PASS D5 capacity: selectors=8 transformer-candidate=1 fail-closed=23");
        end else begin
            $display("FAIL D5 decoder failures=%0d", failures);
        end

        $finish;
    end
endmodule

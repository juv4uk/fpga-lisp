module tb_limb_kernel #(
    parameter integer W = 24
);
    logic [W-1:0] a, b;
    logic cin;
    logic [W-1:0] sum;
    logic carry;
    logic [2*W-1:0] product;

    limb_kernel #(.W(W)) dut (
        .a(a), .b(b), .cin(cin),
        .sum(sum), .carry(carry), .product(product)
    );

    integer fd;
    integer rc;
    integer count;
    logic [W-1:0] exp_sum;
    logic exp_carry;
    logic [2*W-1:0] exp_product;
    string vectors;

    initial begin
        if (!$value$plusargs("VECTORS=%s", vectors)) begin
            $fatal(1, "missing +VECTORS=<path>");
        end
        fd = $fopen(vectors, "r");
        if (fd == 0) $fatal(1, "cannot open vectors: %s", vectors);

        count = 0;
        while (!$feof(fd)) begin
            rc = $fscanf(fd, "%h %h %d %h %d %h\n",
                         a, b, cin, exp_sum, exp_carry, exp_product);
            if (rc == 6) begin
                #1;
                if (sum !== exp_sum || carry !== exp_carry || product !== exp_product) begin
                    $display("FAIL W=%0d a=%h b=%h cin=%0d", W, a, b, cin);
                    $display(" got sum=%h carry=%0d product=%h", sum, carry, product);
                    $display(" exp sum=%h carry=%0d product=%h", exp_sum, exp_carry, exp_product);
                    $fatal(1);
                end
                count = count + 1;
            end
        end
        $fclose(fd);
        $display("PASS W=%0d vectors=%0d", W, count);
        $finish;
    end
endmodule

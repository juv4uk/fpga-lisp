module limb_bench_top #(
    parameter integer W = 24,
    parameter integer MODE = 0
) (
    input  logic clk,
    input  logic rst_n,
    output logic sink
);
    logic [W-1:0] a_q, b_q;
    logic cin_q;
    logic [W-1:0] sum;
    logic carry;
    logic [2*W-1:0] product;

    limb_kernel #(.W(W)) u_kernel (
        .a(a_q), .b(b_q), .cin(cin_q),
        .sum(sum), .carry(carry), .product(product)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_q <= {{(W-1){1'b0}},1'b1};
            b_q <= {{(W-2){1'b0}},2'b11};
            cin_q <= 1'b0;
            sink <= 1'b0;
        end else begin
            a_q <= {a_q[W-2:0], a_q[W-1] ^ a_q[W-2]};
            b_q <= {b_q[W-2:0], b_q[W-1] ^ b_q[W-3]};
            cin_q <= ~cin_q;
            if (MODE == 0)
                sink <= a_q[W-1] ^ b_q[W-1] ^ cin_q;
            else if (MODE == 1)
                sink <= sum[W-1] ^ carry;
            else
                sink <= product[2*W-1] ^ product[W-1];
        end
    end
endmodule

module limb_base_w16(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(16),.MODE(0)) u(.*); endmodule
module limb_add_w16(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(16),.MODE(1)) u(.*); endmodule
module limb_mul_w16(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(16),.MODE(2)) u(.*); endmodule

module limb_base_w18(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(18),.MODE(0)) u(.*); endmodule
module limb_add_w18(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(18),.MODE(1)) u(.*); endmodule
module limb_mul_w18(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(18),.MODE(2)) u(.*); endmodule

module limb_base_w24(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(24),.MODE(0)) u(.*); endmodule
module limb_add_w24(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(24),.MODE(1)) u(.*); endmodule
module limb_mul_w24(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(24),.MODE(2)) u(.*); endmodule

module limb_base_w28(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(28),.MODE(0)) u(.*); endmodule
module limb_add_w28(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(28),.MODE(1)) u(.*); endmodule
module limb_mul_w28(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(28),.MODE(2)) u(.*); endmodule

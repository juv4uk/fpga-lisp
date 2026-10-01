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

    // MODE:
    // 0 = add baseline (W+1 reduction)
    // 1 = add kernel   (W+1 reduction)
    // 2 = mul baseline (2W reduction)
    // 3 = mul kernel    (2W reduction)
    //
    // Separate baselines keep source/sink plumbing matched so resource deltas
    // do not reward one operation for exposing fewer output bits.
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
            case (MODE)
                0: sink <= ^a_q ^ cin_q;
                1: sink <= ^sum ^ carry;
                2: sink <= ^{a_q, b_q};
                3: sink <= ^product;
                default: sink <= 1'b0;
            endcase
        end
    end
endmodule

module limb_baseadd_w16(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(16),.MODE(0)) u(.*); endmodule
module limb_add_w16(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(16),.MODE(1)) u(.*); endmodule
module limb_basemul_w16(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(16),.MODE(2)) u(.*); endmodule
module limb_mul_w16(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(16),.MODE(3)) u(.*); endmodule

module limb_baseadd_w18(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(18),.MODE(0)) u(.*); endmodule
module limb_add_w18(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(18),.MODE(1)) u(.*); endmodule
module limb_basemul_w18(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(18),.MODE(2)) u(.*); endmodule
module limb_mul_w18(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(18),.MODE(3)) u(.*); endmodule

module limb_baseadd_w24(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(24),.MODE(0)) u(.*); endmodule
module limb_add_w24(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(24),.MODE(1)) u(.*); endmodule
module limb_basemul_w24(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(24),.MODE(2)) u(.*); endmodule
module limb_mul_w24(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(24),.MODE(3)) u(.*); endmodule

module limb_baseadd_w28(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(28),.MODE(0)) u(.*); endmodule
module limb_add_w28(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(28),.MODE(1)) u(.*); endmodule
module limb_basemul_w28(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(28),.MODE(2)) u(.*); endmodule
module limb_mul_w28(input logic clk,rst_n,output logic sink);
    limb_bench_top #(.W(28),.MODE(3)) u(.*); endmodule

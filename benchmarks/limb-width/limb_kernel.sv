module limb_kernel #(
    parameter integer W = 24
) (
    input  logic [W-1:0]   a,
    input  logic [W-1:0]   b,
    input  logic           cin,
    output logic [W-1:0]   sum,
    output logic           carry,
    output logic [2*W-1:0] product
);
    logic [W:0] add_ext;

    assign add_ext = {1'b0, a} + {1'b0, b} + cin;
    assign sum = add_ext[W-1:0];
    assign carry = add_ext[W];
    assign product = a * b;
endmodule

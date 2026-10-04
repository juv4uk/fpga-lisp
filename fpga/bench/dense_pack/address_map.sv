// Benchmark-only address mapping for fpga-lisp#50.
// Hardware mechanism evidence only: never semantic authority.

module pack_addr_naive #(
    parameter int DEPTH = 1024,
    parameter int INDEX_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  logic               clk,
    input  logic               rst_n,
    input  logic [INDEX_W-1:0] value_index,
    output logic [INDEX_W-1:0] word_addr,
    output logic [4:0]         bit_offset,
    output logic               crosses_word
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_addr <= '0;
            bit_offset <= '0;
            crosses_word <= 1'b0;
        end else begin
            word_addr <= value_index;
            bit_offset <= 5'd0;
            crosses_word <= 1'b0;
        end
    end
endmodule


module pack_addr_word_aligned #(
    parameter int WIDTH = 3,
    parameter int DEPTH = 1024,
    parameter int INDEX_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  logic               clk,
    input  logic               rst_n,
    input  logic [INDEX_W-1:0] value_index,
    output logic [INDEX_W-1:0] word_addr,
    output logic [4:0]         bit_offset,
    output logic               crosses_word
);
    localparam int SLOTS = 32 / WIDTH;

    logic [INDEX_W-1:0] word_addr_calc;
    logic [4:0] bit_offset_calc;

    always_comb begin
        word_addr_calc = value_index / SLOTS;
        bit_offset_calc = (value_index % SLOTS) * WIDTH;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_addr <= '0;
            bit_offset <= '0;
            crosses_word <= 1'b0;
        end else begin
            word_addr <= word_addr_calc;
            bit_offset <= bit_offset_calc;
            crosses_word <= 1'b0;
        end
    end
endmodule


module pack_addr_tight #(
    parameter int WIDTH = 3,
    parameter int DEPTH = 1024,
    parameter int INDEX_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  logic               clk,
    input  logic               rst_n,
    input  logic [INDEX_W-1:0] value_index,
    output logic [INDEX_W-1:0] word_addr,
    output logic [4:0]         bit_offset,
    output logic               crosses_word
);
    localparam int BITPOS_W = INDEX_W + 4;

    logic [BITPOS_W-1:0] bit_index_calc;
    logic [INDEX_W-1:0] word_addr_calc;
    logic [4:0] bit_offset_calc;
    logic crosses_calc;

    always_comb begin
        bit_index_calc = value_index * WIDTH;
        word_addr_calc = bit_index_calc >> 5;
        bit_offset_calc = bit_index_calc[4:0];
        crosses_calc = ({1'b0, bit_offset_calc} + WIDTH) > 32;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_addr <= '0;
            bit_offset <= '0;
            crosses_word <= 1'b0;
        end else begin
            word_addr <= word_addr_calc;
            bit_offset <= bit_offset_calc;
            crosses_word <= crosses_calc;
        end
    end
endmodule

`include "lisp_word.sv"

module registers (
    input  logic         clk,
    input  logic         rst_n,
    
    // Read ports (up to 2 for binary operations)
    input  logic [3:0]   rd_addr_a,
    input  logic [3:0]   rd_addr_b,
    output lisp_word_t   rd_data_a,
    output lisp_word_t   rd_data_b,
    
    // Write port
    input  logic         we,
    input  logic [3:0]   wr_addr,
    input  lisp_word_t   wr_data
);

    // R0-R7, plus special registers.
    // Address map:
    // 0-7: R0-R7
    // 8: PC (Program Counter)
    // 9: ENV
    // 10: VAL
    // (HP is in LDU but maybe we just proxy it or ignore here, let's say R11 is something else)
    
    lisp_word_t regs [0:15];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i=0; i<16; i++) regs[i] <= '0;
        end else if (we) begin
            regs[wr_addr] <= wr_data;
        end
    end
    
    assign rd_data_a = regs[rd_addr_a];
    assign rd_data_b = regs[rd_addr_b];

endmodule

module heap #(
    parameter integer ADDR_WIDTH = 12
) (
    input  logic                  clk,
    input  logic                  we,      // Write Enable
    input  logic [ADDR_WIDTH-1:0] addr,    // Address
    input  lisp_word_t            car_in,  // Data to write to CAR
    input  lisp_word_t            cdr_in,  // Data to write to CDR
    output lisp_word_t            car_out, // Data read from CAR
    output lisp_word_t            cdr_out  // Data read from CDR
);

    lisp_word_t car_ram [0:(1<<ADDR_WIDTH)-1];
    lisp_word_t cdr_ram [0:(1<<ADDR_WIDTH)-1];
    
    always_ff @(posedge clk) begin
        if (we) begin
            car_ram[addr] <= car_in;
            cdr_ram[addr] <= cdr_in;
        end else begin
            car_out <= car_ram[addr];
            cdr_out <= cdr_ram[addr];
        end
    end

endmodule

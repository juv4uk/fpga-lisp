module heap #(
    parameter integer ADDR_WIDTH = 12
) (
    input  logic                  clk,
    input  logic                  we_car,  // Write Enable, CAR field
    input  logic                  we_cdr,  // Write Enable, CDR field
    input  logic [ADDR_WIDTH-1:0] addr,    // Address
    input  lisp_word_t            car_in,  // Data to write to CAR
    input  lisp_word_t            cdr_in,  // Data to write to CDR
    output lisp_word_t            car_out, // Data read from CAR
    output lisp_word_t            cdr_out  // Data read from CDR
);

    lisp_word_t car_ram [0:(1<<ADDR_WIDTH)-1];
    lisp_word_t cdr_ram [0:(1<<ADDR_WIDTH)-1];

    // Independent per-field write enables (rather than one combined `we`)
    // so an existing cell's CDR can be overwritten in place without
    // touching its CAR -- needed for the internal SETCDR bootstrap
    // capability in lisp_data_unit.sv, which never allocates a new cell,
    // only backpatches one already built by an earlier CONS.
    always_ff @(posedge clk) begin
        if (we_car) car_ram[addr] <= car_in;
        if (we_cdr) cdr_ram[addr] <= cdr_in;
        if (!we_car) car_out <= car_ram[addr];
        if (!we_cdr) cdr_out <= cdr_ram[addr];
    end

endmodule

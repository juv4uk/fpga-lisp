module lisp_data_unit #(
    parameter integer HEAP_ADDR_WIDTH = 12
) (
    input  logic             clk,
    input  logic             rst_n,
    
    // Commands
    input  logic             cmd_cons,
    input  logic             cmd_car,
    input  logic             cmd_cdr,
    input  logic             cmd_setcdr,
    input  logic             cmd_fetch_pair,
    
    // Inputs (from registers or immediate)
    input  lisp_word_t       op_a,
    input  lisp_word_t       op_b,
    
    // Output (to registers)
    output lisp_word_t       result,
    output lisp_word_t       result_cdr,
    output logic             valid,
    output logic             error,

    // Debug/monitor raw heap peek (bypasses CONS tag check)
    input  logic                       cmd_peek,
    input  logic [HEAP_ADDR_WIDTH-1:0] peek_addr,
    output lisp_word_t                 peek_car,
    output lisp_word_t                 peek_cdr,
    output logic                       peek_valid,

    // Debug/monitor: current heap pointer
    output logic [HEAP_ADDR_WIDTH-1:0] hp_out
);

    // Heap Pointer — one bit wider than address space so that
    // hp == 2^HEAP_ADDR_WIDTH signals HEAP_FULL without losing
    // the last usable cell (address 2^HEAP_ADDR_WIDTH - 1).
    logic [HEAP_ADDR_WIDTH:0] hp; // 13 bits for 12-bit address space
    assign hp_out = hp[HEAP_ADDR_WIDTH-1:0];
    logic is_peek;

    // Heap Memory Interface
    logic                     heap_we_car;
    logic                     heap_we_cdr;
    logic [HEAP_ADDR_WIDTH-1:0] heap_addr;
    lisp_word_t               heap_car_in;
    lisp_word_t               heap_cdr_in;
    lisp_word_t               heap_car_out;
    lisp_word_t               heap_cdr_out;

    heap #(
        .ADDR_WIDTH(HEAP_ADDR_WIDTH)
    ) u_heap (
        .clk(clk),
        .we_car(heap_we_car),
        .we_cdr(heap_we_cdr),
        .addr(heap_addr),
        .car_in(heap_car_in),
        .cdr_in(heap_cdr_in),
        .car_out(heap_car_out),
        .cdr_out(heap_cdr_out)
    );
    
    // Basic state logic for reads
    logic [1:0] reading_state; // 0: IDLE, 1: ADDR_SET, 2: DATA_READY
    logic [1:0] read_type; // 0: CAR, 1: CDR, 2: FETCH_PAIR
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hp <= 0;
            heap_we_car <= 0;
            heap_we_cdr <= 0;
            valid <= 0;
            error <= 0;
            reading_state <= 0;
            result <= '0;
            result_cdr <= '0;
            heap_addr <= 0;
            heap_car_in <= 0;
            heap_cdr_in <= 0;
            read_type <= 0;
            is_peek <= 0;
            peek_valid <= 0;
            peek_car <= '0;
            peek_cdr <= '0;
        end else begin
            heap_we_car <= 0;
            heap_we_cdr <= 0;
            valid <= 0;
            error <= 0;
            peek_valid <= 0;

            if (reading_state == 1) begin
                // Address is presented to B-SRAM, wait 1 cycle
                reading_state <= 2;
            end else if (reading_state == 2) begin
                // Data is now available from B-SRAM
                reading_state <= 0;
                if (is_peek) begin
                    peek_valid <= 1;
                    peek_car <= heap_car_out;
                    peek_cdr <= heap_cdr_out;
                end else begin
                    valid <= 1;
                    if (read_type == 2) begin
                        // FETCH_PAIR: return both CAR and CDR
                        result <= heap_car_out;
                        result_cdr <= heap_cdr_out;
                    end else begin
                        result <= (read_type == 0) ? heap_car_out : heap_cdr_out;
                    end
                end
            end else if (cmd_peek) begin
                heap_addr <= peek_addr;
                reading_state <= 1;
                is_peek <= 1;
            end else if (cmd_cons) begin
                // CONS operation — check heap overflow first.
                // hp is (HEAP_ADDR_WIDTH+1) bits wide, so it can
                // represent 0..2^HEAP_ADDR_WIDTH. The value
                // 2^HEAP_ADDR_WIDTH means all 2^HEAP_ADDR_WIDTH
                // cells (0..2^HEAP_ADDR_WIDTH-1) are used → FULL.
                if (hp == (1 << HEAP_ADDR_WIDTH)) begin
                    error <= 1; // HEAP_FULL
                end else begin
                    heap_we_car <= 1;
                    heap_we_cdr <= 1;
                    heap_addr <= hp[HEAP_ADDR_WIDTH-1:0];
                    heap_car_in <= op_a;
                    heap_cdr_in <= op_b;

                    result.tag <= TAG_CONS;
                    result.value <= { {(28-HEAP_ADDR_WIDTH){1'b0}}, hp[HEAP_ADDR_WIDTH-1:0] };
                    valid <= 1;

                    hp <= hp + 1; // Bump allocator
                end
            end else if (cmd_setcdr) begin
                if (op_a.tag == TAG_CONS) begin
                    heap_we_cdr <= 1;
                    heap_addr <= op_a.value[HEAP_ADDR_WIDTH-1:0];
                    heap_cdr_in <= op_b;
                    result <= op_b;
                    valid <= 1;
                end else begin
                    error <= 1;
                end
            end else if (cmd_fetch_pair) begin
                // FETCH_PAIR: read both CAR and CDR in a single heap
                // access cycle. Same latency as CAR or CDR alone (~3
                // cycles), but returns both halves — useful for eval,
                // equal?, lookup, unify, and any traversal that needs
                // both car and cdr of a cons cell.
                if (op_a.tag == TAG_CONS) begin
                    heap_addr <= op_a.value[HEAP_ADDR_WIDTH-1:0];
                    reading_state <= 1;
                    read_type <= 2; // FETCH_PAIR
                    is_peek <= 0;
                end else begin
                    error <= 1; // TYPE_ERROR
                end
            end else if (cmd_car) begin
                if (op_a.tag == TAG_CONS) begin
                    heap_addr <= op_a.value[HEAP_ADDR_WIDTH-1:0];
                    reading_state <= 1;
                    read_type <= 0;
                    is_peek <= 0;
                end else begin
                    error <= 1; // TYPE_ERROR
                end
            end else if (cmd_cdr) begin
                if (op_a.tag == TAG_CONS) begin
                    heap_addr <= op_a.value[HEAP_ADDR_WIDTH-1:0];
                    reading_state <= 1;
                    read_type <= 1;
                    is_peek <= 0;
                end else begin
                    error <= 1; // TYPE_ERROR
                end
            end
        end
    end

endmodule

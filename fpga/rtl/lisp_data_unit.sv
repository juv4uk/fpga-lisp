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
    
    // Inputs (from registers or immediate)
    input  lisp_word_t       op_a,
    input  lisp_word_t       op_b,
    
    // Output (to registers)
    output lisp_word_t       result,
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

    // Heap Pointer
    logic [HEAP_ADDR_WIDTH-1:0] hp;
    assign hp_out = hp;
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
    logic [1:0] read_type; // 0: CAR, 1: CDR
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hp <= 0;
            heap_we_car <= 0;
            heap_we_cdr <= 0;
            valid <= 0;
            error <= 0;
            reading_state <= 0;
            result <= '0;
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
                    result <= (read_type == 0) ? heap_car_out : heap_cdr_out;
                end
            end else if (cmd_peek) begin
                heap_addr <= peek_addr;
                reading_state <= 1;
                is_peek <= 1;
            end else if (cmd_cons) begin
                // CONS operation — check heap overflow first
                if (hp == (1 << HEAP_ADDR_WIDTH) - 1) begin
                    // Heap is full: cannot allocate. Raise error so
                    // control.sv halts the machine with err_flag set,
                    // instead of silently wrapping hp to 0 and
                    // corrupting live cons cells.
                    error <= 1; // HEAP_FULL
                end else begin
                    heap_we_car <= 1;
                    heap_we_cdr <= 1;
                    heap_addr <= hp;
                    heap_car_in <= op_a;
                    heap_cdr_in <= op_b;

                    result.tag <= TAG_CONS;
                    result.value <= { {(28-HEAP_ADDR_WIDTH){1'b0}}, hp };
                    valid <= 1;

                    hp <= hp + 1; // Bump allocator
                end
            end else if (cmd_setcdr) begin
                // Internal bootstrap-only capability, never exposed as an
                // ordinary Lisp primitive through eval: overwrites the CDR
                // of an EXISTING cons cell (op_a, must already be TAG_CONS)
                // with op_b, in place. This is the one deliberate exception
                // to "the heap never mutates a cell after CONS allocates
                // it" -- needed so a closure can be backpatched to see
                // itself in its own captured environment (letrec-style
                // self-reference), the same capability boundary that keeps
                // def/defmacro in the my-lisp Rust host rather than
                // expressed in pure immutable-cons my-lisp (see
                // lib/meta-eval.my's own documented, unresolved gap here --
                // confirmed with the my-lisp session, 2026-08-10, that this
                // Rust-host-only mutation is the *only* known working
                // mechanism, not a shortcut around a solved problem).
                if (op_a.tag == TAG_CONS) begin
                    heap_we_cdr <= 1;
                    heap_addr <= op_a.value[HEAP_ADDR_WIDTH-1:0];
                    heap_cdr_in <= op_b;
                    result <= op_b;
                    valid <= 1;
                end else begin
                    error <= 1; // TYPE_ERROR: can't SETCDR a non-cons
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

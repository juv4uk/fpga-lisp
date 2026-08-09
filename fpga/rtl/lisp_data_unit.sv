module lisp_data_unit #(
    parameter integer HEAP_ADDR_WIDTH = 12
) (
    input  logic             clk,
    input  logic             rst_n,
    
    // Commands
    input  logic             cmd_cons,
    input  logic             cmd_car,
    input  logic             cmd_cdr,
    
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
    logic                     heap_we;
    logic [HEAP_ADDR_WIDTH-1:0] heap_addr;
    lisp_word_t               heap_car_in;
    lisp_word_t               heap_cdr_in;
    lisp_word_t               heap_car_out;
    lisp_word_t               heap_cdr_out;
    
    heap #(
        .ADDR_WIDTH(HEAP_ADDR_WIDTH)
    ) u_heap (
        .clk(clk),
        .we(heap_we),
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
            heap_we <= 0;
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
            heap_we <= 0;
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
                // CONS operation
                heap_we <= 1;
                heap_addr <= hp;
                heap_car_in <= op_a;
                heap_cdr_in <= op_b;
                
                result.tag <= TAG_CONS;
                result.value <= { {(28-HEAP_ADDR_WIDTH){1'b0}}, hp };
                valid <= 1;
                
                hp <= hp + 1; // Bump allocator
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

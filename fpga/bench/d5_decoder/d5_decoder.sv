// D5 exact-width decoder benchmark for fpga-lisp#45.
//
// Research/cost evidence only.  This module does NOT assign SENS semantics.
// The selector subtree is generator-owned upstream; 00101 TRANSFORMER remains
// an upstream ratification candidate.
//
// Normalized outputs let the flat and structured decoders be compared on the
// exact same behavior for all 32 possible width-5 words.

module d5_flat_decoder (
    input  logic [4:0] word,
    output logic       occupied,
    output logic       is_selector,
    output logic       selector_root_is_cdr,
    output logic [1:0] selector_suffix,
    output logic       is_transformer,
    output logic       reserved_fail
);
    always_comb begin
        occupied            = 1'b0;
        is_selector         = 1'b0;
        selector_root_is_cdr = 1'b0;
        selector_suffix     = 2'b00;
        is_transformer      = 1'b0;

        case (word)
            5'b00101: begin
                occupied       = 1'b1;
                is_transformer = 1'b1;
            end

            5'b10100: begin occupied = 1'b1; is_selector = 1'b1; selector_root_is_cdr = 1'b0; selector_suffix = 2'b00; end
            5'b10101: begin occupied = 1'b1; is_selector = 1'b1; selector_root_is_cdr = 1'b0; selector_suffix = 2'b01; end
            5'b10110: begin occupied = 1'b1; is_selector = 1'b1; selector_root_is_cdr = 1'b0; selector_suffix = 2'b10; end
            5'b10111: begin occupied = 1'b1; is_selector = 1'b1; selector_root_is_cdr = 1'b0; selector_suffix = 2'b11; end

            5'b11000: begin occupied = 1'b1; is_selector = 1'b1; selector_root_is_cdr = 1'b1; selector_suffix = 2'b00; end
            5'b11001: begin occupied = 1'b1; is_selector = 1'b1; selector_root_is_cdr = 1'b1; selector_suffix = 2'b01; end
            5'b11010: begin occupied = 1'b1; is_selector = 1'b1; selector_root_is_cdr = 1'b1; selector_suffix = 2'b10; end
            5'b11011: begin occupied = 1'b1; is_selector = 1'b1; selector_root_is_cdr = 1'b1; selector_suffix = 2'b11; end

            default: begin end
        endcase

        reserved_fail = ~occupied;
    end
endmodule


module d5_hybrid_decoder (
    input  logic [4:0] word,
    output logic       occupied,
    output logic       is_selector,
    output logic       selector_root_is_cdr,
    output logic [1:0] selector_suffix,
    output logic       is_transformer,
    output logic       reserved_fail
);
    logic selector_car_family;
    logic selector_cdr_family;

    always_comb begin
        selector_car_family = (word[4:2] == 3'b101);
        selector_cdr_family = (word[4:2] == 3'b110);

        is_selector          = selector_car_family | selector_cdr_family;
        selector_root_is_cdr = selector_cdr_family;
        selector_suffix      = is_selector ? word[1:0] : 2'b00;

        is_transformer = (word == 5'b00101);
        occupied       = is_selector | is_transformer;
        reserved_fail  = ~occupied;
    end
endmodule


module d5_selector_only_decoder (
    input  logic [4:0] word,
    output logic       occupied,
    output logic       is_selector,
    output logic       selector_root_is_cdr,
    output logic [1:0] selector_suffix,
    output logic       is_transformer,
    output logic       reserved_fail
);
    logic selector_car_family;
    logic selector_cdr_family;

    always_comb begin
        selector_car_family = (word[4:2] == 3'b101);
        selector_cdr_family = (word[4:2] == 3'b110);

        is_selector          = selector_car_family | selector_cdr_family;
        selector_root_is_cdr = selector_cdr_family;
        selector_suffix      = is_selector ? word[1:0] : 2'b00;

        is_transformer = 1'b0;
        occupied       = is_selector;
        reserved_fail  = ~occupied;
    end
endmodule

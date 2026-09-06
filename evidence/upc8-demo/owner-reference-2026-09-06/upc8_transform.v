// ============================================================================
// upc8_transform.v — Combinational Phonological Transform Engine
// ============================================================================
// Epistemic status: embryo sūtra-processor (Step B toward Step C)
// Target: Gowin GW5A-LV25MG121
//
// Performs single-cycle (combinational) transforms on 8-bit UPC codes.
// Two sub-engines:
//   A. Class 10 (vowels): toggle length, toggle nasal, next/prev row, guṇa
//   B. Class 00 (canonical consonants): voice / aspirate LUT (embryo)
//
// OP codes:
//   3\'b000 = NOP
//   3\'b001 = TOGGLE_LENGTH   (class 10 only)
//   3\'b010 = TOGGLE_NASAL    (class 10 only)
//   3\'b011 = NEXT_ROW        (class 10, wrap 6->0)
//   3\'b100 = PREV_ROW        (class 10, wrap 0->6)
//   3\'b101 = GUNA            (class 10 only, a->e, i/u/R/L->a, e->ai, o->au)
//   3\'b110 = VOICE           (class 00 embryo LUT: k->g, c->j, etc.)
//   3\'b111 = ASPIRATE        (class 00 embryo LUT: k->kh, g->gh, etc.)
// ============================================================================

`timescale 1ns / 1ps

module upc8_transform (
    input  wire [7:0] code_in,
    input  wire [2:0] op,
    output reg  [7:0] code_out,
    output reg        valid,
    output reg        error
);

    // ------------------------------------------------------------------------
    // OP encoding
    // ------------------------------------------------------------------------
    localparam OP_NOP            = 3\'b000;
    localparam OP_TOGGLE_LENGTH  = 3\'b001;
    localparam OP_TOGGLE_NASAL   = 3\'b010;
    localparam OP_NEXT_ROW       = 3\'b011;
    localparam OP_PREV_ROW       = 3\'b100;
    localparam OP_GUNA           = 3\'b101;
    localparam OP_VOICE          = 3\'b110;
    localparam OP_ASPIRATE       = 3\'b111;

    // ------------------------------------------------------------------------
    // Field extraction from code_in
    // ------------------------------------------------------------------------
    wire [1:0] cls       = code_in[7:6];
    wire [2:0] row       = code_in[5:3];
    wire       free_bit  = code_in[2];
    wire       nasal     = code_in[1];
    wire       length    = code_in[0];

    wire is_class10 = (cls == 2\'b10);
    wire is_class00 = (cls == 2\'b00);
    wire in_skt_layer = is_class10 && !free_bit;

    // ------------------------------------------------------------------------
    // Combinational transform logic
    // ------------------------------------------------------------------------
    always @(*) begin
        // Defaults
        code_out = code_in;
        valid    = 1\'b1;
        error    = 1\'b0;

        case (op)
            OP_NOP: begin
                code_out = code_in;
            end

            // ----------------------------------------------------------------
            // Class 10 vowel operations
            // ----------------------------------------------------------------
            OP_TOGGLE_LENGTH: begin
                if (in_skt_layer) begin
                    code_out = code_in ^ 8\'h01;  // flip bit [0]
                end else begin
                    error = 1\'b1;
                end
            end

            OP_TOGGLE_NASAL: begin
                if (in_skt_layer) begin
                    code_out = code_in ^ 8\'h02;  // flip bit [1]
                end else begin
                    error = 1\'b1;
                end
            end

            OP_NEXT_ROW: begin
                if (in_skt_layer) begin
                    if (row < 3\'d6) begin
                        code_out = code_in + 8\'h08;
                    end else if (row == 3\'d6) begin
                        // wrap row 6 -> row 0, preserve class + lower bits
                        code_out = {code_in[7:6], 3\'b000, code_in[2:0]};
                    end else begin
                        error = 1\'b1;  // row 7 is reserved
                    end
                end else begin
                    error = 1\'b1;
                end
            end

            OP_PREV_ROW: begin
                if (in_skt_layer) begin
                    if (row > 3\'d0 && row <= 3\'d6) begin
                        code_out = code_in - 8\'h08;
                    end else if (row == 3\'d0) begin
                        // wrap row 0 -> row 6
                        code_out = {code_in[7:6], 3\'b110, code_in[2:0]};
                    end else begin
                        error = 1\'b1;
                    end
                end else begin
                    error = 1\'b1;
                end
            end

            OP_GUNA: begin
                // Guṇa (Sūtra 1.1.2 / 1.1.5 embryo):
                //   a -> e        (row 0 -> row 5)
                //   i/u/R/L -> a  (row 1,2,3,4 -> row 0)
                //   e -> ai       (row 5 -> row 5 + length=1)
                //   o -> au       (row 6 -> row 6 + length=1)
                if (in_skt_layer && !nasal) begin
                    case (row)
                        3\'d0: code_out = {code_in[7:6], 3\'d101, code_in[2:0]}; // a -> e
                        3\'d1: code_out = {code_in[7:6], 3\'d000, code_in[2:0]}; // i -> a
                        3\'d2: code_out = {code_in[7:6], 3\'d000, code_in[2:0]}; // u -> a
                        3\'d3: code_out = {code_in[7:6], 3\'d000, code_in[2:0]}; // R -> a
                        3\'d4: code_out = {code_in[7:6], 3\'d000, code_in[2:0]}; // L -> a
                        3\'d5: code_out = code_in | 8\'h01;                    // e -> ai (set length)
                        3\'d6: code_out = code_in | 8\'h01;                    // o -> au (set length)
                        default: error = 1\'b1;
                    endcase
                end else begin
                    error = 1\'b1;
                end
            end

            // ----------------------------------------------------------------
            // Class 00 consonant embryo LUTs (Step C precursor)
            // NOTE: canonical class 00 codes use bit 2 as part of the code,
            // not as a free-bit flag. Therefore no !free_bit check here.
            // ----------------------------------------------------------------
            OP_VOICE: begin
                if (is_class00) begin
                    case (code_in)
                        // Kanthya
                        8\'h23: code_out = 8\'h18; // k  -> g
                        8\'h1B: code_out = 8\'h13; // kh -> gh
                        // Talavya
                        8\'h20: code_out = 8\'h16; // c  -> j
                        8\'h1D: code_out = 8\'h11; // ch -> jh
                        // Murdhanya
                        8\'h21: code_out = 8\'h19; // T  -> D
                        8\'h1E: code_out = 8\'h14; // Th -> Dh
                        // Dantya
                        8\'h22: code_out = 8\'h1A; // t  -> d
                        8\'h1F: code_out = 8\'h15; // th -> dh
                        // Oshthya
                        8\'h24: code_out = 8\'h17; // p  -> b
                        8\'h1C: code_out = 8\'h12; // ph -> bh
                        default: begin
                            error = 1\'b1;
                            code_out = code_in;
                        end
                    endcase
                end else begin
                    error = 1\'b1;
                end
            end

            OP_ASPIRATE: begin
                if (is_class00) begin
                    case (code_in)
                        // Kanthya
                        8\'h23: code_out = 8\'h1B; // k  -> kh
                        8\'h18: code_out = 8\'h13; // g  -> gh
                        // Talavya
                        8\'h20: code_out = 8\'h1D; // c  -> ch
                        8\'h16: code_out = 8\'h11; // j  -> jh
                        // Murdhanya
                        8\'h21: code_out = 8\'h1E; // T  -> Th
                        8\'h19: code_out = 8\'h14; // D  -> Dh
                        // Dantya
                        8\'h22: code_out = 8\'h1F; // t  -> th
                        8\'h1A: code_out = 8\'h15; // d  -> dh
                        // Oshthya
                        8\'h24: code_out = 8\'h1C; // p  -> ph
                        8\'h17: code_out = 8\'h12; // b  -> bh
                        default: begin
                            error = 1\'b1;
                            code_out = code_in;
                        end
                    endcase
                end else begin
                    error = 1\'b1;
                end
            end

            default: begin
                error = 1\'b1;
                code_out = 8\'h00;
            end
        endcase
    end

endmodule

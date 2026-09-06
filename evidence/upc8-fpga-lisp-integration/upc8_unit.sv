// ============================================================================
// upc8_unit.sv — UPC-8 Phonetic Decode/Transform/Predicate Engine
// ============================================================================
// Epistemic status: class-10 authority (owner spec 2026-09-06)
// Integration: fpga-lisp encoded-mode primitive via MOV rs2=4/5/6
// Target: Gowin GW5A-LV25MG121 (Tang Primer 25K)
//
// Interface: lisp_word_t (tag + 28-bit value)
//   Input:  code_word.tag must be TAG_FIXNUM; value[7:0] = UPC-8 code
//           For TRANSFORM (rs2=5): value[10:8] = op, value[7:0] = code
//   Output: result.tag = TAG_FIXNUM; value = packed result
//   Latency: 0 cycles (purely combinational)
//
// Encoded-mode mapping (via MOV opcode, rs2 selector):
//   rs2 = 4 (UPC8_DECODE):    result[7:0] = {cls[1:0], row[2:0], free, nasal, length}
//                             result[8]   = is_class10
//                             result[9]   = ac_14
//                             result[10]  = an_pred
//                             result[11]  = ik_pred
//                             result[12]  = is_reserved_row
//   rs2 = 5 (UPC8_TRANSFORM):  result[7:0] = transformed code
//                             result[8]   = valid
//                             result[9]   = error
//                             result[15:10] = original op (echo for debug)
//   rs2 = 6 (UPC8_PREDICATE):  result[7:0] = {3'b0, is_reserved_row, ik_pred, an_pred, ac_14, is_class10}
//                             (bit-mask for pratyahara testing)
// ============================================================================

`include "lisp_word.sv"

module upc8_unit (
    input  lisp_word_t code_word,
    input  logic [3:0] rs2,           // 4=decode, 5=transform, 6=predicate
    output lisp_word_t result,
    output logic       valid,
    output logic       error
);

    // ------------------------------------------------------------------------
    // Unpack UPC-8 fields from FIXNUM value[7:0]
    // ------------------------------------------------------------------------
    wire [7:0] code = code_word.value[7:0];
    wire [1:0] cls       = code[7:6];
    wire [2:0] row       = code[5:3];
    wire       free_bit  = code[2];
    wire       nasal     = code[1];
    wire       length    = code[0];

    wire is_class10 = (cls == 2\'b10);
    wire is_class00 = (cls == 2\'b00);
    wire in_skt_layer = is_class10 && !free_bit;
    wire row_valid = (row < 3\'d7);

    // ------------------------------------------------------------------------
    // Pratyahara predicates (combinational)
    // ------------------------------------------------------------------------
    wire ac_14  = in_skt_layer && row_valid && !nasal;
    wire an_pred = in_skt_layer && (row < 3\'d5) && !nasal;
    wire ik_pred = in_skt_layer && (row >= 3\'d1) && (row < 3\'d5) && !nasal;
    wire is_reserved_row = is_class10 && (row == 3\'d7);

    // ------------------------------------------------------------------------
    // Transform op unpacking (for rs2=5)
    //   value[10:8] = op, value[7:0] = code
    // ------------------------------------------------------------------------
    wire [2:0] op = code_word.value[10:8];

    // ------------------------------------------------------------------------
    // Transform logic (combinational)
    // ------------------------------------------------------------------------
    reg [7:0] transform_out;
    reg       transform_valid;
    reg       transform_error;

    localparam OP_NOP            = 3\'b000;
    localparam OP_TOGGLE_LENGTH  = 3\'b001;
    localparam OP_TOGGLE_NASAL   = 3\'b010;
    localparam OP_NEXT_ROW       = 3\'b011;
    localparam OP_PREV_ROW       = 3\'b100;
    localparam OP_GUNA           = 3\'b101;
    localparam OP_VOICE          = 3\'b110;
    localparam OP_ASPIRATE       = 3\'b111;

    always @(*) begin
        transform_out   = code;
        transform_valid = 1\'b1;
        transform_error = 1\'b0;

        case (op)
            OP_NOP: begin
                transform_out = code;
            end

            OP_TOGGLE_LENGTH: begin
                if (in_skt_layer) begin
                    transform_out = code ^ 8\'h01;
                end else begin
                    transform_error = 1\'b1;
                end
            end

            OP_TOGGLE_NASAL: begin
                if (in_skt_layer) begin
                    transform_out = code ^ 8\'h02;
                end else begin
                    transform_error = 1\'b1;
                end
            end

            OP_NEXT_ROW: begin
                if (in_skt_layer) begin
                    if (row < 3\'d6)
                        transform_out = code + 8\'h08;
                    else if (row == 3\'d6)
                        transform_out = {code[7:6], 3\'b000, code[2:0]};
                    else
                        transform_error = 1\'b1;
                end else begin
                    transform_error = 1\'b1;
                end
            end

            OP_PREV_ROW: begin
                if (in_skt_layer) begin
                    if (row > 3\'d0 && row <= 3\'d6)
                        transform_out = code - 8\'h08;
                    else if (row == 3\'d0)
                        transform_out = {code[7:6], 3\'b110, code[2:0]};
                    else
                        transform_error = 1\'b1;
                end else begin
                    transform_error = 1\'b1;
                end
            end

            OP_GUNA: begin
                if (in_skt_layer && !nasal) begin
                    case (row)
                        3\'d0: transform_out = {code[7:6], 3\'d101, code[2:0]};
                        3\'d1: transform_out = {code[7:6], 3\'d000, code[2:0]};
                        3\'d2: transform_out = {code[7:6], 3\'d000, code[2:0]};
                        3\'d3: transform_out = {code[7:6], 3\'d000, code[2:0]};
                        3\'d4: transform_out = {code[7:6], 3\'d000, code[2:0]};
                        3\'d5: transform_out = code | 8\'h01;
                        3\'d6: transform_out = code | 8\'h01;
                        default: transform_error = 1\'b1;
                    endcase
                end else begin
                    transform_error = 1\'b1;
                end
            end

            OP_VOICE: begin
                if (is_class00) begin
                    case (code)
                        8\'h23: transform_out = 8\'h18;
                        8\'h1B: transform_out = 8\'h13;
                        8\'h20: transform_out = 8\'h16;
                        8\'h1D: transform_out = 8\'h11;
                        8\'h21: transform_out = 8\'h19;
                        8\'h1E: transform_out = 8\'h14;
                        8\'h22: transform_out = 8\'h1A;
                        8\'h1F: transform_out = 8\'h15;
                        8\'h24: transform_out = 8\'h17;
                        8\'h1C: transform_out = 8\'h12;
                        default: transform_error = 1\'b1;
                    endcase
                end else begin
                    transform_error = 1\'b1;
                end
            end

            OP_ASPIRATE: begin
                if (is_class00) begin
                    case (code)
                        8\'h23: transform_out = 8\'h1B;
                        8\'h18: transform_out = 8\'h13;
                        8\'h20: transform_out = 8\'h1D;
                        8\'h16: transform_out = 8\'h11;
                        8\'h21: transform_out = 8\'h1E;
                        8\'h19: transform_out = 8\'h14;
                        8\'h22: transform_out = 8\'h1F;
                        8\'h1A: transform_out = 8\'h15;
                        8\'h24: transform_out = 8\'h1C;
                        8\'h17: transform_out = 8\'h12;
                        default: transform_error = 1\'b1;
                    endcase
                end else begin
                    transform_error = 1\'b1;
                end
            end

            default: begin
                transform_error = 1\'b1;
                transform_out = 8\'h00;
            end
        endcase
    end

    // ------------------------------------------------------------------------
    // Output multiplexing based on rs2 (cmd selector)
    // ------------------------------------------------------------------------
    always @(*) begin
        // Defaults
        result = \'0;
        valid  = 1\'b1;
        error  = 1\'b0;

        case (rs2)
            4\'d4: begin  // UPC8_DECODE
                // result[7:0]  = raw code (echo)
                // result[8]    = is_class10
                // result[9]    = ac_14
                // result[10]   = an_pred
                // result[11]   = ik_pred
                // result[12]   = is_reserved_row
                // result[15:13] = row[2:0]
                result.tag   = TAG_FIXNUM;
                result.value = {12\'d0,
                                row[2:0],           // [15:13]
                                is_reserved_row,    // [12]
                                ik_pred,            // [11]
                                an_pred,            // [10]
                                ac_14,              // [9]
                                is_class10,         // [8]
                                code[7:0]};         // [7:0]
            end

            4\'d5: begin  // UPC8_TRANSFORM
                result.tag   = TAG_FIXNUM;
                result.value = {12\'d0,
                                op[2:0],            // [15:13] — echo op for debug
                                3\'b0,              // [12:10]
                                transform_error,    // [9]
                                transform_valid,    // [8]
                                transform_out[7:0]};// [7:0]
                valid = transform_valid;
                error = transform_error;
            end

            4\'d6: begin  // UPC8_PREDICATE
                // result[7:0] = bit-mask:
                //   [0] = is_class10
                //   [1] = ac_14
                //   [2] = an_pred
                //   [3] = ik_pred
                //   [4] = is_reserved_row
                result.tag   = TAG_FIXNUM;
                result.value = {20\'d0,
                                3\'b0,              // [7:5]
                                is_reserved_row,    // [4]
                                ik_pred,            // [3]
                                an_pred,            // [2]
                                ac_14,              // [1]
                                is_class10};        // [0]
            end

            default: begin
                // Unknown rs2 — pass-through (NOP behavior for safety)
                result = code_word;
                error  = 1\'b1;
            end
        endcase
    end

endmodule

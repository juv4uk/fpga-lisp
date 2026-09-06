// ============================================================================
// upc8_decode.v — UPC-8 Field Extractor & Pratyāhāra Predicate Engine
// ============================================================================
// Epistemic status: engineering spec validated by upc8_class10_check.py
// Target: Gowin GW5A-LV25MG121 (Tang Primer 25K)
//
// Decodes 8-bit UPC code into structured fields and computes single-cycle
// pratyāhāra predicates for class 10 (vowels, 0x80–0xBF).
//
// Bit layout (class 10):
//   [7:6] = CLASS = 2'b10
//   [5:3] = ROW   (0=a, 1=i, 2=u, 3=ṛ, 4=ḷ, 5=e, 6=o, 7=reserved)
//   [2]   = FREE  (reserved for language extensions, 0 in Sanskrit layer)
//   [1]   = NASAL (0=plain, 1=nasalized)
//   [0]   = LENGTH (0=short, 1=long/vṛddhi)
//
// Predicates (combinational, single-cycle):
//   ac_14  — all 14 vowels (short+long, no nasal, no free, row<7)
//   an_pred — aṇ = 5 (rows 0–4, no nasal, no free)
//   ik_pred — ik = 4 (rows 1–4, no nasal, no free)
// ============================================================================

`timescale 1ns / 1ps

module upc8_decode (
    input  wire [7:0] code,

    // Raw fields
    output wire [1:0] cls,
    output wire [2:0] row,
    output wire       free_bit,
    output wire       nasal,
    output wire       length,

    // Class membership
    output wire       is_class10,
    output wire       is_class00,
    output wire       is_class01,
    output wire       is_class11,

    // Pratyāhāra predicates (class 10 only)
    output wire       ac_14,          // 14 vowels (7 short + 7 long)
    output wire       an_pred,        // aṇ = a i u ṛ ḷ
    output wire       ik_pred,        // ik = i u ṛ ḷ
    output wire       is_reserved_row // row == 7 (0xB8–0xBF)
);

    // ------------------------------------------------------------------------
    // Field extraction (wires — zero logic delay)
    // ------------------------------------------------------------------------
    assign cls      = code[7:6];
    assign row      = code[5:3];
    assign free_bit = code[2];
    assign nasal    = code[1];
    assign length   = code[0];

    // ------------------------------------------------------------------------
    // Class predicates
    // ------------------------------------------------------------------------
    assign is_class10 = (cls == 2'b10);
    assign is_class00 = (cls == 2'b00);
    assign is_class01 = (cls == 2'b01);
    assign is_class11 = (cls == 2'b11);

    // ------------------------------------------------------------------------
    // Sanskrit-layer guard: class 10 AND free bit cleared
    // ------------------------------------------------------------------------
    wire in_sanskrit_layer = is_class10 && !free_bit;
    wire row_valid_sanskrit = (row < 3'd7);   // rows 0–6 are valid

    // ------------------------------------------------------------------------
    // Pratyāhāra predicates (all single-cycle combinational)
    //
    // NOTE: ac_14 here is the *expanded* set (short+long) for class 10.
    // The canonical ac (9 sounds) lives in the 0x00–0x29 ROM in fpga_alu.v.
    // This module covers the *new* class 10 encoding space.
    // ------------------------------------------------------------------------
    assign ac_14  = in_sanskrit_layer && row_valid_sanskrit && !nasal;
    assign an_pred = in_sanskrit_layer && (row < 3'd5) && !nasal;
    assign ik_pred = in_sanskrit_layer && (row >= 3'd1) && (row < 3'd5) && !nasal;

    assign is_reserved_row = is_class10 && (row == 3'd7);

endmodule

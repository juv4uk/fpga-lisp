// ============================================================================
// FPGA Lisp Phonetic Vector ALU (fpga_alu.v)
// ============================================================================
`timescale 1ns / 1ps

module fpga_alu #(
    parameter integer DATA_WIDTH = 32
) (
    input  wire                  clk,
    input  wire                  rst_n,
    
    // ALU Control
    input  wire [3:0]            alu_op,
    
    // Operands
    input  wire [DATA_WIDTH-1:0] op_a,       // PVC-16 sound or Sound Code [5:0]
    input  wire [DATA_WIDTH-1:0] op_b,       // PVC-16 sound, Prat ID, or Mask Lo [31:0]
    input  wire [DATA_WIDTH-1:0] op_ext,     // Extended Operand (Mask Hi [31:0])
    input  wire [63:0]           mask_in,    // Direct 64-bit mask input port
    
    // Outputs
    output reg  [DATA_WIDTH-1:0] result,     // Primary ALU 32-bit result
    output reg                   flag_savarna,// Single-cycle 1.1.9 Savarṇa flag
    output reg                   flag_member, // Single-cycle Pratyāhāra membership flag
    output reg                   flag_zero,   // Zero flag
    output reg                   valid,       // Result valid
    output reg                   error        // Invalid sound code or malformed vector
);

    localparam [3:0] OP_NOP             = 4'h0;
    localparam [3:0] OP_SAVARNA         = 4'h1;
    localparam [3:0] OP_VOICING         = 4'h2;
    localparam [3:0] OP_DEVOICING       = 4'h3;
    localparam [3:0] OP_PALATALIZATION  = 4'h4;
    localparam [3:0] OP_DEPALATALIZE    = 4'h5;
    localparam [3:0] OP_PRATYAHARA_TEST = 4'h6;
    localparam [3:0] OP_PRATYAHARA_ROM  = 4'h7;
    localparam [3:0] OP_SANDHI_VOICE    = 4'h8;
    localparam [3:0] OP_ADD             = 4'h9;
    localparam [3:0] OP_SUB             = 4'hA;
    localparam [3:0] OP_AND             = 4'hB;
    localparam [3:0] OP_OR              = 4'hC;
    localparam [3:0] OP_XOR             = 4'hD;
    localparam [3:0] OP_STHANA_TEST     = 4'hE;
    localparam [3:0] OP_PRAYATNA_TEST   = 4'hF;

    wire [15:0] sound_a = op_a[15:0];
    wire [15:0] sound_b = op_b[15:0];

    wire        vow_a   = sound_a[0];
    wire        vow_b   = sound_b[0];
    wire [4:0]  sth_a   = sound_a[5:1];
    wire [4:0]  sth_b   = sound_b[5:1];
    wire        spr_a   = sound_a[6];
    wire        spr_b   = sound_b[6];

    // Sūtra 1.1.9: tulyāsyaprayatnaṁ savarṇam
    wire same_sthana_comb   = (sth_a == sth_b) && (sth_a != 5'b00000);
    wire same_prayatna_comb = (spr_a == spr_b) && (vow_a == vow_b);
    wire is_savarna_comb    = same_sthana_comb && same_prayatna_comb;

    // Voicing & Palatalization
    wire [15:0] voiced_sound_comb     = sound_a | 16'h0100;
    wire [15:0] unvoiced_sound_comb   = sound_a & 16'hFEFF;
    wire [15:0] palatalized_comb      = sound_a | 16'h4000;
    wire [15:0] depalatalized_comb    = sound_a & 16'hBFFF;
    wire [15:0] sandhi_voiced_comb    = spr_a ? (sound_a | 16'h0100) : sound_a;

    // 64-bit Bitmask Tester
    wire [5:0]  sound_code = op_a[5:0];
    wire [5:0]  prat_rom_id = op_b[5:0];
    wire [63:0] effective_dynamic_mask = (|mask_in) ? mask_in : {op_ext, op_b};
    wire is_dynamic_member_comb = (sound_code < 6'd42) ? effective_dynamic_mask[sound_code] : 1'b0;

    // Classical 42-Pratyāhāra ROM
    reg [63:0] rom_mask;
    always @(*) begin
        case (prat_rom_id)
            6'd0:  rom_mask = 64'h00000000000001FF; // ac
            6'd1:  rom_mask = 64'h000000000000001F; // ak
            6'd2:  rom_mask = 64'h000000000000001E; // ik
            6'd3:  rom_mask = 64'h000000000000001C; // uk
            6'd4:  rom_mask = 64'h0000000000000060; // eN
            6'd5:  rom_mask = 64'h00000000000001E0; // ec
            6'd6:  rom_mask = 64'h0000000000000180; // Ec
            6'd7:  rom_mask = 64'h000003FFFFFFFFFF; // al
            6'd8:  rom_mask = 64'h000003FFFFFFFFFE00; // hal
            6'd9:  rom_mask = 64'h000003FFFFFFFFFC00; // val
            6'd10: rom_mask = 64'h000003FFFFFFFFF000; // ral
            6'd11: rom_mask = 64'h000003FFFFFFFE0200; // Jal
            6'd12: rom_mask = 64'h0000038000000200; // Sal
            6'd13: rom_mask = 64'h0000038000000000; // Sar
            6'd14: rom_mask = 64'h000003FFFFFFFFFC00; // yar
            6'd15: rom_mask = 64'h0000007FFFFFFFFC00; // yay
            6'd16: rom_mask = 64'h0000000000003C00; // yaR
            6'd17: rom_mask = 64'h000000000007FC00; // yam
            6'd18: rom_mask = 64'h00000000001FFC00; // yaY
            6'd19: rom_mask = 64'h0000000000001800; // vaw
            6'd20: rom_mask = 64'h0000007FFFFFF78000; // may
            6'd21: rom_mask = 64'h000000000007FDFF; // am
            6'd22: rom_mask = 64'h0000000000001FFF; // aw
            6'd23: rom_mask = 64'h0000000000003FFE; // iR
            6'd24: rom_mask = 64'h0000000000000007; // aR
            6'd25: rom_mask = 64'h0000000000000060; // eR
            6'd26: rom_mask = 64'h0000000000070000; // nam
            6'd27: rom_mask = 64'h000000001FFE0000; // JaS
            6'd28: rom_mask = 64'h000000001F000000; // jaS
            6'd29: rom_mask = 64'h000000000F000000; // baS
            6'd30: rom_mask = 64'h0000000000FE0000; // Jaz
            6'd31: rom_mask = 64'h00000000007E0000; // Baz
            6'd32: rom_mask = 64'h0000007FFFFFE000; // Jay
            6'd33: rom_mask = 64'h0000007FFE000000; // Kay
            6'd34: rom_mask = 64'h0000001FFE000000; // xay
            6'd35: rom_mask = 64'h000003FE00000000; // car
            6'd36: rom_mask = 64'h0000000E00000000; // cav
            6'd37: rom_mask = 64'h0000000600000000; // caw
            6'd38: rom_mask = 64'h000003FFE0000000; // Kar
            6'd39: rom_mask = 64'h000003FFFFFFE000; // Jar
            6'd40: rom_mask = 64'h000000001FFFFE00; // haS
            6'd41: rom_mask = 64'h000003FFFFFFFFFC00; // yar
            default: rom_mask = 64'h0000000000000000;
        endcase
    end

    wire is_rom_member_comb = (sound_code < 6'd42 && prat_rom_id < 6'd42) ? rom_mask[sound_code] : 1'b0;

    // Synchronous Registered Stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result       <= {DATA_WIDTH{1'b0}};
            flag_savarna <= 1'b0;
            flag_member  <= 1'b0;
            flag_zero    <= 1'b0;
            valid        <= 1'b0;
            error        <= 1'b0;
        end else begin
            valid        <= 1'b1;
            error        <= 1'b0;
            flag_savarna <= is_savarna_comb;
            
            case (alu_op)
                OP_NOP: begin
                    result      <= op_a;
                    flag_member <= 1'b0;
                end
                OP_SAVARNA: begin
                    result      <= { { (DATA_WIDTH-1){1'b0} }, is_savarna_comb };
                    flag_member <= 1'b0;
                    if (sth_a == 5'b0 || sth_b == 5'b0) error <= 1'b1;
                end
                OP_VOICING: begin
                    result      <= { { (DATA_WIDTH-16){1'b0} }, voiced_sound_comb };
                    flag_member <= 1'b0;
                end
                OP_DEVOICING: begin
                    result      <= { { (DATA_WIDTH-16){1'b0} }, unvoiced_sound_comb };
                    flag_member <= 1'b0;
                end
                OP_PALATALIZATION: begin
                    result      <= { { (DATA_WIDTH-16){1'b0} }, palatalized_comb };
                    flag_member <= 1'b0;
                end
                OP_DEPALATALIZE: begin
                    result      <= { { (DATA_WIDTH-16){1'b0} }, depalatalized_comb };
                    flag_member <= 1'b0;
                end
                OP_PRATYAHARA_TEST: begin
                    result      <= { { (DATA_WIDTH-1){1'b0} }, is_dynamic_member_comb };
                    flag_member <= is_dynamic_member_comb;
                    if (sound_code >= 6'd42) error <= 1'b1;
                end
                OP_PRATYAHARA_ROM: begin
                    result      <= { { (DATA_WIDTH-1){1'b0} }, is_rom_member_comb };
                    flag_member <= is_rom_member_comb;
                    if (sound_code >= 6'd42 || prat_rom_id >= 6'd42) error <= 1'b1;
                end
                OP_SANDHI_VOICE: begin
                    result      <= { { (DATA_WIDTH-16){1'b0} }, sandhi_voiced_comb };
                    flag_member <= 1'b0;
                end
                OP_ADD: begin
                    result      <= op_a + op_b;
                    flag_member <= 1'b0;
                end
                OP_SUB: begin
                    result      <= op_a - op_b;
                    flag_member <= 1'b0;
                end
                OP_AND: begin
                    result      <= op_a & op_b;
                    flag_member <= 1'b0;
                end
                OP_OR: begin
                    result      <= op_a | op_b;
                    flag_member <= 1'b0;
                end
                OP_XOR: begin
                    result      <= op_a ^ op_b;
                    flag_member <= 1'b0;
                end
                OP_STHANA_TEST: begin
                    result      <= { { (DATA_WIDTH-1){1'b0} }, same_sthana_comb };
                    flag_member <= 1'b0;
                end
                OP_PRAYATNA_TEST: begin
                    result      <= { { (DATA_WIDTH-1){1'b0} }, same_prayatna_comb };
                    flag_member <= 1'b0;
                end
                default: begin
                    result      <= {DATA_WIDTH{1'b0}};
                    flag_member <= 1'b0;
                    error       <= 1'b1;
                end
            endcase
            flag_zero <= (result == {DATA_WIDTH{1'b0}});
        end
    end
endmodule

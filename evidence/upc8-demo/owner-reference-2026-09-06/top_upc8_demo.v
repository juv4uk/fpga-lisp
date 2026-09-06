// ============================================================================
// top_upc8_demo.v — UPC-8 Decode & Transform Demo (Tang Primer 25K)
// ============================================================================
// Hardware:
//   - Tang Primer 25K Dock (GW5A-LV25MG121)
//   - 50 MHz crystal on E2
//   - 2 buttons on H10 (S2) and H11 (S1), active-high, need pulldown
//   - 1 user LED on L6 (onboard)
//   - 8 external LEDs on PMOD/40-pin header (pmod_io[0..7])
//   - 5 DIP switches on PMOD/40-pin header (pmod_io[8..12])
//
// Operation:
//   - sw[4:2] selects row (0-7), sw[1]=length, sw[0]=nasal
//   - Base code = 0x80 | (row<<3) | (nasal<<1) | length
//   - LED[7:0] shows decode predicates + transform status
//   - btn[0] (H11) short-press: cycle through transform ops
//   - btn[1] (H10) reset code to switch settings
// ============================================================================

`timescale 1ns / 1ps

module top_upc8_demo (
    input  wire       clk,      // 50 MHz from crystal (E2)
    input  wire       rst_n,    // Active-low reset (or tie high)

    // Buttons: active-high, need FPGA pulldown
    input  wire [1:0] btn,      // btn[0]=H11(S1), btn[1]=H10(S2)

    // Switches: external DIP or jumpers on 40-pin header
    input  wire [4:0] sw,       // sw[4:2]=row, sw[1]=length, sw[0]=nasal

    // LEDs
    output wire [7:0] led_ext,  // External LEDs (PMOD or 40-pin)
    output wire       led_onb   // Onboard LED (L6)
);

    // ------------------------------------------------------------------------
    // Clock divider for debounce (~1 kHz from 50 MHz)
    // ------------------------------------------------------------------------
    reg [15:0] clk_div;
    wire       clk_debounce = clk_div[15];  // ~763 Hz

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_div <= 16\'d0;
        else
            clk_div <= clk_div + 1\'b1;
    end

    // ------------------------------------------------------------------------
    // Button debounce (2-stage synchronizer + 10 ms counter)
    // 50 MHz -> 1 kHz debounce clock -> 10 ms = 10 counts
    // ------------------------------------------------------------------------
    reg [1:0] btn_sync [0:1];
    reg [1:0] btn_d;
    reg [1:0] btn_stable;
    reg [3:0] btn_cnt [0:1];
    reg [1:0] btn_edge;

    integer i;
    always @(posedge clk_debounce or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync[0] <= 2\'b00;
            btn_sync[1] <= 2\'b00;
            btn_d       <= 2\'b00;
            btn_stable  <= 2\'b00;
            btn_edge    <= 2\'b00;
            btn_cnt[0]  <= 4\'d0;
            btn_cnt[1]  <= 4\'d0;
        end else begin
            // Synchronizer
            btn_sync[0] <= btn;
            btn_sync[1] <= btn_sync[0];

            // Debounce counter per button
            for (i = 0; i < 2; i = i + 1) begin
                if (btn_sync[1][i] == btn_stable[i]) begin
                    btn_cnt[i] <= 4\'d0;
                end else begin
                    if (btn_cnt[i] < 4\'d10)
                        btn_cnt[i] <= btn_cnt[i] + 1\'b1;
                    else begin
                        btn_stable[i] <= btn_sync[1][i];
                        btn_cnt[i] <= 4\'d0;
                    end
                end
            end

            // Edge detect (rising edge only)
            btn_d <= btn_stable;
            btn_edge <= btn_stable & ~btn_d;
        end
    end

    // ------------------------------------------------------------------------
    // Base code from switches
    //   sw[4:2] = row (0-7)
    //   sw[1]   = length
    //   sw[0]   = nasal
    // ------------------------------------------------------------------------
    wire [7:0] base_code = {2\'b10, sw[4:2], 1\'b0, sw[1:0]};

    // ------------------------------------------------------------------------
    // Current code register
    //   Reset -> base_code
    //   btn[1] edge -> reset to base_code
    //   btn[0] edge -> apply next transform op
    // ------------------------------------------------------------------------
    reg [7:0] current_code;
    reg [2:0] current_op;

    localparam OP_MAX = 3\'b101;  // cycle through NOP..GUNA

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_code <= base_code;
            current_op   <= 3\'b000;
        end else begin
            if (btn_edge[1]) begin
                // Reset to switch settings
                current_code <= base_code;
                current_op   <= 3\'b000;
            end else if (btn_edge[0]) begin
                // Cycle op and apply transform
                if (current_op < OP_MAX)
                    current_op <= current_op + 1\'b1;
                else
                    current_op <= 3\'b000;
                // Transform result will be captured on next cycle
                // (combinational transform output -> registered code)
            end
        end
    end

    // Capture transform result when op changes
    wire [7:0] transform_out;
    wire       transform_valid;
    wire       transform_error;

    always @(posedge clk) begin
        if (btn_edge[0] && transform_valid && !transform_error)
            current_code <= transform_out;
    end

    // ------------------------------------------------------------------------
    // Decode & Transform instances
    // ------------------------------------------------------------------------
    wire [1:0] cls;
    wire [2:0] row;
    wire       free_bit, nasal, length;
    wire       is_class10, is_class00, is_class01, is_class11;
    wire       ac_14, an_pred, ik_pred, is_reserved_row;

    upc8_decode decode (
        .code(current_code),
        .cls(cls),
        .row(row),
        .free_bit(free_bit),
        .nasal(nasal),
        .length(length),
        .is_class10(is_class10),
        .is_class00(is_class00),
        .is_class01(is_class01),
        .is_class11(is_class11),
        .ac_14(ac_14),
        .an_pred(an_pred),
        .ik_pred(ik_pred),
        .is_reserved_row(is_reserved_row)
    );

    upc8_transform transform (
        .code_in(current_code),
        .op(current_op),
        .code_out(transform_out),
        .valid(transform_valid),
        .error(transform_error)
    );

    // ------------------------------------------------------------------------
    // LED mapping
    //
    // led_ext[7:0]:
    //   [0] is_class10      (green: code is in class 10)
    //   [1] ac_14           (green: code is one of 14 vowels)
    //   [2] an_pred         (yellow: code is in aṇ)
    //   [3] ik_pred         (yellow: code is in ik)
    //   [4] nasal           (red: nasal bit set)
    //   [5] length          (red: length bit set)
    //   [6] is_reserved_row (red: row 7 reserved)
    //   [7] transform_error (red: last op was invalid)
    //
    // led_onb: heartbeat (shows clock is running)
    // ------------------------------------------------------------------------
    assign led_ext[0] = is_class10;
    assign led_ext[1] = ac_14;
    assign led_ext[2] = an_pred;
    assign led_ext[3] = ik_pred;
    assign led_ext[4] = nasal;
    assign led_ext[5] = length;
    assign led_ext[6] = is_reserved_row;
    assign led_ext[7] = transform_error;

    // Heartbeat on onboard LED (~1 Hz from 50 MHz)
    reg [24:0] hb_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            hb_cnt <= 25\'d0;
        else
            hb_cnt <= hb_cnt + 1\'b1;
    end
    assign led_onb = hb_cnt[24];

endmodule

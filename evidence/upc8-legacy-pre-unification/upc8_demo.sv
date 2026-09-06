// upc8_demo -- flashable Tang Primer 25K demo of UPC-8 streaming decode.
//
// Walks a small demo bank through upc8_transform + upc8_decode in a loop,
// one byte per wall-tick (or one byte per button press). The class of the
// most recent decoded unit is latched onto pmod_io[5:0]; the LED column
// shows liveness, valid-unit and error status per bank pass.
//
// Pin map (Tang Primer 25K Dock, GW5A-25A, from the official pmod_led cst):
//   clk        E2   board oscillator
//   key        K6   step button (active low)
//   led        L6   user LED            -> heartbeat per bank loop
//   led_done   D7   READY LED           -> current unit is a valid assigned code
//   led_ready  E8   DONE LED            -> malformed byte seen this loop
//   pmod_io[5:0]     PMOD P1/P2         -> {vowel,..,semivowel} of current unit
//
// The bank intentionally covers all six natural classes plus one reserved
// error byte so the demo walks through the full decode space in ~5 s.
module upc8_demo #(
    parameter [31:0] CLK_DIV = 32'd25000000, // ~0.5 s per byte at 50 MHz
    parameter [31:0] GAP_DIV = 32'd50000000  // ~1 s hold on final unit
)(
    input  wire        clk,
    input  wire        key,       // active low step
    output wire        led,
    output wire        led_done,
    output wire        led_ready,
    output wire [5:0]  pmod_io
);

    localparam [3:0] BANK_LEN = 4'd9;

    // demo bank byte lookup (address 0..8):
    //   a k a r n S  e0:00 (2-byte ext)  f0 (reserved)
    // implemented as a case, not an unpacked array literal, for tool portability
    reg [7:0] bank_byte;
    always @* begin
        case (addr)
            4'd0: bank_byte = 8'h00; // a   -> vowel
            4'd1: bank_byte = 8'h25; // k   -> stop
            4'd2: bank_byte = 8'h00; // a   -> vowel
            4'd3: bank_byte = 8'h0C; // r   -> semivowel
            4'd4: bank_byte = 8'h12; // n   -> nasal
            4'd5: bank_byte = 8'h27; // S   -> sibilant
            4'd6: bank_byte = 8'hE0; // 2-byte extension lead
            4'd7: bank_byte = 8'h00; //     extension tail (unit 0xE0 emits)
            4'd8: bank_byte = 8'hF0; // reserved -> err_reserved
            default: bank_byte = 8'h00;
        endcase
    end

    // wall tick (CLK_DIV cycles per byte; parameterized for fast testbench)
    reg [15:0] por_cnt;
    reg por_done;
    always @(posedge clk) begin
        if (!por_done) begin
            por_cnt <= por_cnt + 16'd1;
            por_done <= &por_cnt;
        end
    end
    wire rst = ~por_done;

    // ---- debounced key (active low) ------------------------------------
    reg [3:0]  key_stable;
    reg        key_deb;
    reg        key_deb_d;
    always @(posedge clk) begin
        key_deb_d <= key_deb;
        if (!key) begin
            if (key_stable != 4'hF) key_stable <= key_stable + 4'd1;
            if (key_stable == 4'hE) key_deb <= 1'b0;
        end else begin
            key_stable <= 4'h0;
            key_deb    <= 1'b1;
        end
    end
    wire key_evt = key_deb_d && !key_deb;

    // ---- wall tick ------------------------------------------------------
    reg [31:0] tick_cnt;
    reg tick;
    always @(posedge clk) begin
        if (rst) begin
            tick_cnt <= 32'd0;
            tick     <= 1'b0;
        end else begin
            tick <= 1'b0;
            if (tick_cnt == CLK_DIV - 32'd1) begin
                tick_cnt <= 32'd0;
                tick     <= 1'b1;
            end else begin
                tick_cnt <= tick_cnt + 32'd1;
            end
        end
    end
    wire advance = tick | key_evt;

    // ---- bank walker ----------------------------------------------------
    localparam RUN  = 1'b0;
    localparam HOLD = 1'b1;

    reg        state;
    reg [3:0]  addr;
    reg [31:0] gap_cnt;
    reg        err_sticky;
    reg        hb;

    reg [7:0] din_w;
    reg       dv_w;
    reg       eof_w;

    always @* begin
        din_w = 8'h00;
        dv_w  = 1'b0;
        eof_w = 1'b0;
        if (state == RUN && advance && addr < BANK_LEN) begin
            din_w = bank_byte;
            dv_w  = 1'b1;
            if (addr == BANK_LEN - 4'd1) eof_w = 1'b1; // last byte of bank
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state    <= RUN;
            addr     <= 4'd0;
            gap_cnt  <= 32'd0;
            err_sticky <= 1'b0;
            hb       <= 1'b0;
        end else begin
            if (u_reserved || u_truncated) err_sticky <= 1'b1;
            if (state == RUN) begin
                if (advance) begin
                    if (addr == BANK_LEN - 4'd1) begin
                        state <= HOLD;   // fed the last byte
                        gap_cnt <= 32'd0;
                        hb <= ~hb;       // heartbeat per bank pass
                    end else begin
                        addr <= addr + 4'd1;
                    end
                end
            end else begin // HOLD
                err_sticky <= err_sticky; // keep error latched through hold
                if (gap_cnt == GAP_DIV - 32'd1) begin
                    state   <= RUN;
                    addr    <= 4'd0;
                    err_sticky <= 1'b0;   // clear per pass
                end else begin
                    gap_cnt <= gap_cnt + 32'd1;
                end
            end
        end
    end

    // ---- decoder path ---------------------------------------------------
    wire [7:0]  u_unit;
    wire        u_valid;
    wire        u_reserved;
    wire        u_truncated;

    upc8_transform u_tf(
        .clk           (clk),
        .rst           (rst),
        .din           (din_w),
        .dv            (dv_w),
        .eof           (eof_w),
        .unit          (u_unit),
        .unit_valid    (u_valid),
        .err_reserved  (u_reserved),
        .err_truncated (u_truncated)
    );

    reg [7:0] curr_unit;
    reg       curr_valid;
    always @(posedge clk) begin
        if (rst) begin
            curr_unit  <= 8'h00;
            curr_valid <= 1'b0;
        end else begin
            if (u_valid) begin
                curr_unit  <= u_unit;
                curr_valid <= 1'b1;
            end
        end
    end

    wire [1:0] layer;
    wire [5:0] cls;
    wire [1:0] special;
    wire       valid_assign;

    upc8_decode u_dc(
        .code         (curr_unit),
        .layer        (layer),
        .cls          (cls),
        .special      (special),
        .valid_assign (valid_assign)
    );

    assign pmod_io  = cls;
    assign led_done = curr_valid && valid_assign;
    assign led_ready = err_sticky;
    assign led      = hb;

endmodule
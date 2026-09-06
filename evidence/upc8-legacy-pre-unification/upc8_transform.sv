// UPC-8 streaming transform: variable-length unit decoder.
//
// Implements the UPC v1 binary grammar recommended in
// docs/upc8-fpga-economics-and-optimization.md section 3:
//
//   0x00-0xDF   direct unit                     (1 byte, emits lead)
//   0xE0 + 1 tail                               (2-byte extension)
//   0xE1 + 2 tails                              (3-byte extension)
//   0xE2 + 3 tails                              (4-byte extension)
//   0xE3-0xFF   reserved / invalid lead  -> ERR_RESERVED
//
// A bank always begins at a known frame boundary. Unit identity (the lead
// byte) is emitted with one unit_valid pulse; malformed banks raise
// err_reserved or err_truncated (end-of-bank signalled with eof while tail
// bytes are still owed). The decoder is optimistic by default at reset.
module upc8_transform(
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  din,
    input  wire        dv,          // din consumed this cycle
    input  wire        eof,         // asserted with dv on the bank's last byte
    output reg  [7:0]  unit,        // lead byte of the decoded unit
    output reg         unit_valid,  // one-cycle pulse per decoded unit
    output reg         err_reserved,   // reserved lead byte (0xE3-0xFF)
    output reg         err_truncated   // eof while tail bytes still owed
);

    localparam [1:0] TAILS_0 = 2'd0;
    localparam [1:0] TAILS_1 = 2'd1;
    localparam [1:0] TAILS_2 = 2'd2;
    localparam [1:0] TAILS_3 = 2'd3;

    reg [1:0] tails;
    reg [7:0] lead;

    always @(posedge clk) begin
        if (rst) begin
            tails        <= TAILS_0;
            lead         <= 8'h00;
            unit         <= 8'h00;
            unit_valid   <= 1'b0;
            err_reserved <= 1'b0;
            err_truncated <= 1'b0;
        end else begin
            // one-cycle pulse defaults; overridden below on unit/error events
            unit_valid   <= 1'b0;
            err_reserved <= 1'b0;
            err_truncated <= 1'b0;

            if (dv) begin

            if (tails == TAILS_0) begin
                // Expecting a lead byte.
                if (din <= 8'hDF) begin
                    // Direct unit: emit this cycle.
                    unit       <= din;
                    unit_valid <= 1'b1;
                end else if (din == 8'hE0) begin
                    lead  <= din;
                    if (eof) begin
                        err_truncated <= 1'b1;  // no room for required tail
                    end else begin
                        tails <= TAILS_1;
                    end
                end else if (din == 8'hE1) begin
                    lead  <= din;
                    if (eof) begin
                        err_truncated <= 1'b1;
                    end else begin
                        tails <= TAILS_2;
                    end
                end else if (din == 8'hE2) begin
                    lead  <= din;
                    if (eof) begin
                        err_truncated <= 1'b1;
                    end else begin
                        tails <= TAILS_3;
                    end
                end else begin
                    err_reserved <= 1'b1;
                end
            end else begin
                // Consuming a tail byte. A unit completes when the last
                // owed tail arrives.
                if (tails == TAILS_1) begin
                    unit       <= lead;
                    unit_valid <= 1'b1;
                end
                tails <= tails - 2'd1;
                // eof here with more than one tail still owed => truncated.
                if (eof && (tails > TAILS_1)) begin
                    err_truncated <= 1'b1;
                end
            end
        end
    end
end

endmodule
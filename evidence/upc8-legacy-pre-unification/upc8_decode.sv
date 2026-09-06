// GENERATED FILE -- do not hand-edit. Regenerate with:
//   python3 gen_upc8_decode.py ../shiva-sutras/prototype/upc8.py
// Decode truth table derived from the shiva-sutras UPC-8 registry
// oracle (upc8.py, phonological_class profile='sanskrit').
//
// cls[5:0]   = {vowel,consonant,stop,sibilant,nasal,semivowel}
// special[0] = anusvara, special[1] = visarga (extended, no canon_ref)
// layer      = 0 canonical, 1 sanskrit_extended, 2 ukrainian_new, 3 reserved
//
module upc8_decode(
    input  wire [7:0] code,
    output reg  [1:0] layer,
    output reg  [5:0] cls,
    output reg  [1:0] special,
    output reg        valid_assign
);
    always @* begin
        case (code)
            8'h00: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // a
            8'h01: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // i
            8'h02: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // u
            8'h03: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // f
            8'h04: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // x
            8'h05: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // e
            8'h06: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // o
            8'h07: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // E
            8'h08: begin layer=0; cls=6'd32; special=2'd0; valid_assign=1'b1; end // O
            8'h09: begin layer=0; cls=6'd16; special=2'd0; valid_assign=1'b1; end // h
            8'h0A: begin layer=0; cls=6'd17; special=2'd0; valid_assign=1'b1; end // y
            8'h0B: begin layer=0; cls=6'd17; special=2'd0; valid_assign=1'b1; end // v
            8'h0C: begin layer=0; cls=6'd17; special=2'd0; valid_assign=1'b1; end // r
            8'h0D: begin layer=0; cls=6'd17; special=2'd0; valid_assign=1'b1; end // l
            8'h0E: begin layer=0; cls=6'd18; special=2'd0; valid_assign=1'b1; end // Y
            8'h0F: begin layer=0; cls=6'd18; special=2'd0; valid_assign=1'b1; end // m
            8'h10: begin layer=0; cls=6'd18; special=2'd0; valid_assign=1'b1; end // N
            8'h11: begin layer=0; cls=6'd18; special=2'd0; valid_assign=1'b1; end // R
            8'h12: begin layer=0; cls=6'd18; special=2'd0; valid_assign=1'b1; end // n
            8'h13: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // J
            8'h14: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // B
            8'h15: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // G
            8'h16: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // Q
            8'h17: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // D
            8'h18: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // j
            8'h19: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // b
            8'h1A: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // g
            8'h1B: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // q
            8'h1C: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // d
            8'h1D: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // K
            8'h1E: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // P
            8'h1F: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // C
            8'h20: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // W
            8'h21: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // T
            8'h22: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // c
            8'h23: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // w
            8'h24: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // t
            8'h25: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // k
            8'h26: begin layer=0; cls=6'd24; special=2'd0; valid_assign=1'b1; end // p
            8'h27: begin layer=0; cls=6'd20; special=2'd0; valid_assign=1'b1; end // S
            8'h28: begin layer=0; cls=6'd20; special=2'd0; valid_assign=1'b1; end // z
            8'h29: begin layer=0; cls=6'd20; special=2'd0; valid_assign=1'b1; end // s
            8'h2A: begin layer=1; cls=6'd32; special=2'd0; valid_assign=1'b1; end // 
            8'h2B: begin layer=1; cls=6'd32; special=2'd0; valid_assign=1'b1; end // 
            8'h2C: begin layer=1; cls=6'd32; special=2'd0; valid_assign=1'b1; end // 
            8'h2D: begin layer=1; cls=6'd32; special=2'd0; valid_assign=1'b1; end // 
            8'h2E: begin layer=1; cls=6'd32; special=2'd0; valid_assign=1'b1; end // 
            8'h2F: begin layer=1; cls=6'd0; special=2'd1; valid_assign=1'b1; end // 
            8'h30: begin layer=1; cls=6'd0; special=2'd2; valid_assign=1'b1; end // 
            8'h31: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h32: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h33: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h34: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h35: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h36: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h37: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h38: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h39: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h3A: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h3B: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h3C: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h3D: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h3E: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h3F: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h40: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h41: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h42: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h43: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h44: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h45: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h46: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h47: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h48: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h49: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h4A: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h4B: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h4C: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h4D: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h4E: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            8'h4F: begin layer=2; cls=6'd0; special=2'd0; valid_assign=1'b1; end // 
            default: begin layer=2'd3; cls=6'd0; special=2'd0;
                       valid_assign=1'b0; end
        endcase
    end
endmodule

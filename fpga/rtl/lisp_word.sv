`ifndef LISP_WORD_SV
`define LISP_WORD_SV

// 32-bit Lisp Word:
// 31:28 - TAG (4 bits)
// 27:0  - VALUE (28 bits)

typedef enum logic [3:0] {
    TAG_FIXNUM  = 4'd0,
    TAG_CONS    = 4'd1,
    TAG_SYMBOL  = 4'd2,
    TAG_NIL     = 4'd3,
    TAG_TRUE    = 4'd4,
    TAG_PRIMITIVE = 4'd5
} lisp_tag_t;

typedef struct packed {
    lisp_tag_t tag;
    logic [27:0] value;
} lisp_word_t;

`endif // LISP_WORD_SV

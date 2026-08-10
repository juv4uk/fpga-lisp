;; Canonical symbol-name -> id table for lib/core.my's identifiers
;; (function names, parameters, special forms), generated 2026-08-10 from
;; my-lisp's scripts/symbol-table.my (commit f32ec78) -- see that script
;; for the exact algorithm: every atom-symbol occurring anywhere in
;; core.my, deduplicated, sorted ALPHABETICALLY (not reader intern order --
;; the my-lisp project makes no promise about that), id assigned from 0.
;;
;; FROZEN SNAPSHOT, not a live regeneration target: ids are alphabetical
;; positions, so adding even one new symbol to core.my before another one
;; (alphabetically) shifts every id after it. Re-running
;; scripts/symbol-table.my later and reflowing this file would silently
;; renumber every SYM_* constant already baked into assembled .asm/.inc
;; files' instruction words. If core.my changes meaningfully, regenerate
;; deliberately, review the diff, and re-verify every bootstrap testbench
;; -- never treat this file as auto-refreshable in place.
;;
;; Replaces the ad-hoc per-file numeric ranges (900s for third, 1000s for
;; pair, 2000s for triple, ...) bootstrap files M19-M26 invented by hand --
;; a real source of collision risk with no single source of truth.

.define SYM_STAR 0    ; '*
.define SYM_PLUS 1    ; '+
.define SYM_MINUS 2    ; '-
.define SYM_SLASH 3    ; '/
.define SYM_LT 4    ; '<
.define SYM_A 5    ; 'a
.define SYM_ACC 6    ; 'acc
.define SYM_ALIST 7    ; 'alist
.define SYM_APPEND 8    ; 'append
.define SYM_ARGS 9    ; 'args
.define SYM_ASSOC 10    ; 'assoc
.define SYM_ATOM 11    ; 'atom
.define SYM_B 12    ; 'b
.define SYM_BINDING 13    ; 'binding
.define SYM_BINDINGS 14    ; 'bindings
.define SYM_BODY 15    ; 'body
.define SYM_CAAR 16    ; 'caar
.define SYM_CADDDR 17    ; 'cadddr
.define SYM_CADR 18    ; 'cadr
.define SYM_CAR 19    ; 'car
.define SYM_CDDR 20    ; 'cddr
.define SYM_CDR 21    ; 'cdr
.define SYM_CHUNK 22    ; 'chunk
.define SYM_CHUNK_PLUS_MULT 23    ; 'chunk+mult
.define SYM_COND 24    ; 'cond
.define SYM_CONS 25    ; 'cons
.define SYM_D 26    ; 'd
.define SYM_DEF 27    ; 'def
.define SYM_DEFMACRO 28    ; 'defmacro
.define SYM_DIGIT_TO_STRING 29    ; 'digit->string
.define SYM_EQ 30    ; 'eq
.define SYM_EQUAL_P 31    ; 'equal?
.define SYM_F 32    ; 'f
.define SYM_FIFTH 33    ; 'fifth
.define SYM_FILTER 34    ; 'filter
.define SYM_FILTER_MINUS_ONTO 35    ; 'filter-onto
.define SYM_FOURTH 36    ; 'fourth
.define SYM_I 37    ; 'i
.define SYM_IDENTITY 38    ; 'identity
.define SYM_ITEM 39    ; 'item
.define SYM_KEY 40    ; 'key
.define SYM_LAMBDA 41    ; 'lambda
.define SYM_LARGEST_MINUS_CHUNK 42    ; 'largest-chunk
.define SYM_LEFT 43    ; 'left
.define SYM_LENGTH 44    ; 'length
.define SYM_LENGTH_MINUS_ONTO 45    ; 'length-onto
.define SYM_LET 46    ; 'let
.define SYM_LET_STAR 47    ; 'let*
.define SYM_LIST 48    ; 'list
.define SYM_LST 49    ; 'lst
.define SYM_MAP 50    ; 'map
.define SYM_MAP_MINUS_ONTO 51    ; 'map-onto
.define SYM_MEMBER_P 52    ; 'member?
.define SYM_MOD 53    ; 'mod
.define SYM_MULT 54    ; 'mult
.define SYM_N 55    ; 'n
.define SYM_NEEDLE 56    ; 'needle
.define SYM_NOT 57    ; 'not
.define SYM_NTH 58    ; 'nth
.define SYM_NUMBER_TO_STRING 59    ; 'number->string
.define SYM_NUMBER_TO_STRING_MINUS_ONTO 60    ; 'number->string-onto
.define SYM_PAIR 61    ; 'pair
.define SYM_PREDICATE 62    ; 'predicate
.define SYM_PREFIX 63    ; 'prefix
.define SYM_QUOTE 64    ; 'quote
.define SYM_QUOTIENT 65    ; 'quotient
.define SYM_REDUCE 66    ; 'reduce
.define SYM_REVERSE 67    ; 'reverse
.define SYM_REVERSE_MINUS_ONTO 68    ; 'reverse-onto
.define SYM_RIGHT 69    ; 'right
.define SYM_S 70    ; 's
.define SYM_SECOND 71    ; 'second
.define SYM_STRING_MINUS_APPEND 72    ; 'string-append
.define SYM_STRING_MINUS_CONTAINS_P 73    ; 'string-contains?
.define SYM_STRING_MINUS_EMPTY_P 74    ; 'string-empty?
.define SYM_STRING_MINUS_FIRST 75    ; 'string-first
.define SYM_STRING_MINUS_LENGTH 76    ; 'string-length
.define SYM_STRING_MINUS_PREFIX_P 77    ; 'string-prefix?
.define SYM_STRING_MINUS_REST 78    ; 'string-rest
.define SYM_T 79    ; 't
.define SYM_THIRD 80    ; 'third
.define SYM_VALUE 81    ; 'value
.define SYM_VALUES 82    ; 'values

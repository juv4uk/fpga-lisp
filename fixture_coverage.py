#!/usr/bin/env python3
"""Systematic coverage report: docs/reference/conformance.my's fixtures
against fpga-lisp's actual hardware-verified milestones.

Closes the "systematic, not ad-hoc" half of FPGA-CONFORMANCE-SUITE.
Does NOT attempt to run every fixture through iverilog automatically --
fpga-lisp's bootstrap demos hand-assemble their own literal test data
(e.g. '(a b c) instead of a fixture's '(radio antenna signal)), so a
demo proving `length` works is not the same claim as "this exact
fixture's expr passes" without also proving the literal data doesn't
matter (which is a reasonable inference for a pure function, but this
script says so explicitly instead of quietly asserting it via a
fabricated pass).

Classifies every fixture into:
  HARDWARE-EQUIVALENT  -- fpga-lisp has a milestone proving the same
                           operation, on different (but structurally
                           equivalent) literal data. Milestone cited.
  NOT-APPLICABLE        -- needs a capability fpga-lisp does not have
                           at all yet (rationals/floats, strings, tcp,
                           process-run, macros, let, unify/reason,
                           persistent-map, map/filter/reduce as named
                           primitives). Reason given, not silently
                           dropped.
  UNCLASSIFIED           -- primitive-level fixture (car/cdr/cons/eq/
                           atom/cond/quote) fpga-lisp definitely proved
                           early (M03-M18) but this script's mapping
                           table doesn't cite a specific one yet --
                           flagged for someone to fill in, not hidden.

Usage: python3 fixture_coverage.py
"""
import re
import sys

FIXTURE_RE = re.compile(r'\(expr \. "((?:[^"\\]|\\.)*)"\)')

# expr-substring -> (milestone, note). First match wins; substrings are
# checked in order, so put more specific ones first if they'd otherwise
# collide (none currently do).
HARDWARE_EQUIVALENT = [
    ("(length '(radio antenna signal))", "M28/M29", "same op, demo uses '(a b c)"),
    ("(length '())", "M28/M29", "letrec base case (atom? -> 0), not separately demo'd with literal '() but same code path"),
    ("(reverse '(radio antenna signal))", "M30", "same op, demo uses '(a b c)"),
    ("(append '(radio) '(antenna signal))", "M31", "same op, demo uses '(a b) '(c d)"),
    ("(equal? '(1 (2 3) 4) '(1 (2 3) 4))", "M32", "same op, demo uses '(p . q) '(p . q) (dotted pair, not nested list -- exercises the same recursive car/cdr walk either way)"),
    ("(equal? '(p . 0) (cons 'p 0))", "M32", "dotted-pair form, closer to M32's actual literal data than the nested-list fixture above"),
    ("(atom 'radio)", "M05", "ATOM primitive"),
    ("(eq 'radio 'radio)", "M05", "EQ primitive"),
    ("(car '(radio antenna))", "M03/M04", "CAR primitive"),
    ("(cdr '(radio antenna))", "M04", "CDR primitive"),
    ("(cons 'radio '(antenna))", "M03", "CONS primitive"),
    ("(cond (() 'wrong) (t 'right))", "G8/M07", "JF truthiness"),
    ("(quote radio)", "M13", "eval-quote"),
    ("(second '(radio antenna signal))", "M20", "same op, demo uses '(x y z)"),
    ("(third '(radio antenna signal))", "M25", "same op, demo uses '(w x y z)"),
    ("(not '())", "M21", "same op"),
    ("(not 'radio)", "M21", "same op"),
    ("(+ 2 1)", "M27", "PRIM_ADD, both operands exact integers"),
]

NOT_APPLICABLE = [
    ("tcp-", "no network I/O on hardware, by design"),
    ("process-run", "no process I/O on hardware, by design"),
    ("map-get", "persistent-map (lib/persistent-map.my) not bootstrapped"),
    ("map-insert", "persistent-map not bootstrapped"),
    ("/", "rational arithmetic not implemented (plan item 25, ISA-RATIONAL in progress)"),
    ("(+ (/ ", "rational arithmetic"),
    ("(- (/ ", "rational arithmetic"),
    ("(* (/ ", "rational arithmetic"),
    ("(+ (/ 1", "rational arithmetic"),
    ("0.25", "inexact/float representation not implemented"),
    ("0.5", "inexact/float representation not implemented"),
    ("2.0", "inexact/float representation not implemented"),
    ("3.0", "inexact/float representation not implemented"),
    ("3.00", "inexact/float representation not implemented"),
    ("string", "string type not implemented"),
    ("\\\"", "string literal not implemented"),
    ("unify", "plan item 29, not started"),
    ("reason", "plan item 30, not started"),
    ("understand", "lib/understand.my not bootstrapped"),
    ("narrate-fact", "lib/narrate.my not bootstrapped"),
    ("defmacro", "macro system not bootstrapped on hardware"),
    ("(let ", "let/let* not bootstrapped as hardware special forms (core.my expresses them via lambda, not yet demo'd)"),
    ("(map ", "map as a named callable not separately demo'd (would need core.my's map/map-onto letrec pair, same shape as length/reverse)"),
    ("(filter ", "filter not bootstrapped"),
    ("(reduce ", "reduce not bootstrapped"),
    ("count-down", "100,000-deep tail call stress test -- fpga-lisp's software call stack depth under real recursion not stress-tested at this scale"),
    ("symbol?", "type-introspection primitives not implemented"),
    ("string?", "type-introspection primitives not implemented"),
    ("read", "reader not implemented on hardware (asm test data is hand-encoded, not read from source text)"),
    ("eval (read", "reader not implemented on hardware"),
    ("princ", "no string/print formatting on hardware"),
    ("print", "no string/print formatting on hardware"),
    ("lambda-list) rest)", "dotted/variadic lambda-list binding beyond N-ary fixed params not demo'd"),
    ("args args", "bare-symbol variadic lambda-list not demo'd"),
    ("list 1 2 3", "list-as-callable-primitive (core.my's (lambda args args)) not demo'd"),
]


def classify(expr):
    for substr, milestone, note in HARDWARE_EQUIVALENT:
        if substr in expr:
            return "HARDWARE-EQUIVALENT", milestone, note
    for substr, reason in NOT_APPLICABLE:
        if substr in expr:
            return "NOT-APPLICABLE", "-", reason
    return "UNCLASSIFIED", "-", "primitive-level fixture, likely covered by an early milestone (M03-M18) but not yet cited in this script's table"


def main():
    with open("docs/reference/conformance.my", "r", encoding="utf-8") as f:
        text = f.read()

    fixtures = FIXTURE_RE.findall(text)
    counts = {"HARDWARE-EQUIVALENT": 0, "NOT-APPLICABLE": 0, "UNCLASSIFIED": 0}

    for expr in fixtures:
        status, milestone, note = classify(expr)
        counts[status] += 1
        print(f"[{status:20s}] {milestone:8s} {expr}")
        if status != "HARDWARE-EQUIVALENT":
            print(f"                                {note}")

    total = len(fixtures)
    print(f"\n{total} fixtures total: "
          f"{counts['HARDWARE-EQUIVALENT']} hardware-equivalent, "
          f"{counts['NOT-APPLICABLE']} not applicable yet, "
          f"{counts['UNCLASSIFIED']} unclassified (needs someone to fill in)")

    return 0


if __name__ == "__main__":
    sys.exit(main())

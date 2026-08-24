# CPU + GPU + FPGA execution fabric

**Status:** architecture direction, 2026-08-24. `isa-contract.my`, RTL, and
hardware evidence remain authoritative.

The three repositories keep separate authority while forming one system:

```text
my-lisp    observable semantics
CML        analysis, Execution Graph, partitioning, lowering
fpga-lisp  FPGA ISA, RTL, transport, physical evidence
```

The target fabric is:

```text
my-lisp -> CML semantic IR -> Execution Graph
                                  |    |    |
                                 CPU  GPU  FPGA
```

CPU runs full Lisp semantics and coordinates jobs. Portable or
vendor-specific GPU backends run pure bulk operations over immutable typed
numeric buffers. The FPGA has two roles that evidence must keep distinct:

1. general Lisp execution through the existing `fpga-lisp` ISA;
2. future specialized stream/dataflow pipelines.

The connected GW5A-25A board, SRAM programming, UART upload, and observed
`(plus 3 4)` result establish the first role. They do not establish the second.

## FPGA executor boundary

CML owns graph nodes and logical buffers. `fpga-lisp` owns a versioned job and
result protocol that maps a node onto the physical machine:

```text
CPU logical buffer
 -> versioned frame
 -> UART / future PCIe transport
 -> program + FPGA-visible data
 -> execution
 -> named status + result frame
 -> CPU logical buffer
```

No raw pointer is a cross-device ABI. M0 may copy through host memory. BRAM
descriptors, DMA, pinned memory, or direct GPU/FPGA movement are later
optimizations and require an explicit ABI revision.

The executor must report live capabilities, device identity, supported
operations and representations, program limits, transport availability, and
named errors. A planned pipeline is never selectable. A failed job publishes
no partial language value.

## Synergy rather than substitution

Suggested placement is complementary:

| Work | Candidate |
|---|---|
| dynamic control, closures, exact arithmetic, GC | CPU |
| pure element-wise and reductions | GPU |
| deterministic streams/pipelines or Lisp-machine programs | FPGA |
| uncertain or unsupported regions | CPU fallback |

A golden heterogeneous experiment should be deliberately small:

```text
CPU validates input
 -> GPU maps a typed numeric buffer
 -> CPU converts or partitions
 -> FPGA executes a deterministic node
 -> CPU compares with reference execution
```

This proves orchestration only. Performance requires separate transfer,
launch, and execution measurements.

## Milestones affecting fpga-lisp

1. CML first implements an Execution Graph with a CPU-only executor.
2. Define a machine-readable, versioned FPGA job/result frame jointly with
   CML; keep existing ISA authority here.
3. Implement Rust host transport without deleting the current monitor, which
   remains an independent diagnostic path.
4. Run one graph node on physical hardware and record cable/device, bitstream,
   program, transport, and result evidence separately.
5. Only then design a dataflow specialization ABI and RTL pipeline.

FPGA conformance distinguishes simulation, synthesis, SRAM programming,
transport success, and observed results. Valid states are `CONFIRMED`,
`PARTIAL`, `UNSUPPORTED`, `UNAVAILABLE`, `BROKEN`, and `UNRESOLVED`; success
of the CPU or GPU backend does not infer FPGA success.

Hardware vendor names and transport primitives do not enter core my-lisp.
CML selects only a registered `Live` executor after semantic and
representation checks pass.

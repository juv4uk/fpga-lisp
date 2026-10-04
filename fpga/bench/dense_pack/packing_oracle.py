#!/usr/bin/env python3
from __future__ import annotations

import json

PHYS_W = 32
WIDTHS = (3, 5, 7)
DEPTHS = (256, 1024, 4096)


def ceil_div(a: int, b: int) -> int:
    return (a + b - 1) // b


def mask(width: int) -> int:
    return (1 << width) - 1


def pack_naive(values: list[int], width: int) -> list[int]:
    m = mask(width)
    assert all(0 <= v <= m for v in values)
    return values[:]


def unpack_naive(carriers: list[int], width: int) -> list[int]:
    m = mask(width)
    assert all((v & ~m) == 0 for v in carriers)
    return [v & m for v in carriers]


def pack_word_aligned(values: list[int], width: int) -> list[int]:
    slots = PHYS_W // width
    out = [0] * ceil_div(len(values), slots)
    m = mask(width)
    for i, value in enumerate(values):
        assert 0 <= value <= m
        word = i // slots
        slot = i % slots
        out[word] |= value << (slot * width)
    return out


def unpack_word_aligned(words: list[int], count: int, width: int) -> list[int]:
    slots = PHYS_W // width
    m = mask(width)
    out: list[int] = []
    for i in range(count):
        word = i // slots
        slot = i % slots
        out.append((words[word] >> (slot * width)) & m)
    return out


def pack_tight(values: list[int], width: int) -> list[int]:
    total_bits = len(values) * width
    out = [0] * ceil_div(total_bits, PHYS_W)
    m = mask(width)
    for i, value in enumerate(values):
        assert 0 <= value <= m
        bit = i * width
        wi = bit // PHYS_W
        off = bit % PHYS_W
        out[wi] |= (value << off) & 0xFFFFFFFF
        spill = off + width - PHYS_W
        if spill > 0:
            out[wi + 1] |= value >> (width - spill)
    return [word & 0xFFFFFFFF for word in out]


def unpack_tight(words: list[int], count: int, width: int) -> list[int]:
    m = mask(width)
    out: list[int] = []
    for i in range(count):
        bit = i * width
        wi = bit // PHYS_W
        off = bit % PHYS_W
        value = words[wi] >> off
        spill = off + width - PHYS_W
        if spill > 0:
            value |= words[wi + 1] << (PHYS_W - off)
        out.append(value & m)
    return out


def physical_bits(strategy: str, count: int, width: int) -> int:
    if strategy == "naive-byte":
        return count * 8
    if strategy == "word-aligned-32":
        slots = PHYS_W // width
        return ceil_div(count, slots) * PHYS_W
    if strategy == "tight-32":
        return ceil_div(count * width, PHYS_W) * PHYS_W
    raise ValueError(strategy)


def deterministic_values(count: int, width: int) -> list[int]:
    m = mask(width)
    return [((i * 5) ^ (i >> 2) ^ m) & m for i in range(count)]


def verify_strategy(strategy: str, values: list[int], width: int) -> None:
    if strategy == "naive-byte":
        packed = pack_naive(values, width)
        got = unpack_naive(packed, width)
    elif strategy == "word-aligned-32":
        packed = pack_word_aligned(values, width)
        got = unpack_word_aligned(packed, len(values), width)
    elif strategy == "tight-32":
        packed = pack_tight(values, width)
        got = unpack_tight(packed, len(values), width)
    else:
        raise ValueError(strategy)
    if got != values:
        for i, (expected, actual) in enumerate(zip(values, got)):
            if expected != actual:
                raise AssertionError(
                    f"{strategy} width={width} mismatch at {i}: "
                    f"expected={expected} got={actual}"
                )
        raise AssertionError(f"{strategy} width={width}: round-trip mismatch")


def row(strategy: str, count: int, width: int) -> dict[str, object]:
    logical = count * width
    physical = physical_bits(strategy, count, width)
    return {
        "kind": "dense-pack-capacity-oracle/v1",
        "semantic_width": width,
        "depth_values": count,
        "physical_word_width": 8 if strategy == "naive-byte" else PHYS_W,
        "strategy": strategy,
        "logical_bits": logical,
        "physical_bits": physical,
        "reserved_bits": physical - logical,
        "packing_efficiency": logical / physical,
        "semantic_authority": False,
        "hardware_evidence": False,
    }


def main() -> None:
    strategies = ("naive-byte", "word-aligned-32", "tight-32")
    rows: list[dict[str, object]] = []

    for width in WIDTHS:
        exhaustive = list(range(1 << width))
        for strategy in strategies:
            verify_strategy(strategy, exhaustive, width)

    for width in WIDTHS:
        for count in DEPTHS:
            values = deterministic_values(count, width)
            for strategy in strategies:
                verify_strategy(strategy, values, width)
                rows.append(row(strategy, count, width))

    for item in rows:
        print(json.dumps(item, sort_keys=True))

    print("PASS dense-pack capacity/oracle round-trips", flush=True)


if __name__ == "__main__":
    main()

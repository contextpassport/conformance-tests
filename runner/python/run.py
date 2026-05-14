#!/usr/bin/env python3
"""
Context Passport conformance test runner — Python reference implementation.

Usage:
    python runner/python/run.py [--implementation <module>] [--level core|signed|full]

Loads every vector under vectors/{required,signed,recommended}/ and dispatches
each to the implementation under test according to the vector's `operation`
field. Reports a pass/fail summary per level.

The default implementation is `context_passport` (the official Python reference
implementation). To test a different Python implementation, pass --implementation
with a module name that exports the same API:
    - payload_hash(payload) -> str
    - integrity_hash(payload_hash, parent_integrity_or_None) -> str
    - verify_chain(passports) -> bool
"""

from __future__ import annotations

import argparse
import importlib
import json
import sys
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "vectors"

# ----- vector loading ------------------------------------------------------

def load_vectors(level: str) -> list[dict]:
    directory = VECTORS / level
    if not directory.exists():
        return []
    out = []
    for path in sorted(directory.glob("*.json")):
        with path.open(encoding="utf-8") as f:
            out.append({"file": path.name, "data": json.load(f)})
    return out


# ----- dispatchers ---------------------------------------------------------

class TestResult:
    def __init__(self, passed: bool, message: str = ""):
        self.passed = passed
        self.message = message

    def __bool__(self) -> bool:
        return self.passed


def dispatch_verify_chain(impl, vec: dict) -> TestResult:
    passports = vec["input"]["passports"]
    expected = vec["expected"]["result"]
    try:
        actual = impl.verify_chain(passports)
    except Exception as e:
        return TestResult(False, f"impl.verify_chain raised: {e!r}")
    if bool(actual) != bool(expected):
        return TestResult(False, f"expected verify_chain={expected}, got {actual}")
    return TestResult(True)


def dispatch_compare_payload_hashes(impl, vec: dict) -> TestResult:
    a = vec["input"]["payload_a"]
    b = vec["input"]["payload_b"]
    try:
        ha = impl.payload_hash(a)
        hb = impl.payload_hash(b)
    except Exception as e:
        return TestResult(False, f"impl.payload_hash raised: {e!r}")
    if vec["expected"]["result"] == "equal":
        if ha != hb:
            return TestResult(False, f"expected equal hashes, got {ha} vs {hb}")
        expected_hash = vec["expected"].get("hash")
        if expected_hash and ha != expected_hash:
            return TestResult(False, f"hash matches between inputs but != ground truth {expected_hash}: got {ha}")
        return TestResult(True)
    else:  # unequal
        if ha == hb:
            return TestResult(False, f"expected unequal hashes, got equal: {ha}")
        return TestResult(True)


def dispatch_parse_should_reject(impl, vec: dict) -> TestResult:
    """
    Parse-should-reject vectors test that the implementation refuses to
    operate on malformed passports. We probe by trying verify_chain — a
    conformant implementation should either raise or return False (depending
    on philosophy). Either is treated as a pass; succeeding silently with
    True is a fail.
    """
    passport = vec["input"]["passport"]
    try:
        result = impl.verify_chain([passport])
    except (KeyError, ValueError, TypeError):
        return TestResult(True, "implementation correctly raised on malformed input")
    if result is False:
        return TestResult(True, "implementation correctly returned False on malformed input")
    return TestResult(False, "implementation accepted a passport missing required schema_version field")


DISPATCHERS: dict[str, Callable[..., TestResult]] = {
    "verify_chain":            dispatch_verify_chain,
    "compare_payload_hashes":  dispatch_compare_payload_hashes,
    "parse_should_reject":     dispatch_parse_should_reject,
}


# ----- main loop -----------------------------------------------------------

def run_level(impl, level: str) -> tuple[int, int]:
    """Run all vectors in a level. Returns (passed, total)."""
    vectors = load_vectors(level)
    if not vectors:
        return 0, 0

    passed = 0
    print(f"# {level} ({len(vectors)} vector{'s' if len(vectors) != 1 else ''})")
    for v in vectors:
        data = v["data"]
        op = data.get("operation", "<missing>")
        dispatcher = DISPATCHERS.get(op)
        if dispatcher is None:
            print(f"  - {v['file']:42s} SKIP  (no dispatcher for operation '{op}')")
            continue
        result = dispatcher(impl, data)
        if result:
            print(f"  - {v['file']:42s} PASS")
            passed += 1
        else:
            print(f"  - {v['file']:42s} FAIL  {result.message}")
    print()
    return passed, len(vectors)


def main() -> int:
    parser = argparse.ArgumentParser(description="Context Passport conformance runner.")
    parser.add_argument(
        "--implementation",
        default="context_passport",
        help="Python module name of the implementation under test (default: context_passport).",
    )
    parser.add_argument(
        "--level",
        choices=["core", "signed", "full"],
        default="core",
        help="Conformance level (default: core).",
    )
    args = parser.parse_args()

    try:
        impl = importlib.import_module(args.implementation)
    except ImportError as e:
        print(f"ERROR: could not import implementation '{args.implementation}': {e}", file=sys.stderr)
        print("Install it with: pip install context-passport", file=sys.stderr)
        return 2

    for attr in ("payload_hash", "integrity_hash", "verify_chain"):
        if not hasattr(impl, attr):
            print(f"ERROR: implementation '{args.implementation}' missing required function '{attr}'", file=sys.stderr)
            return 2

    levels_to_run = {
        "core":   ["required"],
        "signed": ["required", "signed"],
        "full":   ["required", "signed", "recommended"],
    }[args.level]

    print(f"Context Passport conformance runner")
    print(f"  Implementation: {args.implementation}")
    print(f"  Level:          {args.level}")
    print()

    total_passed = 0
    total = 0
    for level in levels_to_run:
        p, t = run_level(impl, level)
        total_passed += p
        total += t

    print(f"Summary: {total_passed}/{total} vectors passed")
    return 0 if total_passed == total and total > 0 else 1


if __name__ == "__main__":
    sys.exit(main())

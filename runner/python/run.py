#!/usr/bin/env python3
"""
Context Passport conformance test runner — Python reference implementation.

Usage:
    python run.py --implementation <module_name>

The runner loads every vector under vectors/required/ and (optionally) vectors/signed/
and vectors/recommended/, then invokes the named implementation's API against each.

This is a stub. The full runner will dynamically import the implementation under
test, dispatch by vector `expected.operation`, and report pass/fail per level.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "vectors"


def load_vectors(level: str) -> list[dict]:
    """Load all JSON vectors from a level directory."""
    directory = VECTORS / level
    if not directory.exists():
        return []
    vectors = []
    for path in sorted(directory.glob("*.json")):
        with path.open(encoding="utf-8") as f:
            vectors.append({"file": path.name, "data": json.load(f)})
    return vectors


def main() -> int:
    parser = argparse.ArgumentParser(description="Context Passport conformance runner.")
    parser.add_argument(
        "--implementation",
        default="context_passport",
        help="Python module name of the implementation under test.",
    )
    parser.add_argument(
        "--level",
        choices=["core", "signed", "full"],
        default="core",
        help="Conformance level to test.",
    )
    args = parser.parse_args()

    levels_to_run = {
        "core":   ["required"],
        "signed": ["required", "signed"],
        "full":   ["required", "signed", "recommended"],
    }[args.level]

    print(f"Context Passport conformance runner")
    print(f"  Implementation: {args.implementation}")
    print(f"  Level:          {args.level}")
    print()

    total = 0
    passed = 0
    for level in levels_to_run:
        vectors = load_vectors(level)
        print(f"# {level} ({len(vectors)} vector(s))")
        for v in vectors:
            total += 1
            # TODO: dispatch by expected.operation and invoke the implementation
            print(f"  - {v['file']:40s} SKIP (runner stub)")
        print()

    print(f"Summary: {passed}/{total} vectors passed (runner is a stub)")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())

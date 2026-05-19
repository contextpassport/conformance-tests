# Polyglot conformance

Cross-implementation byte-equivalence check for Context Passport. Runs the same payloads through the Python (`context-passport`) and TypeScript (`@contextpassport/core`) reference implementations and confirms they produce identical `payload_hash` values.

This is the load-bearing test for whether Context Passport is portable across implementations. If a payload hashes to different bytes in Python and TypeScript, a record signed in one will not verify in the other, and the standard is implementation-defined rather than truly portable.

## Run it

Requires both reference implementations installed in the current environment:

```bash
pip install "context-passport>=2.0"
npm install @contextpassport/core@^2.0   # in the cwd
bash runner/polyglot/run.sh
```

Exit 0 on full equivalence, exit 1 if any payload diverges.

## Status (v2.0)

Under v2.0 (RFC 8785 / JCS canonicalization), all 11 payload vectors pass in both implementations, including non-ASCII strings and emoji. The signed `v07_ed25519_valid.json` vector verifies cross-impl.

The original v1.x harness documented three known divergences:

1. **Non-ASCII characters** — closed by JCS (raw UTF-8 emission, no `\uXXXX` escapes).
2. **Emoji / multi-byte Unicode** — closed by JCS (same fix).
3. **Integers larger than 2^53 − 1** — *not* closed by JCS. This is a fundamental limit of the JavaScript `Number` type, not of the canonicalization algorithm. Applications that need arbitrary-precision integers across implementations must encode them as strings or BigInts in the payload. The v2.0 vector set uses `safe_integer_max` (`9007199254740991`, exactly 2^53 − 1) as the upper bound and documents this constraint in SPEC.md §3.4.

## Vector coverage

The script tests 11 hand-crafted payload shapes (`payloads.json`) covering simple strings, nested objects, key-order variants, mixed arrays, empty values, Unicode, emoji, integers at safe-range bounds, and deeply nested objects. Plus the signed v07 vector for cross-impl signature verification.

## CI integration

Suitable for a GitHub Actions matrix that runs on every push to either reference SDK:

```yaml
- run: pip install "context-passport>=2.0"
- run: npm install @contextpassport/core@^2.0
- run: bash runner/polyglot/run.sh
```

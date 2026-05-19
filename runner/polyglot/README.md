# Polyglot conformance

Cross-implementation byte-equivalence check for Context Passport. Runs the same payloads through the Python (`context-passport`) and TypeScript (`@contextpassport/core`) reference implementations and confirms they produce identical `payload_hash` values.

This is the load-bearing test for whether Context Passport is portable across implementations. If a payload hashes to different bytes in Python and TypeScript, a record signed in one will not verify in the other, and the standard is implementation-defined rather than truly portable.

## Run it

Requires both reference implementations installed in the current environment:

```bash
pip install context-passport
npm install @contextpassport/core   # in the cwd
bash runner/polyglot/run.sh
```

Exit 0 on full equivalence, exit 1 if any payload diverges.

## Known divergences (as of v1.0)

The current Python and TypeScript implementations both use their native `JSON` serializers with sorted keys. This produces byte-equivalent output for most payload shapes (strings without non-ASCII, integers within `Number.MAX_SAFE_INTEGER`, all nested object shapes, arrays of mixed primitives) but diverges in three cases:

1. **Non-ASCII characters.** Python's `json.dumps` defaults to `ensure_ascii=True` (escapes `ç` to `ç`). Node's `JSON.stringify` keeps the raw UTF-8 byte. Different serialized bytes → different hash.
2. **Emoji and multi-byte Unicode.** Same root cause as above.
3. **Integers larger than 2^53 − 1.** JavaScript silently loses precision (numbers past `Number.MAX_SAFE_INTEGER` get rounded). Python preserves the full integer. Different number → different hash.

These divergences are tracked as the canonical-JSON gap. The fix is to adopt RFC 8785 (JSON Canonicalization Scheme) as the spec-mandated canonicalization algorithm. See SPEC.md §3.4 and any open issue tagged `rfc-8785`.

Until the fix lands, applications that need cross-implementation portability MUST avoid non-ASCII characters in payloads and MUST keep all integer values within the JavaScript safe-integer range (-(2^53 − 1) through 2^53 − 1).

## Vector coverage

The script tests:

- 11 hand-crafted payload shapes covering simple strings, nested objects, key-order variants, mixed arrays, empty values, Unicode, integers at various magnitudes, deeply nested objects.
- The `signed/v07_ed25519_valid.json` vector verifies in both implementations (currently passes — the vector uses an ASCII-only payload so the Unicode bug does not surface).

When the canonical-JSON fix lands, the 3 currently-failing payload tests must go green and the harness as a whole must exit 0.

## CI integration

Suitable for a GitHub Actions matrix that runs on every push to either reference SDK:

```yaml
- run: pip install context-passport
- run: npm install @contextpassport/core
- run: bash runner/polyglot/run.sh
```

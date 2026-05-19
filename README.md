# Context Passport Conformance Tests

The test suite that any Context Passport implementation can run against to verify v2.0 conformance.

**Specification:** https://github.com/contextpassport/spec

## Licensing

- **Test vectors** (everything under `src/context_passport_conformance/vectors/`) — CC0 1.0. See `LICENSE-CC0`. Free to use, modify, redistribute.
- **Runner code** — Apache-2.0. See `LICENSE-APACHE`.

## What conformance means

An implementation is **Context Passport v2.0 conformant** if it passes every vector at a given level. v2.0 adopts RFC 8785 (JCS) as the canonical-JSON algorithm; the vectors verify byte-equivalent hashing across implementations.

## Conformance levels

| Level | Requirements |
|---|---|
| **Core** | All vectors in `vectors/required/` pass. The implementation produces and consumes passports that validate against `schema/v2.json` and compute integrity hashes correctly under RFC 8785. |
| **Signed** | Core, plus all vectors in `vectors/signed/` pass. Ed25519 signing per SPEC.md §3.2.7 is implemented and verifies correctly. |
| **Full** | Signed, plus all vectors in `vectors/recommended/` pass. Handles fork/merge lineage, extension namespacing, and forward compatibility. (No recommended vectors are published yet — `--level full` currently exits 1 to prevent silent green-ticking.) |

## Running the suite

### Install

```bash
pip install "context-passport-conformance[reference]"
```

The `[reference]` extra also pulls in `context-passport>=2.0.0` (the default implementation under test). For other languages, install the package without extras and use `--implementation <module_name>`.

### Run it

```bash
context-passport-conformance --level core      # 6/6
context-passport-conformance --level signed    # 9/9
```

The vectors travel inside the wheel, so no `--vectors-dir` flag and no git clone are required for the default suite. Use `--vectors-dir <path>` only to test against a custom or in-development vector set.

### Polyglot harness

The polyglot byte-equivalence harness lives at `runner/polyglot/run.sh`. It exercises the same payloads through the Python and TypeScript reference SDKs and confirms identical hashes — the load-bearing test for cross-implementation portability. Requires both SDKs installed:

```bash
pip install context-passport
npm install @contextpassport/core
bash runner/polyglot/run.sh
```

11/11 vectors pass under v2.0.

### Test a different implementation

```bash
context-passport-conformance --implementation <module_name> --level core
```

The implementation must expose `payload_hash`, `integrity_hash`, `verify_chain`, and (for signed conformance) `verify_signature` with the same signatures as the reference SDK.

Implementations in other languages should ship their own runners that load each vector JSON and report pass/fail against `expected`. The vectors are CC0 — copy them freely.

## Vector format

Each test vector is a JSON file:

```json
{
  "name": "v01_root_commit",
  "description": "A valid root passport with no parent.",
  "operation": "verify_chain",
  "input": { "passports": [ ... ] },
  "expected": { "result": true }
}
```

Supported `operation` values: `verify_chain`, `compare_payload_hashes`, `parse_should_reject`, `verify_signature`, `verify_signature_pair_consistency`.

## Required vectors (Core)

1. `v01_root_commit.json` — Valid root passport with no parent.
2. `v02_chained_commit.json` — Child passport with linked parent.
3. `v03_canonical_payload.json` — Two key-orderings produce identical hashes.
4. `v04_broken_chain.json` — Tampered payload is detected.
5. `v05_schema_version.json` — Missing `schema_version` is rejected.
6. `v06_unknown_extension.json` — Unknown namespaced field is accepted and ignored.

## Signed vectors

7. `v07_ed25519_valid.json` — Valid Ed25519 signature verifies.
8. `v08_ed25519_tampered.json` — Modified payload fails signature verification.
9. `v09_signature_canonicalization.json` — Signature is over canonical bytes with signature field cleared.

## Conformance badge

Implementations that pass all required vectors may self-declare:

```
Context Passport v2.0 Core Conformant
```

Implementations that also pass signed vectors may declare `Signed Conformant`. This is self-attestation. Independent verification is encouraged but not required.

## Contributing

Open a pull request adding a new vector under the appropriate directory. Vectors should:

1. Test one specific behavior
2. Include clear `expected` output
3. Be reproducible across implementations
4. Follow the naming convention `vNN_short_description.json`

See [CONTRIBUTING.md](https://github.com/contextpassport/spec/blob/main/CONTRIBUTING.md) in the spec repository for general guidelines.

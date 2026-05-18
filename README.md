# Context Passport Conformance Tests

The test suite that any Context Passport implementation can run against to verify v1.0 conformance.

**Specification:** https://github.com/contextpassport/spec

## Licensing

- **Test vectors** (everything under `vectors/`) — CC0 1.0. See `LICENSE-CC0`. Free to use, modify, redistribute.
- **Runner code** (everything under `runner/`) — Apache-2.0. See `LICENSE-APACHE`.

## What conformance means

An implementation is **Context Passport v1.0 conformant** if it passes every test in `vectors/required/`. Implementations may additionally pass tests in `vectors/signed/` or `vectors/recommended/` to claim stronger conformance levels.

## Conformance levels

| Level | Requirements |
|---|---|
| **Core** | All vectors in `vectors/required/` pass. The implementation can produce and consume passports that validate against `schema/v1.json` and compute integrity hashes correctly. |
| **Signed** | Core, plus all vectors in `vectors/signed/` pass. The implementation produces signed passports (SPEC.md section 3.2.7) and verifies signatures correctly. |
| **Full** | Signed, plus all vectors in `vectors/recommended/` pass. The implementation handles fork/merge lineage, extension namespacing, and forward compatibility correctly. |

## Vector format

Each test vector is a JSON file with three sections:

```json
{
  "name": "v01_root_commit",
  "description": "A valid root passport with no parent.",
  "input": { ... passport or chain to be evaluated ... },
  "expected": { ... expected verification result ... }
}
```

Implementations under test load the vector, perform the relevant operation, and compare output against `expected`.

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

## Recommended vectors

10. `v10_fork_lineage.json` — Fork populates lineage fields.
11. `v11_event_types.json` — All event types accepted.
12. `v12_long_chain.json` — 100-commit chain verifies.

## Running the suite

### Install the runner

```bash
pip install context-passport-conformance context-passport
```

This installs the `context-passport-conformance` CLI plus the reference Python implementation it tests against.

### Run it

From a checkout of this repository:

```bash
context-passport-conformance --level core
context-passport-conformance --level signed
```

If you installed via pip (vectors not next to the runner), point at a vectors directory:

```bash
git clone https://github.com/contextpassport/conformance-tests.git
context-passport-conformance --vectors-dir conformance-tests/vectors --level signed
```

### Test a different implementation

```bash
context-passport-conformance --implementation <module_name> --level core
```

The implementation must expose `payload_hash`, `integrity_hash`, `verify_chain`, and (for signed conformance) `verify_signature` with the same signatures as the reference implementation.

Implementations in other languages should ship their own runners that load each vector JSON and report pass/fail against `expected`. The vectors are CC0 — copy them freely.

## Conformance badge

Implementations that pass all required vectors may self-declare:

```
Context Passport v1.0 Core Conformant
```

This is self-attestation. Independent verification is encouraged but not required.

## Contributing

Open a pull request adding a new vector under the appropriate directory. Vectors should:

1. Test one specific behavior
2. Include clear `expected` output
3. Be reproducible across implementations
4. Follow the naming convention `vNN_short_description.json`

See [CONTRIBUTING.md](https://github.com/contextpassport/spec/blob/main/CONTRIBUTING.md) in the spec repository for general guidelines.

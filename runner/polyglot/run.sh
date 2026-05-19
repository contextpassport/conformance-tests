#!/usr/bin/env bash
# Polyglot conformance check: prove that the Python and TypeScript reference
# implementations of Context Passport produce byte-identical hashes for the
# same input payloads. If they diverge for any vector, cross-implementation
# verification is broken and the standard is implementation-defined rather
# than portable.
#
# Requires:
#   - python with context-passport installed (pip install context-passport)
#   - node with @contextpassport/core installed (npm install @contextpassport/core)
#   - jq (for JSON comparison)
#
# Usage:
#   bash runner/polyglot/run.sh [--vectors-dir <dir>]
#
# Exits 0 if all vectors produce identical hashes across both impls.
# Exits 1 if any vector diverges.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VECTORS_DIR="${REPO_ROOT}/src/context_passport_conformance/vectors"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vectors-dir) VECTORS_DIR="$2"; shift 2 ;;
    -h|--help)
      grep '^# ' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if ! command -v python >/dev/null 2>&1; then
  echo "ERROR: python not on PATH" >&2; exit 2
fi
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node not on PATH" >&2; exit 2
fi
if ! python -c "import context_passport" 2>/dev/null; then
  echo "ERROR: context-passport not installed. pip install context-passport" >&2; exit 2
fi
if ! node -e "import('@contextpassport/core').then(()=>process.exit(0)).catch(()=>process.exit(1))" 2>/dev/null; then
  echo "ERROR: @contextpassport/core not installed in cwd. npm install @contextpassport/core" >&2
  exit 2
fi

echo "polyglot conformance: python vs typescript"
echo "  vectors: $VECTORS_DIR"
echo ""

total=0
passed=0
failed=0
failures=()

# Test 1: payload_hash byte equivalence on a curated set of payloads
PAYLOADS_FILE="${SCRIPT_DIR}/payloads.json"
# Convert to native path on Windows/MSYS so Python/Node can open it.
if command -v cygpath >/dev/null 2>&1; then
  PAYLOADS_FILE="$(cygpath -w "$PAYLOADS_FILE")"
fi

run_python_case() {
  local case_name="$1"
  PAYLOADS_FILE="$PAYLOADS_FILE" CASE_NAME="$case_name" python -c "
import json, os
from context_passport import payload_hash
with open(os.environ['PAYLOADS_FILE'], encoding='utf-8') as f:
    cases = json.load(f)
for c in cases:
    if c['name'] == os.environ['CASE_NAME']:
        print(payload_hash(c['payload']))
        break
"
}

run_node_case() {
  local case_name="$1"
  PAYLOADS_FILE="$PAYLOADS_FILE" CASE_NAME="$case_name" node -e "
import('@contextpassport/core').then(async m => {
  const fs = await import('node:fs');
  const cases = JSON.parse(fs.readFileSync(process.env.PAYLOADS_FILE, 'utf8'));
  const c = cases.find(x => x.name === process.env.CASE_NAME);
  process.stdout.write(m.payloadHash(c.payload) + '\n');
}).catch(e => { console.error(e); process.exit(1); });"
}

echo "test: payload_hash equivalence"
case_names=$(PAYLOADS_FILE="$PAYLOADS_FILE" python -c "
import json, os
with open(os.environ['PAYLOADS_FILE'], encoding='utf-8') as f:
    for c in json.load(f):
        print(c['name'])
")
while IFS= read -r name; do
  name="${name%$'\r'}"  # strip trailing CR on Windows
  [[ -z "$name" ]] && continue
  total=$((total + 1))
  py_hash=$(run_python_case "$name")
  ts_hash=$(run_node_case "$name")
  if [[ "$py_hash" == "$ts_hash" ]]; then
    echo "  PASS  $name"
    passed=$((passed + 1))
  else
    echo "  FAIL  $name"
    echo "        py: $py_hash"
    echo "        ts: $ts_hash"
    failed=$((failed + 1))
    failures+=("$name")
  fi
done <<< "$case_names"

# Test 2: signed vector v07 verifies in both implementations
echo ""
echo "test: signed vector v07 verifies in both implementations"
V07_PATH="$VECTORS_DIR/signed/v07_ed25519_valid.json"
if [[ -f "$V07_PATH" ]]; then
  # Pass path as env var to dodge Windows-backslash escaping inside -c strings.
  py_ok=$(V07_PATH="$V07_PATH" python -c "
import json, os
from context_passport.signing import verify_signature
v = json.load(open(os.environ['V07_PATH']))
print(verify_signature(v['input']['passport']))
")
  ts_ok=$(V07_PATH="$V07_PATH" node -e "
import('@contextpassport/core').then(m => {
  const v = require(process.env.V07_PATH);
  process.stdout.write(String(m.verifySignature(v.input.passport)) + '\n');
});")
  if [[ "$py_ok" == "True" && "$ts_ok" == "true" ]]; then
    echo "  PASS  v07 verifies in both py=$py_ok ts=$ts_ok"
  else
    echo "  FAIL  v07 verification mismatch: py=$py_ok ts=$ts_ok"
    failed=$((failed + 1))
  fi
else
  echo "  SKIP  vectors/signed/v07_ed25519_valid.json not found"
fi

echo ""
echo "Summary: $passed/$total payload-hash tests passed"
if [[ $failed -gt 0 ]]; then
  echo "FAILED vectors: ${failures[*]}"
  exit 1
fi
exit 0

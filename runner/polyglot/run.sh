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
VECTORS_DIR="${REPO_ROOT}/vectors"

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
PAYLOADS=$(cat <<'EOF'
[
  {"name":"simple_string",        "payload": {"input": "hello", "output": "world"}},
  {"name":"nested_object",        "payload": {"input": {"a":1,"b":{"c":2,"d":3}}, "output": "x"}},
  {"name":"key_order_swap",       "payload": {"output":"x", "input":"y"}},
  {"name":"array_with_mixed",     "payload": {"data": [1,"two",true,null,{"k":"v"}]}},
  {"name":"empty_object",         "payload": {}},
  {"name":"empty_string",         "payload": {"input": "", "output": ""}},
  {"name":"unicode_basic",        "payload": {"name":"François","city":"München"}},
  {"name":"unicode_emoji",        "payload": {"msg":"hello 👋 world 🌍"}},
  {"name":"integer_zero",         "payload": {"count": 0}},
  {"name":"large_integer",        "payload": {"id": 12345678901234567}},
  {"name":"deeply_nested",        "payload": {"a":{"b":{"c":{"d":{"e":{"f":"deep"}}}}}}}
]
EOF
)

run_python() {
  local payload="$1"
  python -c "
import json, sys
from context_passport import payload_hash
p = json.loads(sys.argv[1])
print(payload_hash(p))" "$payload"
}

run_node() {
  local payload="$1"
  node -e "
import('@contextpassport/core').then(m => {
  const p = JSON.parse(process.argv[1]);
  process.stdout.write(m.payloadHash(p) + '\n');
}).catch(e => { console.error(e); process.exit(1); });" "$payload"
}

echo "test: payload_hash equivalence"
echo "$PAYLOADS" | python -c "
import json, sys
for case in json.load(sys.stdin):
    print(case['name'] + '|' + json.dumps(case['payload']))
" | while IFS='|' read -r name payload; do
  total=$((total + 1))
  py_hash=$(run_python "$payload")
  ts_hash=$(run_node "$payload")
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
done

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

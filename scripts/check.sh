#!/usr/bin/env bash
# The gate: JSONTestSuite labels (y_ accept, n_ reject) and, for every accepted file,
# a canonical value identical to tools/oracle.py (Python json). DECODER = the Mojo decoder binary.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DECODER:?FAIL setup: set DECODER to the decoder binary (tests/decoder.mojo, built)}"
mkdir -p .work/check; fail=0; y=0; n=0; i=0
for f in tests/cases/JSONTestSuite/*.json; do
  b=$(basename "$f"); exp=.work/check/$b.exp; got=.work/check/$b.got
  python3 -I tools/oracle.py "$f" > "$exp"
  timeout 5 "$DECODER" "$f" > "$got" 2>/dev/null || echo REJECT > "$got"
  case $b in
    y_*) y=$((y+1)); cmp -s "$exp" "$got" || { echo "FAIL y: $b"; fail=$((fail+1)); } ;;
    n_*) n=$((n+1)); [ "$(head -1 "$got")" = REJECT ] || { echo "FAIL n (accepted): $b"; fail=$((fail+1)); } ;;
    i_*) i=$((i+1)) ;;
  esac
done
echo "y: $y must-accept, n: $n must-reject, i: $i not gated; failures: $fail"
[ "$fail" -eq 0 ] || { echo "FAIL check: $fail case(s)"; exit 1; }
echo "PASS all"

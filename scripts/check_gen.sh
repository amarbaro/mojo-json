#!/usr/bin/env bash
# The generated-corpus gate: tools/gen.mojo files (numbers of every shape, whole-Unicode strings, random
# whitespace, nesting, and byte-corrupted twins of each) plus the y_ and i_ files of JSONTestSuite, through
#   decode  DECODER vs tools/oracle.py       canonical values identical (what the oracle rejects must be rejected)
#   encode  ENCODER vs tools/enc_oracle.py   json.dumps byte-identical in four layouts
# Needs DECODER, ENCODER and GEN (built from tests/decoder.mojo, tests/encoder.mojo, tools/gen.mojo).
# COUNT and SEED size the corpus.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DECODER:?FAIL setup: set DECODER to the built tests/decoder.mojo}"
: "${ENCODER:?FAIL setup: set ENCODER to the built tests/encoder.mojo}"
: "${GEN:?FAIL setup: set GEN to the built tools/gen.mojo}"
COUNT=${COUNT:-200}; SEED=${SEED:-7}
rm -rf .work/gen; mkdir -p .work/gen
"$GEN" .work/gen "$COUNT" "$SEED"
fail=0; dec=0; rej=0; enc=0; skip=0
for f in .work/gen/*.json tests/cases/JSONTestSuite/[yi]_*.json; do
  b=$(basename "$f" .json)
  python3 -I tools/oracle.py "$f" > .work/gen/$b.dexp
  timeout 20 "$DECODER" "$f" > .work/gen/$b.dgot 2>/dev/null || echo REJECT > .work/gen/$b.dgot
  if cmp -s .work/gen/$b.dexp .work/gen/$b.dgot; then
    dec=$((dec+1)); [ "$(head -1 .work/gen/$b.dexp)" != REJECT ] || rej=$((rej+1))
  else echo "FAIL decode: $f"; fail=$((fail+1)); fi
  python3 -I tools/enc_oracle.py "$f" > .work/gen/$b.eexp
  case $(head -1 .work/gen/$b.eexp) in
    SKIP) skip=$((skip+1)) ;;
    *) timeout 20 "$ENCODER" "$f" > .work/gen/$b.egot 2>/dev/null || echo REJECT > .work/gen/$b.egot
       if cmp -s .work/gen/$b.eexp .work/gen/$b.egot; then enc=$((enc+1)); else echo "FAIL encode: $f"; fail=$((fail+1)); fi ;;
  esac
done
echo "decode: $dec identical ($rej rejected by both); encode: $enc identical x4 layouts, $skip skipped (duplicate keys); failures: $fail"
[ "$fail" -eq 0 ] || { echo "FAIL check_gen: $fail case(s)"; exit 1; }
echo "PASS all"

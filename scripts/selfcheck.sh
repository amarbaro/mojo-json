#!/usr/bin/env bash
# Proves scripts/check.sh can see a crash: a decoder that aborts on one n_ file (and is the real one elsewhere)
# must make the gate FAIL. A crash is not a REJECT; only the decoder's own `REJECT` with exit 1 is.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DECODER:?FAIL setup: set DECODER to the built tests/decoder.mojo}"
mkdir -p .work
cat > .work/mutant.sh <<M
#!/usr/bin/env bash
case "\$1" in */n_array_extra_comma.json) kill -ABRT \$\$ ;; esac
exec "$PWD/$DECODER" "\$@"
M
chmod +x .work/mutant.sh
if out=$(DECODER=.work/mutant.sh scripts/check.sh 2>&1); then
  echo "FAIL selfcheck: the gate passed a decoder that aborts"; exit 1
fi
grep -q "FAIL crash: n_array_extra_comma.json" <<<"$out" || { echo "FAIL selfcheck: the crash was not named"; echo "$out"; exit 1; }
echo "PASS selfcheck"

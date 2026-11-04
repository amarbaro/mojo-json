#!/usr/bin/env bash
# Proves scripts/check.sh and scripts/check_gen.sh can see a crash: a decoder that aborts on one n_ file (and is the real one elsewhere)
# must make the gate FAIL. A crash is not a REJECT; only the decoder's own `REJECT` with exit 1 is.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DECODER:?FAIL setup: set DECODER to the built tests/decoder.mojo}"
: "${ENCODER:?FAIL setup: set ENCODER to the built tests/encoder.mojo}"
: "${GEN:?FAIL setup: set GEN to the built tools/gen.mojo}"
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
# check_gen.sh: a decoder or encoder that aborts on a file the oracle rejects must fail it too (a crash is not a REJECT)
for who in DECODER ENCODER; do
  bin=${!who}
  cat > .work/mutant_gen.sh <<M
#!/usr/bin/env bash
case "\$1" in */i_number_huge_exp.json) kill -ABRT \$\$ ;; esac
exec "$PWD/$bin" "\$@"
M
  chmod +x .work/mutant_gen.sh
  args=(DECODER="$DECODER" ENCODER="$ENCODER" GEN="$GEN" COUNT=5); args[$([ "$who" = DECODER ] && echo 0 || echo 1)]="$who=.work/mutant_gen.sh"
  if out=$(env "${args[@]}" scripts/check_gen.sh 2>&1); then
    echo "FAIL selfcheck: check_gen.sh passed a $who that aborts"; exit 1
  fi
  grep -q "FAIL crash: .*i_number_huge_exp.json" <<<"$out" || { echo "FAIL selfcheck: check_gen.sh did not name the $who crash"; echo "$out" | tail -5; exit 1; }
done
echo "PASS selfcheck"

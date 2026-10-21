"""Oracle: canonical typed form of a JSON file as Python json parses it, or REJECT.

Canonical form, one token per line, so a Mojo decoder can print the same bytes:
  {N  object with N members, then key/value pairs in document order (duplicates kept)
  [N  array with N elements
  s:<hex of UTF-8>   string     i:<int>  integer that fits Int64     f:<int64 bits>  float64
  t / F / n          true / false / null
Integers outside Int64 are printed as the float64 Python would round them to.
NaN/Infinity literals and lone surrogates are rejected (RFC 8259), unlike Python's default.
"""
import json, math, struct, sys

def bits(x: float) -> str:
    return "f:%d" % struct.unpack("<q", struct.pack("<d", x))[0]

def strict_const(name):
    raise ValueError(name)

def emit(v, out):
    if isinstance(v, Obj):
        out.append("{%d" % len(v.pairs))
        for k, x in v.pairs:
            out.append("s:" + k.encode("utf-8").hex()); emit(x, out)
    elif isinstance(v, list):
        out.append("[%d" % len(v)); [emit(x, out) for x in v]
    elif isinstance(v, str):
        out.append("s:" + v.encode("utf-8").hex())
    elif v is True: out.append("t")
    elif v is False: out.append("F")
    elif v is None: out.append("n")
    elif isinstance(v, int):
        out.append("i:%d" % v if -2**63 <= v < 2**63 else bits(float(v)))
    else:
        if math.isinf(v) or math.isnan(v): raise ValueError("overflow")
        out.append(bits(v))

class Obj:
    def __init__(self, pairs): self.pairs = pairs

def main():
    raw = open(sys.argv[1], "rb").read()
    try:
        text = raw.decode("utf-8")
        v = json.loads(text, object_pairs_hook=Obj, parse_constant=strict_const)
        out = []; emit(v, out)
        "\n".join(out).encode("utf-8")  # lone surrogates in keys/strings fail here
    except (ValueError, RecursionError, UnicodeError):
        print("REJECT"); return
    print("\n".join(out))

main()

"""Encoder oracle: parse FILE as tools/oracle.py does, then print Python's json.dumps of the value in
four layouts, each under a `# mode` line:  compact (",", ":")  default (", ", ": ")  indent2  indent0.
Integers outside Int64 become floats first (the library has no big ints). SKIP for documents with
duplicate keys (Python's dict would drop one) and REJECT for what the library rejects."""
import json, sys

def strict_const(name): raise ValueError(name)
class Dup(Exception): pass

def pairs(ps):
    d = {}
    for k, v in ps:
        if k in d: raise Dup()
        d[k] = v
    return d

def parse_int(s):
    v = int(s)
    return v if -2**63 <= v < 2**63 else float(v)

def strict(v):
    """What oracle.py rejects and Python's json accepts: lone surrogates and floats that overflow."""
    if isinstance(v, str): v.encode("utf-8")
    elif isinstance(v, float) and (v != v or v in (float("inf"), float("-inf"))): raise ValueError("overflow")
    elif isinstance(v, list): [strict(x) for x in v]
    elif isinstance(v, dict): [(strict(k), strict(x)) for k, x in v.items()]

def main():
    raw = open(sys.argv[1], "rb").read()
    try:
        v = json.loads(raw.decode("utf-8"), object_pairs_hook=pairs, parse_constant=strict_const, parse_int=parse_int)
        strict(v)
        out = {
            "compact": json.dumps(v, separators=(",", ":")), "default": json.dumps(v),
            "indent2": json.dumps(v, indent=2), "indent0": json.dumps(v, indent=0),
        }
    except Dup:
        print("SKIP"); return
    except (ValueError, RecursionError, UnicodeError):
        print("REJECT"); return
    for mode, text in out.items():
        print("# " + mode); print(text)

main()

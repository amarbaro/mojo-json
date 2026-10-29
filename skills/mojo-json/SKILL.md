---
name: mojo-json
description: "Parse and write JSON from Mojo with Python json's exact semantics: int/float distinction, key order, ensure_ascii output, strict RFC 8259 parsing. Use when Mojo code must read or build JSON that Python also reads, or must produce json.dumps byte-identical text."
---

# mojo-json

JSON for Mojo 1.2, byte-identical with Python's `json`. Checked against JSONTestSuite and
generated files.

## Install

`mojo build -I <repo>/src app.mojo`, or `mojo precompile <repo>/src/json -o json.mojoc`, or
copy `src/json/`.

## Use

```mojo
from json import Json, parse

def main() raises:
    var doc = parse('{"name": "gpu", "pids": [1, 2], "load": 0.5}')
    print(doc.text("name"), doc.get("pids").len(), doc.opt_f("load").value())

    var out = Json.object()
    out.set("ok", Json.of(True))
    out.set("n", Json.of(3))
    var list = Json.array()
    list.push(Json.of("a"))
    out.set("items", list)
    print(out.dumps())             # {"ok":true,"n":3,"items":["a"]}
    print(out.dumps(False))        # {"ok": true, "n": 3, "items": ["a"]}  (Python's default)
    print(out.dumps(False, 2))     # indent=2
```

## Rules

- `parse(String)` or `parse(Span[UInt8])` for bytes read from a file or socket. Both raise
  `json: <what> at byte N`; catch it, do not assume the input is clean.
- Numbers: `3` is an `INT`, `3.0` and `3e0` are `FLOAT`s, an integer past Int64 becomes a
  `FLOAT`. `1e400`, `NaN` and `Infinity` raise.
- `get(key)` and `at(i)` return **copies** of the subtree. Read a scalar with `text`,
  `opt_f`, `opt_s` (no copy of a nested value), and do not chain `get` in a hot loop.
- `set` keeps the position of an existing key; duplicate keys in a parsed document are kept,
  `get` finds the first.
- `dumps()` is the wire layout (`,` `:`); `dumps(False)` is `json.dumps` default (`, ` `: `);
  `dumps(False, n)` is `indent=n`. Output is ASCII: non-ASCII becomes `\uXXXX`.
- `num()` and `int()` are for numbers: any other kind gives 0.
- Nesting over 1000 levels raises.
- Do not write your own float formatting: `dumps` already prints Python's `repr`.
- Errors worth matching on: `json: extra data at byte 4`, `json: value expected at byte 6`.

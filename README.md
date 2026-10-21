# mojo-json

[![CI](https://github.com/amarbaro/mojo-json/actions/workflows/ci.yml/badge.svg)](https://github.com/amarbaro/mojo-json/actions/workflows/ci.yml)

JSON for Mojo that behaves like Python's `json`: the int/float distinction, key order, and
`json.dumps` output byte for byte. The parser is strict RFC 8259 (JSONTestSuite: 95 of 95
`y_` accepted with values identical to Python's, 188 of 188 `n_` rejected), the writer is
checked against `json.dumps` on generated files in four layouts, and a parsed document is two
buffers with no allocation per value.

```mojo
from json import Json, parse

def main() raises:
    var doc = parse('{"name": "gpu", "pids": [1, 2], "load": 0.5}')
    print(doc.text("name"), doc.get("pids").len(), doc.opt_f("load").value())

    var out = Json.object()
    out.set("ok", Json.of(True))
    out.set("n", Json.of(3))
    print(out.dumps())             # {"ok":true,"n":3}
    print(out.dumps(False))        # {"ok": true, "n": 3}   Python's default layout
```

## Install

Requires Mojo 1.1. The only libc calls are `strtod` and `snprintf`, so no linker flags.

| Way | Command |
|---|---|
| Source path | `mojo build -I path/to/mojo-json/src app.mojo` |
| Precompiled | `mojo precompile src/json -o json.mojoc`, then put it next to your code |
| Vendor | copy `src/json/` into your project |

## What you get

- `parse(String)` and `parse(Span[UInt8])`: strict RFC 8259 with `json: <what> at byte N`
  errors. No `NaN`, no trailing commas, no lone surrogates, UTF-8 checked, nesting capped at
  1000.
- `Json`: seven kinds, accessors (`get`, `at`, `text`, `opt_f`, `opt_s`, `int`, `num`,
  `truthy`, ...), builders (`Json.of`, `array`, `object`, `push`, `set`).
- `dumps(compact, indent)`: `json.dumps(ensure_ascii=True)` byte for byte, including float
  `repr`, `\u007f`, surrogate pairs and `indent=`.
- Integers past Int64 become floats, rounded as Python's `float(int)` rounds.

The API is in [docs/api.md](docs/api.md). The memory and speed design is in
[docs/design.md](docs/design.md).

## Performance

`tests/bench.mojo` against `tools/bench_oracle.py` (Python's C-accelerated `json`) and against
the code this library replaced: 20 passes over a 4.6 MB document of 20,000 records (about
500,000 values), three runs each.

| | parse | dumps (compact) | peak RSS |
|---|---|---|---|
| Python `json` | 734 to 763 ms | 491 to 498 ms | 45.4 MB / 54.2 MB |
| previous Mojo implementation | 1,413 ms | 1,081 ms | 130 MB / 102 MB |
| mojo-json | 199 to 206 ms | 298 to 317 ms | 45.3 to 45.7 MB / 45.2 to 45.7 MB |

The memory is the document itself: the file bytes, a 32-byte node per value, one text buffer.

## Limits

- `get` and `at` copy a subtree and `at(i)` is O(i): read scalars with `text`, `opt_f`,
  `opt_s`, and keep a nested value instead of calling `get` again.
- No streaming, no `object_hook`, no big integers, no `NaN` or `Infinity` (read or written
  by a parsed document; `dumps` still prints them for a `Float64` you put in yourself, as
  Python does).
- Duplicate keys are kept, in order; `get` returns the first.
- A hostile document of nested `[` stops at depth 1000 with an error; nothing else limits
  its size.
- Strings are decoded as they are parsed, so `str()` and `text()` copy.

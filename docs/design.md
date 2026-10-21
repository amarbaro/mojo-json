# Design

## Memory

A parsed document is two growing buffers and nothing else:

- **`n: List[Node]`**, the values in preorder. A `Node` is 32 bytes, widest field first:
  `num: Int64` (an integer, the bits of a float, or 1/0 for a bool), then `koff, klen, soff,
  slen, size` as `UInt32` and `kind` as `UInt8`. A container's `size` is the number of nodes
  in its subtree, so skipping a subtree is one addition and no pointers or child lists exist.
- **`buf: List[UInt8]`**, every member name and string value back to back. A node holds an
  offset and a length into it. No `String` per node, no allocation per value.

The code this replaces held `key: String, kind, size, i: Int, f: Float64, s: String` per node:
80 bytes and up to two heap strings each.

The parser reads the caller's bytes through a pointer: the input is not copied (the old one
copied the whole text into a `List[UInt8]`). Strings are copied into `buf` in runs: a string
with no escape and no non-ASCII byte is one `extend`; only an escape or a multi-byte
sequence leaves the fast path. Floats go through libc `strtod` on a scratch buffer that is
reused, because Mojo's `atof` refuses numbers longer than about 19 digits and rounds only
what it accepts.

`dumps` writes ASCII bytes into one pre-sized list and builds the `String` once at the end.
It walks the nodes by reference; the old one copied each `Node` (two strings) to print it.

### Measurements

`tests/bench.mojo` against `tools/bench_oracle.py` and against the previous implementation
(gpu-wait's `json.mojo`), 20 passes over a 4.6 MB document of 20,000 daemon-state-shaped
records (about 500,000 values), three runs each.

| | parse | dumps (compact) | peak RSS |
|---|---|---|---|
| Python `json` | 734 to 763 ms | 491 to 498 ms | 45.4 to 45.7 MB, 54.1 to 54.3 MB |
| previous Mojo | 1,413 ms | 1,081 ms | 130 MB, 102 MB |
| mojo-json | 199 to 206 ms | 298 to 317 ms | 45.3 to 45.7 MB, 45.2 to 45.7 MB |

Parse is 3.7x Python and 7x the previous code; `dumps` 1.6x Python and 3.5x the previous code
(it took 197 ms before floats were printed through printf, see below).
The RSS is the document: the file bytes (4.6 MB), the node list and the text buffer. An
empty Mojo program uses 11.3 to 11.7 MB.

## Strictness

Probed on the previous parser: it accepted `01`, `+1`, `1.` (as `1.0`), `"\x"` and a raw tab
inside a string, aborted the process on a lone surrogate escape (`chr(55296)` is not a valid
code point), and could not read a number of 20 digits or more. The gates found the rest.
Now: the number grammar is the RFC's, an escape is one of `"\/bfnrtu`,
a `\u` pair must be a high then a low surrogate, and raw bytes are checked as RFC 3629 UTF-8
(`E0 A0..BF`, `ED 80..9F`, `F0 90..BF`, `F4 80..8F`; no `C0`, `C1`, `F5` and up). Nesting past
1,000 raises: the recursive descent would otherwise overflow the stack on `[[[[...`.

## Python compatibility, and where it stops

- `dumps` is `json.dumps(ensure_ascii=True)`. Floats print Python's `repr`: Mojo's shortest
  round-trip printing supplies the digit count, but it rounds an exact tie up where Python
  rounds to even (`25110357248038.5625` gave `...563`, Python `...562`; the generated corpus
  found it), so the digits come from `snprintf("%.*e")` at that count, with the layout
  rules of `repr`. Powers of two, whose rounding interval is narrower below, are in the gate; `NaN`, `Infinity` and
  `-Infinity` are written like Python for a `Float64` built by hand.
- DEL (U+007F) is written `\u007f`, as Python does. The previous code wrote it raw.
- Integers past Int64 become floats because there is no big integer. The oracle rounds them
  the same way (`float(int(s))`), and so does `strtod` on the decimal text.
- Duplicate keys are kept, as Python's `object_pairs_hook` can. Python's own `dict` result
  would drop all but the last, so the encoder gate skips those documents.
- Differences kept on purpose from `json.loads`: `NaN`, `Infinity`, lone surrogates, a number
  that overflows to infinity, and nesting past 1,000 raise here.

## The gates, and what they caught

`scripts/check.sh` runs JSONTestSuite (95 `y_` must give Python's values, 188 `n_` must be
rejected). `scripts/check_gen.sh` adds files from `tools/gen.mojo`: numbers of every shape,
strings from all of Unicode raw and escaped, random whitespace, nesting, duplicate keys, and
for each of those a twin with one to three random byte edits (the oracle decides whether it
is still JSON), plus the 35 `i_` files. Each is decoded and compared with `tools/oracle.py`,
and encoded in four layouts and compared with `tools/enc_oracle.py`.

Twelve mutants of the library (a byte range, a bound, a check removed) were each run through
both scripts: `check.sh` alone killed 3 of them; with `check_gen.sh` all 12 died. The first
generated corpus without the `i_` files and the corrupted twins let two of the 12 live; they
are why those two parts exist.

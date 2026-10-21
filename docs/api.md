# API

Everything here is asserted in `tests/api.mojo`, or checked against Python's `json` by the
decoder and encoder gates (`scripts/check.sh`, `scripts/check_gen.sh`). `from json import ...`.

## parse

| Call | Behaviour |
|---|---|
| `parse(text: String) -> Json` | Parses one JSON document (RFC 8259). |
| `parse(data: Span[UInt8]) -> Json` | The same from bytes; the bytes are checked as UTF-8. |

Strict where Python's `json.loads` is lax, so a document that parses here parses everywhere:

- No `NaN`, `Infinity`, `-Infinity`, no leading zeros (`01`), no `+1`, `.5` or `1.`, no trailing
  comma, no comments, no single quotes, no raw control character in a string.
- A `\u` escape that is half of a surrogate pair, or a lone surrogate, raises. Raw invalid
  UTF-8 (overlong forms, encoded surrogates, above U+10FFFF, truncated sequences) raises. A
  byte order mark raises.
- A number whose float value is infinite (`1e400`) raises.
- Nesting deeper than `MAX_DEPTH` (1000) raises instead of overflowing the stack.

Numbers keep Python's distinction: no fraction and no exponent and it fits Int64 gives an
`INT`; anything else, including an integer past Int64, gives a `FLOAT` rounded to nearest
(the same double Python's `float(int(s))` gives). `-0` is the integer 0, `-0.0` is a float.
Duplicate object keys are kept in document order.

Errors are `Error("json: <what> at byte N")`: `unexpected end`, `value expected`,
`object key expected`, `':' expected`, `',' or closing bracket expected`, `extra data`,
`unterminated string`, `control character in string`, `bad escape`, `bad \u escape`,
`lone surrogate`, `invalid UTF-8`, `number out of range`, `digit expected after '.'`,
`digit expected in exponent`, `nesting deeper than 1000`.

## Json

A value of one of seven kinds: `NULL BOOL INT FLOAT STR ARR OBJ` (`UInt8` constants).

| Call | Behaviour |
|---|---|
| `Json()` | null. |
| `Json.of(v)` | From `String`, `Int`, `Float64`, `Bool`, or an `Optional` of `String`, `Int`, `Float64` (an empty one is null). |
| `Json.array()`, `Json.object()` | Empty containers. |
| `kind()`, `is_null()`, `is_num()` | `is_num` is true for `INT` and `FLOAT`, not `BOOL`. |
| `int()` | An `INT` or `BOOL` as is, a `FLOAT` truncated toward zero; 0 for any other kind. |
| `num()` | An `INT` or `FLOAT` as `Float64`; 0.0 for any other kind (also for `BOOL`). |
| `str()` | The text of a `STR`; empty for any other kind. |
| `truthy()` | Python's `bool()`: false for null, `false`, 0, 0.0, "", `[]`, `{}`. |
| `len()` | Elements of an array, members of an object, 0 for a scalar. |
| `at(i)` | Element or member `i` as a copy; null past the end. O(i) plus the size of the copy. |
| `key_at(i)` | The name of member `i`; empty past the end. |
| `get(key)` | The member as a copy; null when absent or when this is not an object. The first of duplicate keys. |
| `has(key)`, `text(key, default="")`, `opt_f(key)`, `opt_s(key)` | Whether the key exists; its string (or `default` when it is absent or not a string); its number or string as an `Optional`. |
| `push(v)` | Appends a copy of `v` to an array. |
| `set(key, v)` | Replaces the first member named `key` in place (its position stays), or appends one. A copy of `v`. |
| `dumps(compact=True, indent=-1) -> String` | Python's `json.dumps(ensure_ascii=True)`. `compact` gives `,` and `:`; otherwise Python's default `, ` and `: `. `indent >= 0` breaks lines like `json.dumps(indent=n)` (separators `,` and `: `). |

`dumps` output is ASCII: everything above U+007E is `\uXXXX` (lower-case hex, surrogate pairs
above U+FFFF), as are control characters and DEL; `\" \\ \n \r \t \b \f` use the short
forms; `/` is not escaped. Floats print as Python's `repr` (`1.0`, `1e+16`, `1e-05`,
`5e-324`), and `NaN`, `Infinity`, `-Infinity` for the values that have no JSON form (a parsed
document never holds them).

`Json` is `Copyable` and `Movable`. `get`, `at` and `push` copy a subtree: take what you need
once and keep it, rather than chaining `get` in a loop.

## What the gates pin down

- All 95 `y_` files of JSONTestSuite parse to values identical to Python's, 188 `n_` files are
  rejected, and the 35 `i_` files agree with Python (each accepted or rejected the same way).
- Generated files (numbers of every shape, strings across all of Unicode raw, escaped and
  mixed, random whitespace, nesting) decode to the same value as Python and `dumps` to the same
  bytes as `json.dumps` in four layouts: compact, default, `indent=2`, `indent=0`.

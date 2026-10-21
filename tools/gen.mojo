# Deterministic corpus for the gate: `gen DIR COUNT SEED` writes DIR/g_NNNN.json.
# Every file is valid RFC 8259 JSON (the oracle accepts it unless a number overflows a float), built to
# hit what JSONTestSuite does not: numbers of every shape, strings from the whole Unicode range raw,
# \u-escaped and mixed, random whitespace, nesting, duplicate keys (decoder gate only). Each g_ file
# also gets an m_ twin with one to three random byte edits: the oracle decides if it is still JSON.
from std.memory import bitcast
from std.pathlib import Path
from std.sys import argv


struct Gen:
    var s: UInt64
    var out: List[UInt8]
    var edge: List[StaticString]

    def __init__(out self, seed: Int):
        self.edge = [
            "0", "-0", "0.0", "-0.0", "1e0", "1E+2", "9007199254740993", "9223372036854775807", "9223372036854775808",
            "-9223372036854775808", "-9223372036854775809", "4.9e-324", "2.2250738585072014e-308", "1.7976931348623157e308",
            "5e-324", "2.4703282292062327e-324", "2.4703282292062328e-324", "0.1", "123456789012345678901234567890e-10",
            "100000000000000000000000000000", "0.000001", "1e-7", "1e16", "1e15", "123456789.123456789", "-1.5E-10",
        ]
        self.s = UInt64(seed) * 0x9E3779B97F4A7C15 + 0x1234567
        self.out = List[UInt8]()

    def next(mut self) -> UInt64:
        self.s ^= self.s >> 12
        self.s ^= self.s << 25
        self.s ^= self.s >> 27
        return self.s * 0x2545F4914F6CDD1D

    def below(mut self, n: Int) -> Int:
        return Int(self.next() >> 11) % n

    def chance(mut self, pct: Int) -> Bool:
        return self.below(100) < pct

    def put(mut self, s: StringSlice):
        self.out.extend(s.as_bytes())

    def ws(mut self):
        if self.chance(50):
            var opts: List[StaticString] = ["", "", "", " ", "\n", "\t", "  ", "\r\n", " \n\t "]
            self.put(opts[self.below(len(opts))])

    def digits(mut self, n: Int):
        for _ in range(n):
            self.out.append(UInt8(48 + self.below(10)))

    def number(mut self):
        var k = self.below(8)
        if k < 4 and self.chance(33):
            self.put("-")
        if k == 0:  # an int, up to 18 digits
            self.out.append(UInt8(49 + self.below(9)))
            self.digits(self.below(18))
        elif k == 1:  # wider than Int64
            self.out.append(UInt8(49 + self.below(9)))
            self.digits(19 + self.below(11))
        elif k == 2:  # a decimal
            self.out.append(UInt8(49 + self.below(9)))
            self.digits(self.below(11))
            self.put(".")
            self.digits(1 + self.below(25))
        elif k == 3:  # exponent form; the exponent reaches the subnormal range and past 1e308
            self.out.append(UInt8(49 + self.below(9)))
            self.digits(self.below(8))
            if self.chance(60):
                self.put(".")
                self.digits(1 + self.below(19))
            self.put("e" if self.chance(50) else "E")
            var sg = self.below(3)
            self.put("" if sg == 0 else ("+" if sg == 1 else "-"))
            self.put(String(self.below(300) if self.chance(50) else self.below(345)))
        elif k == 4:  # a random double
            while True:
                var x = bitcast[DType.float64](self.next())
                if x == x and x - x == 0:
                    self.put(String(x))
                    break
        elif k == 7:  # n / 2^j: an exact decimal one digit past what 17 digits can hold, so a tie
            var n = Float64((self.next() >> 11) | (UInt64(1) << 50)) / Float64(1 << self.below(11))
            self.put(String(n))
        else:
            self.put(self.edge[self.below(len(self.edge))])

    def codepoint(mut self) -> Int:
        var k = self.below(100)
        if k < 55:
            return 32 + self.below(95)
        if k < 63:
            return self.below(32)
        if k < 69:
            var opts: List[Int] = [34, 92, 47, 127]
            return opts[self.below(4)]
        if k < 80:
            return 128 + self.below(0x800 - 128)
        if k < 90:
            var c = 0x800 + self.below(0x10000 - 0x800 - 0x800)
            return c if c < 0xD800 else c + 0x800
        if k < 98:
            return 0x10000 + self.below(0x100000)
        var sp: List[Int] = [0x2028, 0x2029, 0xFFFF, 0xFFFE, 0, 0x10FFFF, 0xD7FF, 0xE000, 0x7F, 0x80, 0x9F, 0xA0]
        return sp[self.below(len(sp))]

    def u4(mut self, c: Int):
        comptime LO = "0123456789abcdef".as_bytes()
        comptime UP = "0123456789ABCDEF".as_bytes()
        var upper = self.chance(30)
        self.put("\\u")
        for sh in range(4):
            var d = (c >> (12 - 4 * sh)) & 15
            self.out.append(UP[d] if upper else LO[d])

    def raw(mut self, c: Int):
        if c < 0x80:
            self.out.append(UInt8(c))
        elif c < 0x800:
            self.out.append(UInt8(0xC0 | (c >> 6)))
            self.out.append(UInt8(0x80 | (c & 0x3F)))
        elif c < 0x10000:
            self.out.append(UInt8(0xE0 | (c >> 12)))
            self.out.append(UInt8(0x80 | ((c >> 6) & 0x3F)))
            self.out.append(UInt8(0x80 | (c & 0x3F)))
        else:
            self.out.append(UInt8(0xF0 | (c >> 18)))
            self.out.append(UInt8(0x80 | ((c >> 12) & 0x3F)))
            self.out.append(UInt8(0x80 | ((c >> 6) & 0x3F)))
            self.out.append(UInt8(0x80 | (c & 0x3F)))

    def quote(mut self):
        var style = self.below(3)  # raw, ascii, mixed
        self.put('"')
        for _ in range(self.below(40)):
            var c = self.codepoint()
            if c == 34 or c == 92 or (c == 47 and self.chance(30)):
                self.out.append(92)
                self.out.append(UInt8(c))
            elif c == 8 or c == 9 or c == 10 or c == 12 or c == 13:
                self.out.append(92)
                self.out.append(UInt8(98 if c == 8 else (116 if c == 9 else (110 if c == 10 else (102 if c == 12 else 114)))))
            elif c < 32 or (c == 127 and self.chance(50)):
                self.u4(c)
            elif (style == 1 and c > 126) or (style == 2 and c > 126 and self.chance(50)) or self.chance(3):
                if c > 0xFFFF:
                    self.u4(0xD800 + ((c - 0x10000) >> 10))
                    self.u4(0xDC00 + ((c - 0x10000) & 0x3FF))
                else:
                    self.u4(c)
            else:
                self.raw(c)
        self.put('"')

    def value(mut self, depth: Int, dup: Bool):
        var k = self.below(100)
        if depth < 4 and k < 25:
            self.put("[")
            self.ws()
            for i in range(self.below(6)):
                if i > 0:
                    self.put(",")
                self.ws()
                self.value(depth + 1, dup)
                self.ws()
            self.put("]")
        elif depth < 4 and k < 45:
            self.put("{")
            self.ws()
            var n = self.below(6)
            for i in range(n):
                if i > 0:
                    self.put(",")
                self.ws()
                if dup and n >= 2 and (i == 0 or i == n - 1):
                    self.put('"dup"')  # the same key twice
                else:
                    self.quote()
                self.ws()
                self.put(":")
                self.ws()
                self.value(depth + 1, dup)
                self.ws()
            self.put("}")
        elif k < 65:
            self.number()
        elif k < 90:
            self.quote()
        else:
            var lit: List[StaticString] = ["true", "false", "null"]
            self.put(lit[self.below(3)])


def corrupt(mut g: Gen):
    """One to three random edits (delete, insert, replace, repeat a byte) at points that stress the grammar."""
    var pool: List[Int] = [34, 92, 44, 58, 91, 93, 123, 125, 43, 45, 46, 48, 49, 101, 69, 32, 10, 117, 110, 116, 120, 127, 0, 1, 0x80, 0xC0, 0xED, 0xF4, 0xFF, 0xBF]
    for _ in range(1 + g.below(3)):
        if len(g.out) == 0:
            return
        var at = g.below(len(g.out))
        var op = g.below(4)
        var b = UInt8(pool[g.below(len(pool))])
        if op == 0:
            _ = g.out.pop(at)
        elif op == 1:
            g.out.insert(at, b)
        elif op == 2:
            g.out[at] = b
        else:
            g.out.insert(at, g.out[at])


def powers_of_two(mut g: Gen):
    """Every power of two and its two neighbours: their rounding interval is narrower below."""
    g.out.clear()
    g.put("[")
    var first = True
    for k in range(-1074, 1024):
        var x = Float64(1.0)
        if k < -1022:
            x = bitcast[DType.float64](UInt64(1) << UInt64(k + 1074))
        else:
            x = bitcast[DType.float64](UInt64(k + 1023) << 52)
        for d in range(-1, 2):
            var y = bitcast[DType.float64](UInt64(Int(bitcast[DType.uint64](x)) + d))
            if y == y and y - y == 0 and y > 0:
                g.put("" if first else ",")
                first = False
                g.put(String(y))
    g.put("]")


def main() raises:
    var dir = String(argv()[1])
    var count = atol(argv()[2])
    var g = Gen(atol(argv()[3]))
    powers_of_two(g)
    Path(dir + "/p_pow2.json").write_bytes(g.out)
    for i in range(count):
        g.out.clear()
        g.ws()
        if i % 6 == 0:  # a bare scalar at the top level
            var k = g.below(3)
            if k == 0:
                g.number()
            elif k == 1:
                g.quote()
            else:
                g.put("true")
        else:
            g.put("[")
            for j in range(1 + g.below(24)):
                if j > 0:
                    g.put(",")
                g.ws()
                g.value(1, i % 17 == 0)
                g.ws()
            g.put("]")
        g.ws()
        var name = "0" * (4 - String(i).byte_length()) + String(i)
        Path(dir + "/g_" + name + ".json").write_bytes(g.out)
        corrupt(g)
        Path(dir + "/m_" + name + ".json").write_bytes(g.out)

# Every behaviour docs/api.md states. The decoder and encoder gates cover parse and dumps against
# Python's json; this file pins the value API and the error cases.
from std.testing import assert_equal, assert_true, assert_false
from json import Json, parse, NULL, BOOL, INT, FLOAT, STR, ARR, OBJ, MAX_DEPTH


def rejects(text: String) raises:
    try:
        _ = parse(text)
        assert_true(False, "accepted: " + text)
    except e:
        assert_true(String(e).startswith("json: "), String(e))


def test_values() raises:
    assert_equal(Json().kind(), NULL)
    assert_equal(Json.of(True).kind(), BOOL)
    assert_equal(Json.of(3).kind(), INT)
    assert_equal(Json.of(2.5).kind(), FLOAT)
    assert_equal(Json.of("x").kind(), STR)
    assert_equal(Json.array().kind(), ARR)
    assert_equal(Json.object().kind(), OBJ)
    assert_true(Json().is_null() and not Json.of(0).is_null())
    assert_true(Json.of(1).is_num() and Json.of(1.5).is_num() and not Json.of(True).is_num() and not Json.of("1").is_num())
    assert_equal(Json.of(7).int(), 7)
    assert_equal(Json.of(7).num(), 7.0)
    assert_equal(Json.of(2.9).int(), 2, "a float truncates")
    assert_equal(Json.of(-2.9).int(), -2)
    assert_equal(Json.of(True).int(), 1)
    assert_equal(Json.of(True).num(), 0.0, "num() is for numbers: 0.0 for any other kind")
    assert_equal(Json.of("x").int(), 0)
    assert_equal(Json.of("héllo").str(), "héllo")
    assert_equal(Json.of(3).str(), "")
    assert_equal(Json.of(Optional[Int]()).kind(), NULL)
    assert_equal(Json.of(Optional[Float64](1.5)).num(), 1.5)
    assert_equal(Json.of(Optional[String]("s")).str(), "s")
    assert_equal(Json.of(Optional[Int](4)).int(), 4)
    # truthiness as Python's bool()
    assert_false(Json().truthy() or Json.of(False).truthy() or Json.of(0).truthy() or Json.of(0.0).truthy())
    assert_false(Json.of("").truthy() or Json.array().truthy() or Json.object().truthy())
    assert_true(Json.of(True).truthy() and Json.of(-1).truthy() and Json.of(0.1).truthy() and Json.of(" ").truthy())
    assert_true(parse("[0]").truthy() and parse('{"a":null}').truthy())


def test_containers() raises:
    var o = Json.object()
    o.set("b", Json.of(1))
    o.set("a", Json.of("x"))
    o.set("b", Json.of(2.5))  # replaces in place: key order stays
    assert_equal(o.dumps(), '{"b":2.5,"a":"x"}')
    assert_equal(o.len(), 2)
    assert_equal(o.key_at(0), "b")
    assert_equal(o.key_at(1), "a")
    assert_equal(o.key_at(2), "")
    assert_true(o.has("a") and not o.has("c"))
    assert_equal(o.get("a").str(), "x")
    assert_true(o.get("c").is_null())
    assert_equal(o.text("a"), "x")
    assert_equal(o.text("b", "dflt"), "dflt", "a number is not text")
    assert_equal(o.text("zz", "dflt"), "dflt")
    assert_equal(o.opt_f("b").value(), 2.5)
    assert_false(o.opt_f("a").__bool__())
    assert_equal(o.opt_s("a").value(), "x")
    assert_false(o.opt_s("b").__bool__())
    assert_equal(o.at(0).num(), 2.5)
    assert_true(o.at(5).is_null())
    var arr = Json.array()
    arr.push(Json.of(1))
    arr.push(o)
    arr.push(Json.array())
    assert_equal(arr.dumps(), '[1,{"b":2.5,"a":"x"},[]]')
    assert_equal(arr.len(), 3)
    assert_equal(arr.at(1).get("a").str(), "x")
    assert_true(arr.get("b").is_null(), "get on an array is null")
    o.set("list", arr)  # nests a copy
    assert_equal(o.dumps(False), '{"b": 2.5, "a": "x", "list": [1, {"b": 2.5, "a": "x"}, []]}')
    o.set("a", Json.object())  # a replacement of another size shifts what follows
    assert_equal(o.dumps(), '{"b":2.5,"a":{},"list":[1,{"b":2.5,"a":"x"},[]]}')
    # get() hands out a copy
    var inner = o.get("list")
    inner.push(Json.of(9))
    assert_equal(o.get("list").len(), 3)
    assert_equal(inner.len(), 4)


def test_dumps() raises:
    var v = parse('{"k": [1, 2.0, "é", {"e": {}, "a": []}], "n": null, "t": true, "f": false}')
    assert_equal(v.dumps(), '{"k":[1,2.0,"\\u00e9",{"e":{},"a":[]}],"n":null,"t":true,"f":false}')
    assert_equal(v.dumps(False), '{"k": [1, 2.0, "\\u00e9", {"e": {}, "a": []}], "n": null, "t": true, "f": false}')
    assert_equal(
        v.dumps(False, 2),
        '{\n  "k": [\n    1,\n    2.0,\n    "\\u00e9",\n    {\n      "e": {},\n      "a": []\n    }\n  ],\n  "n": null,\n  "t": true,\n  "f": false\n}',
    )
    assert_equal(Json.of("a\"b\\c\n\r\t\x08\x0c\x01\x7f/😀").dumps(), '"a\\"b\\\\c\\n\\r\\t\\b\\f\\u0001\\u007f/\\ud83d\\ude00"')
    assert_equal(Json.of(1.0).dumps(), "1.0")
    assert_equal(Json.of(1e16).dumps(), "1e+16")
    assert_equal(Json.of(1e-5).dumps(), "1e-05")
    assert_equal(Json.of(-0.0).dumps(), "-0.0")
    assert_equal(parse("0.30000000000000004").dumps(), "0.30000000000000004")
    assert_equal(Json.of(Float64.MAX_FINITE).dumps(), "1.7976931348623157e+308")
    assert_equal(Json.of(Float64.MAX).dumps(), "Infinity")
    assert_equal(Json.of(-Float64.MAX).dumps(), "-Infinity")
    assert_equal(Json.of(Float64.MAX - Float64.MAX).dumps(), "NaN")
    assert_equal(Json.of(-5).dumps(), "-5")
    assert_equal(Json().dumps(), "null")


def test_parse() raises:
    assert_equal(parse(" [1 , 2\n]\t").dumps(), "[1,2]")
    assert_equal(parse("9223372036854775807").int(), 9223372036854775807)
    assert_equal(parse("9223372036854775807").kind(), INT)
    assert_equal(parse("-9223372036854775808").kind(), INT)
    assert_equal(parse("9223372036854775808").kind(), FLOAT, "past Int64: a float, as Python's float(int)")
    assert_equal(parse("9223372036854775808").dumps(), "9.223372036854776e+18")
    assert_equal(parse("123456789012345678901234567890").dumps(), "1.2345678901234568e+29")
    assert_equal(parse("-0").dumps(), "0")
    assert_equal(parse("-0.0").dumps(), "-0.0")
    assert_equal(parse("1E2").dumps(), "100.0")
    assert_equal(parse("5e-324").dumps(), "5e-324")
    assert_equal(parse("25110357248038.5625").dumps(), "25110357248038.562", "a tie rounds to even, as Python's repr does")
    assert_equal(parse("0.5").dumps(), "0.5")
    assert_equal(parse("123456789012345.6").dumps(), "123456789012345.6")
    assert_equal(parse("1234567890123456.7").dumps(), "1234567890123456.8")
    assert_equal(parse("12345678901234567.0").dumps(), "1.2345678901234568e+16")
    assert_equal(parse("0.0001").dumps(), "0.0001")
    assert_equal(parse("0.00001234").dumps(), "1.234e-05")
    assert_equal(parse("2.2250738585072011e-308").dumps(), "2.225073858507201e-308")
    assert_equal(parse('"\\u00e9\\ud83d\\ude00\\/"').str(), "é😀/")
    assert_equal(parse('"\\u0000x"').str().byte_length(), 2, "NUL is allowed in a string")
    assert_equal(parse('{"a":1,"a":2}').len(), 2, "duplicate keys are kept")
    assert_equal(parse('{"a":1,"a":2}').get("a").int(), 1, "get finds the first")
    var raw = "\"é\"".as_bytes()
    assert_equal(parse(raw).str(), "é", "parse takes bytes too")
    # deep nesting: MAX_DEPTH levels parse, one more raises
    assert_equal(parse("[" * MAX_DEPTH + "]" * MAX_DEPTH).kind(), ARR)
    rejects("[" * (MAX_DEPTH + 1) + "]" * (MAX_DEPTH + 1))
    rejects("[" * 100000)


def test_rejects() raises:
    for bad in [
        "", " ", "[", "]", "[1,]", "[,1]", "[1 2]", '{"a":1,}', '{"a"}', '{a:1}', "{1:1}", "'a'", "01", "-01", "+1", "-", ".5",
        "1.", "1.e1", "1e", "1e+", "0x10", "NaN", "Infinity", "-Infinity", "nul", "True", "truee", "[truex]", "1 2", "[1]]",
        '"a', '"\\x"', '"\\u12"', '"\\u12g4"', '"\\ud800"', '"\\udc00"', '"\\ud800\\u0041"', '"\\ud800\\ud800"', '"a\tb"',
        '"a\nb"', "1e400", "-1e400", "[1e999]", "\"\x01\"",
    ]:
        rejects(String(bad))
    # invalid UTF-8 and a BOM, as bytes
    for hexs in ["22c322", "22c0af22", "22eda08022", "22f490808022", "22e28222", "22ff22", "efbbbf31", "22c2"]:
        var b = List[UInt8]()
        for i in range(0, hexs.byte_length(), 2):
            b.append(UInt8(atol(String(hexs[byte=i : i + 2]), base=16)))
        try:
            _ = parse(Span(b))
            assert_true(False, "accepted invalid bytes " + String(hexs))
        except e:
            assert_true(String(e).startswith("json: "))
    try:
        _ = parse("[1, 2,]")
    except e:
        assert_equal(String(e), "json: value expected at byte 6")
    try:
        _ = parse("[1] x")
    except e:
        assert_equal(String(e), "json: extra data at byte 4")


def main() raises:
    test_values()
    test_containers()
    test_dumps()
    test_parse()
    test_rejects()
    print("api: ok")

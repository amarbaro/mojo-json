# Property smoke step: parse(dumps(x)) == x for random arrays of strings (ASCII to 4 byte UTF-8) and Ints.
from proptest import check, Lists, Strings, Ints
from json import Json, parse


def strs(xs: List[String]) raises -> Bool:
    var a = Json.array()
    for s in xs:
        a.push(Json.of(s))
    var b = parse(a.dumps())
    for i in range(len(xs)):
        if b.at(i).str() != xs[i]:
            return False
    return b.len() == len(xs) and b.dumps() == a.dumps()


def ints(xs: List[Int]) raises -> Bool:
    var a = Json.array()
    for x in xs:
        a.push(Json.of(x))
    return parse(a.dumps()).dumps() == a.dumps()


def main() raises:
    check(Lists(Strings(12), 8), strs, n=2000)
    check(Lists(Ints(Int.MIN, Int.MAX), 8), ints, n=2000)
    print("prop: ok")

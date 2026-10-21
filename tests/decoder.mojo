# The Mojo side of tools/oracle.py: `decoder FILE` prints the canonical form of the parsed document
# (see oracle.py), or REJECT with exit code 1 when the library refuses it.
from std.memory import bitcast
from std.pathlib import Path
from std.sys import argv, exit
from json import parse, Json, NULL, BOOL, INT, FLOAT, STR, ARR, OBJ


def hex_of(buf: List[UInt8], off: UInt32, n: UInt32, mut out: String):
    comptime HEX = "0123456789abcdef".as_bytes()
    for i in range(Int(off), Int(off) + Int(n)):
        out += chr(Int(HEX[Int(buf[i] >> 4)]))
        out += chr(Int(HEX[Int(buf[i] & 15)]))


def emit(j: Json, at: Int, mut out: String) -> Int:
    """Append the canonical lines of the node at `at`; return the index after its subtree."""
    var nd = j.n[at]
    if nd.kind == OBJ or nd.kind == ARR:
        var kids = 0
        var k = at + 1
        while k < at + Int(nd.size):
            kids += 1
            k += Int(j.n[k].size)
        out += ("{" if nd.kind == OBJ else "[") + String(kids) + "\n"
        k = at + 1
        while k < at + Int(nd.size):
            if nd.kind == OBJ:
                out += "s:"
                hex_of(j.buf, j.n[k].koff, j.n[k].klen, out)
                out += "\n"
            k = emit(j, k, out)
    elif nd.kind == STR:
        out += "s:"
        hex_of(j.buf, nd.soff, nd.slen, out)
        out += "\n"
    elif nd.kind == BOOL:
        out += "t\n" if nd.num != 0 else "F\n"
    elif nd.kind == NULL:
        out += "n\n"
    elif nd.kind == INT:
        out += "i:" + String(nd.num) + "\n"
    else:
        out += "f:" + String(nd.num) + "\n"
    return at + Int(nd.size)


def main() raises:
    var j = Json()
    try:
        j = parse(Path(String(argv()[1])).read_bytes())
    except:
        print("REJECT")
        exit(1)
    var out = String()
    _ = emit(j, 0, out)
    print(out[byte = : out.byte_length() - 1])

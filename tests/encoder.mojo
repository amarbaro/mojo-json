# The Mojo side of tools/enc_oracle.py: `encoder FILE` parses FILE and prints dumps() in four layouts.
from std.pathlib import Path
from std.sys import argv, exit
from json import parse, Json


def main() raises:
    var j = Json()
    try:
        j = parse(Path(String(argv()[1])).read_bytes())
    except:
        print("REJECT")
        exit(1)
    print("# compact")
    print(j.dumps())
    print("# default")
    print(j.dumps(False))
    print("# indent2")
    print(j.dumps(False, 2))
    print("# indent0")
    print(j.dumps(False, 0))

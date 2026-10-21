# Speed and memory: `bench MODE FILE` with MODE parse | dumps. The same work as tools/bench_oracle.py.
#   parse   parse FILE 20 times
#   dumps   parse FILE once (untimed), then dumps it 20 times in the compact layout
from std.pathlib import Path
from std.sys import argv
from std.time import perf_counter_ns
from json import parse


def main() raises:
    var mode = argv()[1]
    var data = Path(String(argv()[2])).read_bytes()
    var check = 0
    var ns = 0
    if mode == "parse":
        var t0 = perf_counter_ns()
        for _ in range(20):
            check += parse(Span(data)).len()
        ns = Int(perf_counter_ns() - t0)
    else:
        var j = parse(Span(data))
        var t0 = perf_counter_ns()
        for _ in range(20):
            check += j.dumps().byte_length()
        ns = Int(perf_counter_ns() - t0)
    print(mode, "ms", ns // 1000000, "check", check)

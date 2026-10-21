"""Same work as tests/bench.mojo with Python's json. Usage: bench_oracle.py MODE FILE
  make    write FILE: about 4 MB of records shaped like a daemon's state (short strings, ints, floats, nesting)
  parse   json.loads(FILE) 20 times
  dumps   json.dumps(value, separators=(",", ":")) 20 times (the value is parsed once, untimed)
"""
import json, random, sys, time

mode, path = sys.argv[1], sys.argv[2]
if mode == "make":
    r = random.Random(1)
    recs = []
    for i in range(20000):
        recs.append({"id": "job-%06d" % i, "state": r.choice(["running", "queued", "done", "failed"]),
                     "pid": r.randrange(1, 4_000_000), "vram_mb": r.randrange(0, 24_000), "util": round(r.random() * 100, 3),
                     "cmd": ["python3", "train.py", "--lr", repr(r.random()), "--note", "café ✓"],
                     "env": {"HOME": "/home/user", "CUDA": None, "N": r.randrange(100)}, "ok": r.random() < .5})
    open(path, "w", encoding="utf-8").write(json.dumps(recs, ensure_ascii=False))
    sys.exit()
text = open(path, "rb").read().decode("utf-8")
check = 0
if mode == "parse":
    t0 = time.perf_counter_ns()
    for _ in range(20):
        check += len(json.loads(text))
else:
    v = json.loads(text)
    t0 = time.perf_counter_ns()
    for _ in range(20):
        check += len(json.dumps(v, separators=(",", ":")))
print(mode, "ms", (time.perf_counter_ns() - t0) // 1000000, "check", check)

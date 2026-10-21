from json import Json, parse


def main() raises:
    var doc = parse('{"name": "gpu", "pids": [1, 2], "load": 0.5}')
    print(doc.text("name"), doc.get("pids").len(), doc.opt_f("load").value())

    var out = Json.object()
    out.set("ok", Json.of(True))
    out.set("n", Json.of(3))
    var list = Json.array()
    list.push(Json.of("a"))
    out.set("items", list)
    print(out.dumps())  # {"ok":true,"n":3,"items":["a"]}
    print(out.dumps(False))  # {"ok": true, "n": 3, "items": ["a"]}, Python's default layout
    print(out.dumps(False, 2))  # like indent=2

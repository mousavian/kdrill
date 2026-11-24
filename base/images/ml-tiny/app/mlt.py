"""Small inspection tool for run directories and buckets (used by kdrill verify).

  mlt get LOCATION/metrics.json KEY...   print values (dotted paths, e.g. runs.-1.start_step;
                                         "len:runs" prints a list length), one per line
  mlt ls LOCATION                        list files
  mlt cat LOCATION/FILE                  print a file
  mlt exists LOCATION/FILE               exit 0 if the file exists
  mlt ckpt LOCATION                      print the step of the newest checkpoint (0 if none)

LOCATION is a directory or s3://bucket/prefix (credentials from AWS_* variables).
"""
import io
import json
import sys

from store import open_store


def split(path):
    if "/" not in path.rstrip("/"):
        return path, ""
    loc, _, name = path.rstrip("/").rpartition("/")
    return loc or "/", name


def dig(obj, key):
    for part in key.split("."):
        if isinstance(obj, list):
            obj = obj[int(part)]
        elif isinstance(obj, dict):
            obj = obj.get(part)
        else:
            return None
        if obj is None:
            return None
    return obj


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, target = argv[0], argv[1]
    if cmd == "ls":
        for n in open_store(target).list():
            print(n)
        return 0
    if cmd == "ckpt":
        st = open_store(target)
        names = st.list("ckpt-")
        if not names:
            print(0)
            return 0
        import torch
        ck = torch.load(io.BytesIO(st.get(names[-1])), weights_only=False)
        print(ck["step"])
        return 0
    loc, name = split(target)
    data = open_store(loc).get(name)
    if cmd == "exists":
        return 0 if data is not None else 1
    if data is None:
        print(f"mlt: {target} not found", file=sys.stderr)
        return 1
    if cmd == "cat":
        sys.stdout.write(data.decode(errors="replace"))
        return 0
    if cmd == "get":
        doc = json.loads(data)
        for key in argv[2:]:
            if key.startswith("len:"):
                v = dig(doc, key[4:])
                print(len(v) if isinstance(v, (list, dict)) else 0)
                continue
            v = dig(doc, key)
            print("" if v is None else (json.dumps(v) if isinstance(v, (list, dict)) else v))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

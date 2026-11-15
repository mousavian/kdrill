"""Prepare a dataset for train.py: unpack, clean and describe it.

  python prepare.py --src /opt/ml-tiny/datasets/tinyshakespeare.txt.gz --out /data

Writes OUT/input.txt (UTF-8 text, Windows line endings removed, trailing
spaces trimmed) and OUT/meta.json (source, characters, vocabulary, sha256).
In the lab the archive ships inside the image so nothing is downloaded; on a
real cluster this step would fetch it from object storage or a URL.
Idempotent: does nothing when OUT already holds the same data.
"""
import argparse
import datetime
import gzip
import hashlib
import json
import os
import sys


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--src", default=os.environ.get("DATA_SRC", "/opt/ml-tiny/datasets/tinyshakespeare.txt.gz"))
    p.add_argument("--out", default=os.environ.get("DATA_OUT", "/data"))
    a = p.parse_args()
    raw = gzip.open(a.src).read() if a.src.endswith(".gz") else open(a.src, "rb").read()
    text = "\n".join(line.rstrip() for line in raw.decode("utf-8").replace("\r\n", "\n").split("\n"))
    data = text.encode("utf-8")
    sha = hashlib.sha256(data).hexdigest()
    os.makedirs(a.out, exist_ok=True)
    meta_path = os.path.join(a.out, "meta.json")
    if os.path.exists(meta_path):
        try:
            if json.load(open(meta_path)).get("sha256") == sha:
                print(f"prepare: {a.out} already holds {os.path.basename(a.src)} (sha256 {sha[:12]}), nothing to do")
                return 0
        except ValueError:
            pass
    tmp = os.path.join(a.out, ".input.txt.tmp")
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, os.path.join(a.out, "input.txt"))
    meta = {"source": os.path.basename(a.src), "chars": len(text), "vocab": len(set(text)), "sha256": sha,
            "prepared": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=1)
    print(f"prepare: wrote {a.out}/input.txt ({len(text)} characters, vocabulary {meta['vocab']}, sha256 {sha[:12]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())

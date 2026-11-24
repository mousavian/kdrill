"""Serve a trained model over HTTP (for later courses; stdlib only).

  python serve.py --model /models/run-1 --port 8000
  curl -s localhost:8000/generate -d '{"prompt": "ROMEO:", "chars": 100}'

GET /healthz answers ok once the model is loaded; POST /generate returns
{"text": ..., "chars": N}.
"""
import argparse
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import torch

from model import GPT, GPTConfig
from sample import load


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--model", default=os.environ.get("MODEL", ""), required=not os.environ.get("MODEL"))
    p.add_argument("--port", type=int, default=int(os.environ.get("PORT", 8000)))
    a = p.parse_args()
    torch.set_num_threads(int(os.environ.get("OMP_NUM_THREADS", 1)))
    ck, where = load(a.model)
    model = GPT(GPTConfig(**ck["config"]))
    model.load_state_dict(ck["model"])
    model.eval()
    chars = ck["chars"]
    stoi = {c: i for i, c in enumerate(chars)}
    lock = threading.Lock()

    class H(BaseHTTPRequestHandler):
        def _send(self, code, obj):
            body = json.dumps(obj).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path.startswith("/healthz"):
                return self._send(200, {"status": "ok", "model": where})
            self._send(404, {"error": "not found"})

        def do_POST(self):
            if not self.path.startswith("/generate"):
                return self._send(404, {"error": "not found"})
            try:
                req = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
                n = max(1, min(int(req.get("chars", 100)), 1000))
                prompt = "".join(c for c in str(req.get("prompt", "\n")) if c in stoi) or chars[0]
                g = torch.Generator().manual_seed(int(req.get("seed", 0)))
                with lock:
                    out = model.generate(torch.tensor([[stoi[c] for c in prompt]]), n,
                                         float(req.get("temperature", 0.8)), generator=g)[0].tolist()
                self._send(200, {"text": "".join(chars[i] for i in out), "chars": n})
            except (ValueError, TypeError) as e:
                self._send(400, {"error": str(e)})

        def log_message(self, *args):
            pass

    print(f"serving {where} on :{a.port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", a.port), H).serve_forever()


if __name__ == "__main__":
    sys.exit(main())

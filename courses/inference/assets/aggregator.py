#!/usr/bin/env python3
"""Metrics aggregator for the kdrill inference course (not a model server).

KEDA's metrics-api scaler reads ONE number from ONE URL, but a model server
exposes Prometheus text per pod. This tiny adapter plays the part that
Prometheus plays on a real cluster: it finds every pod behind a headless
Service, scrapes /metrics, adds the values up and serves JSON:

    GET /  ->  {"running": 3, "waiting": 7, "inflight": 10, "replicas": 2,
                "waiting_per_replica": 3.5, "kv_cache_max": 0.42}

Environment: TARGET_HOST (headless Service name), TARGET_PORT (default 8000).
Understands vLLM / llm-d-inference-sim names and llama.cpp names.
"""
import json, os, re, socket, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ["TARGET_HOST"]
PORT = int(os.environ.get("TARGET_PORT", "8000"))
RUNNING = ("vllm:num_requests_running", "llamacpp:requests_processing")
WAITING = ("vllm:num_requests_waiting", "llamacpp:requests_deferred")
KV = ("vllm:kv_cache_usage_perc",)


def scrape(ip):
    out = {}
    try:
        with urllib.request.urlopen("http://%s:%d/metrics" % (ip, PORT), timeout=2) as r:
            for line in r.read().decode().splitlines():
                m = re.match(r"^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{[^}]*\})?\s+([0-9.eE+-]+)$", line)
                if m:
                    out[m.group(1)] = out.get(m.group(1), 0.0) + float(m.group(3))
    except Exception:
        return None
    return out


def snapshot():
    try:
        ips = sorted({a[4][0] for a in socket.getaddrinfo(HOST, PORT, socket.AF_INET, socket.SOCK_STREAM)})
    except socket.gaierror:
        ips = []
    run = wait = 0.0
    kv = 0.0
    n = 0
    for ip in ips:
        m = scrape(ip)
        if m is None:
            continue
        n += 1
        run += sum(m.get(k, 0.0) for k in RUNNING)
        wait += sum(m.get(k, 0.0) for k in WAITING)
        kv = max(kv, max([m.get(k, 0.0) for k in KV] or [0.0]))
    return {"running": run, "waiting": wait, "inflight": run + wait, "replicas": n,
            "waiting_per_replica": (wait / n) if n else 0.0, "kv_cache_max": kv}


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps(snapshot()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()

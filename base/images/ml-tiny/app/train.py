"""Train the tiny character-level GPT. Instrumented for the kdrill lessons.

Every option is a flag and an environment variable (the flag wins), so a Job
can set it either way. Run `python train.py --help` for the list.

What it writes (into --out, which defaults to --ckpt):
  ckpt-NNNNNN.pt   checkpoints (model + optimizer + RNG state), the newest --keep kept
  latest           name of the newest checkpoint
  metrics.json     machine-readable progress: step, loss, status, run history
  model.pt / model.json   with --model-out: final weights + metadata

Exit codes:
  0    finished
  42   injected bug (--fail-at-step), the "fix your code" kind of failure
  75   another worker of a distributed run stopped or vanished (restart the group)
  143  stopped by SIGTERM after writing a final checkpoint
  1    anything else (bad configuration, missing data, storage errors)
"""
import argparse
import datetime
import hashlib
import io
import json
import os
import resource
import signal
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import torch

from model import GPT, GPTConfig
from store import open_store

EXIT_BUG, EXIT_PEER, EXIT_SIGTERM = 42, 75, 143


def env(name, default):
    v = os.environ.get(name)
    return default if v in (None, "") else v


def parse_args(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a = p.add_argument
    a("--data", default=env("DATA", ""), help="text file, or a directory with input.txt (from prepare.py) [DATA]")
    a("--steps", type=int, default=int(env("STEPS", 2000)), help="train until this step [STEPS]")
    a("--batch-size", type=int, default=int(env("BATCH_SIZE", 32)), help="sequences per step and worker [BATCH_SIZE]")
    a("--block-size", type=int, default=int(env("BLOCK_SIZE", 64)), help="context length in characters [BLOCK_SIZE]")
    a("--n-layer", type=int, default=int(env("N_LAYER", 3)), help="[N_LAYER]")
    a("--n-head", type=int, default=int(env("N_HEAD", 4)), help="[N_HEAD]")
    a("--n-embd", type=int, default=int(env("N_EMBD", 96)), help="[N_EMBD]")
    a("--lr", type=float, default=float(env("LR", 3e-3)), help="learning rate [LR]")
    a("--seed", default=env("SEED", ""), help="random seed; empty = a different one every run [SEED]")
    a("--ckpt", default=env("CKPT_DIR", ""), help="checkpoint location: a directory or s3://bucket/prefix; empty = none [CKPT_DIR]")
    a("--ckpt-every", type=int, default=int(env("CKPT_EVERY", 100)), help="checkpoint every N steps [CKPT_EVERY]")
    a("--ckpt-write-seconds", type=float, default=float(env("CKPT_WRITE_SECONDS", 0)),
      help="pretend each checkpoint takes this long to write (slow storage) [CKPT_WRITE_SECONDS]")
    a("--keep", type=int, default=int(env("CKPT_KEEP", 3)), help="keep the newest N checkpoints, 0 = all [CKPT_KEEP]")
    a("--resume", default=env("RESUME", "auto"), choices=["auto", "never"], help="auto: continue from the newest checkpoint [RESUME]")
    a("--out", default=env("OUT_DIR", ""), help="where metrics.json goes (default: the checkpoint location, else /tmp/run) [OUT_DIR]")
    a("--model-out", default=env("MODEL_OUT", ""), help="write the final model (model.pt + model.json) here [MODEL_OUT]")
    a("--run-name", default=env("RUN_NAME", ""), help="name recorded in metrics and model metadata [RUN_NAME]")
    a("--eval-every", type=int, default=int(env("EVAL_EVERY", 100)), help="validation loss every N steps [EVAL_EVERY]")
    a("--log-every", type=int, default=int(env("LOG_EVERY", 20)), help="[LOG_EVERY]")
    a("--threads", type=int, default=int(env("THREADS", 0)), help="torch threads; 0 = OMP_NUM_THREADS or every core [THREADS]")
    a("--fail-at-step", type=int, default=int(env("FAIL_AT_STEP", 0)), help="inject a crash at this step [FAIL_AT_STEP]")
    a("--fail-exit-code", type=int, default=int(env("FAIL_EXIT_CODE", EXIT_BUG)), help="[FAIL_EXIT_CODE]")
    a("--fail-rank", type=int, default=int(env("FAIL_RANK", -1)), help="only this rank crashes; -1 = every rank [FAIL_RANK]")
    a("--fail-once", default=env("FAIL_ONCE", "false"), help="crash only the first time (remembered in the checkpoint location) [FAIL_ONCE]")
    a("--metrics-port", type=int, default=int(env("METRICS_PORT", 0)), help="serve Prometheus metrics on this port [METRICS_PORT]")
    a("--dist-timeout", type=int, default=int(env("DIST_TIMEOUT", 120)), help="seconds to wait for the other workers [DIST_TIMEOUT]")
    return p.parse_args(argv)


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def log(msg):
    print(f"[{now()}] {msg}", flush=True)


# ------------------------------------------------------------------ cgroup ----
def _read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def _v1_cpu_dir():
    """The cgroup v1 cpu directory of this container. Usually the mount point
    itself; when containers are nested (k3s inside Docker) the mount shows an
    outer cgroup, so look for our own path below it."""
    base = next((d for d in ("/sys/fs/cgroup/cpu", "/sys/fs/cgroup/cpu,cpuacct") if os.path.isdir(d)), None)
    if not base:
        return None
    rel = ""
    for line in (_read("/proc/self/cgroup") or "").splitlines():
        parts = line.split(":", 2)
        if len(parts) == 3 and "cpu" in parts[1].split(","):
            rel = parts[2].strip("/")
    comps = [c for c in rel.split("/") if c]
    for k in range(len(comps)):
        cand = os.path.join(base, *comps[k:])
        if os.path.exists(os.path.join(cand, "cpu.cfs_quota_us")):
            return cand
    return base


def cpu_limit():
    """CPU limit of this container in cores (cgroup v2 or v1), or None."""
    v = _read("/sys/fs/cgroup/cpu.max")
    if v:
        quota, period = v.split()
        return None if quota == "max" else int(quota) / int(period)
    d = _v1_cpu_dir()
    if d:
        q, per = _read(d + "/cpu.cfs_quota_us"), _read(d + "/cpu.cfs_period_us")
        if q and per:
            return None if int(q) < 0 else int(q) / int(per)
    return None


def cpu_stat():
    """(periods, throttled_periods, throttled_seconds) for this container."""
    v2 = _read("/sys/fs/cgroup/cpu.stat") if os.path.exists("/sys/fs/cgroup/cpu.max") else None
    d = None if v2 else _v1_cpu_dir()
    v = v2 or (_read(d + "/cpu.stat") if d else None)
    if v:
        st = dict(line.split() for line in v.splitlines() if len(line.split()) == 2)
        if "nr_periods" in st:
            t = int(st.get("throttled_usec", 0)) / 1e6 if v2 else int(st.get("throttled_time", 0)) / 1e9
            return int(st["nr_periods"]), int(st["nr_throttled"]), t
    return 0, 0, 0.0


def max_rss_mb():
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.0


# -------------------------------------------------------------------- data ----
def load_data(path):
    if not path:
        raise SystemExit("error: no training data: pass --data or set DATA (a text file, or a directory from prepare.py)")
    meta = {}
    if os.path.isdir(path):
        mp = os.path.join(path, "meta.json")
        if os.path.exists(mp):
            meta = json.load(open(mp))
        path = os.path.join(path, "input.txt")
    if not os.path.exists(path):
        raise SystemExit(f"error: training data {path} does not exist")
    raw = open(path, "rb").read()
    text = raw.decode("utf-8")
    if len(text) < 1000:
        raise SystemExit(f"error: {path} has only {len(text)} characters; that is not a dataset")
    return text, {"data_path": path, "data_chars": len(text), "data_sha256": hashlib.sha256(raw).hexdigest(),
                  "data_prepared": bool(meta), "data_source": meta.get("source", "")}


# ------------------------------------------------------------- distributed ----
class Dist:
    def __init__(self, timeout):
        self.world = int(env("WORLD_SIZE", 1))
        # an Indexed Job's index is the rank only when the run is distributed
        rank = os.environ.get("RANK") or (os.environ.get("JOB_COMPLETION_INDEX") if self.world > 1 else None) or "0"
        self.rank = int(rank)
        self.timeout = timeout
        self.on = self.world > 1

    def init(self):
        if not self.on:
            return
        import torch.distributed as dist
        addr, port = env("MASTER_ADDR", ""), env("MASTER_PORT", "29500")
        if not addr:
            raise SystemExit("error: WORLD_SIZE > 1 but MASTER_ADDR is not set")
        log(f"rank {self.rank}/{self.world}: joining {addr}:{port} (waits up to {self.timeout}s for the others)")
        deadline = time.time() + self.timeout
        while True:  # the headless Service's DNS record appears only once the pod exists
            try:
                socket.getaddrinfo(addr, int(port))
                break
            except socket.gaierror as e:
                if time.time() > deadline:
                    raise SystemExit(f"error: MASTER_ADDR {addr} does not resolve ({e}); "
                                     "is there a headless Service and does the pod's subdomain match it?")
                log(f"rank {self.rank}: waiting for {addr} to resolve ({e.strerror})")
                time.sleep(3)
        os.environ["MASTER_ADDR"], os.environ["MASTER_PORT"] = addr, port
        dist.init_process_group("gloo", rank=self.rank, world_size=self.world,
                                timeout=datetime.timedelta(seconds=self.timeout))
        log(f"rank {self.rank}/{self.world}: all {self.world} workers connected")

    def any(self, flag):
        """True on every rank if any rank passed True."""
        if not self.on:
            return flag
        import torch.distributed as dist
        t = torch.tensor([1 if flag else 0])
        dist.all_reduce(t, op=dist.ReduceOp.MAX)
        return bool(t.item())

    def gather(self, obj):
        if not self.on:
            return [obj]
        import torch.distributed as dist
        out = [None] * self.world
        dist.all_gather_object(out, obj)
        return out

    def broadcast(self, obj):
        if not self.on:
            return obj
        import torch.distributed as dist
        box = [obj]
        dist.broadcast_object_list(box, src=0)
        return box[0]

    def close(self):
        if self.on:
            import torch.distributed as dist
            try:
                dist.destroy_process_group()
            except Exception:
                pass


# ----------------------------------------------------------------- metrics ----
class Metrics:
    """metrics.json (rank 0 only) plus an optional Prometheus endpoint."""

    def __init__(self, store, enabled, port):
        self.store, self.enabled = store, enabled
        self.m = {}
        self.lock = threading.Lock()
        if port:
            self._serve(port)

    def update(self, **kw):
        with self.lock:
            self.m.update(kw)

    def write(self):
        if not (self.enabled and self.store):
            return
        with self.lock:
            self.m["updated"] = now()
            data = json.dumps(self.m, indent=1, sort_keys=True).encode()
        self.store.put("metrics.json", data)

    def prometheus(self):
        periods, throttled, tsec = cpu_stat()
        with self.lock:
            m = dict(self.m)
        lines = []

        def g(name, help_, val, typ="gauge"):
            if val is None:
                return
            lines.append(f"# HELP {name} {help_}\n# TYPE {name} {typ}\n{name} {val}")

        g("kdrill_train_step", "Last completed training step.", m.get("step", 0))
        g("kdrill_train_target_steps", "Step at which the run stops.", m.get("steps", 0))
        g("kdrill_train_loss", "Training loss (average of the last logging window).", m.get("loss"))
        g("kdrill_train_val_loss", "Latest validation loss.", m.get("val_loss"))
        g("kdrill_train_tokens_per_second", "Training throughput of this worker.", m.get("tokens_per_sec"))
        g("kdrill_train_step_seconds", "Average seconds per step over the last logging window.", m.get("step_seconds"))
        g("kdrill_train_threads", "Torch intra-op threads.", m.get("threads"))
        g("kdrill_train_cpu_limit_cores", "CPU limit of the container (0 = none).", m.get("cpu_limit") or 0)
        g("kdrill_train_cpu_periods_total", "CFS scheduling periods.", periods, "counter")
        g("kdrill_train_cpu_throttled_periods_total", "CFS periods in which the container was throttled.", throttled, "counter")
        g("kdrill_train_cpu_throttled_seconds_total", "Time the container was throttled.", round(tsec, 3), "counter")
        g("kdrill_train_max_rss_megabytes", "Peak resident memory of the training process.", round(max_rss_mb(), 1))
        return ("\n".join(lines) + "\n").encode()

    def _serve(self, port):
        outer = self

        class H(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path.startswith("/metrics"):
                    body, ctype = outer.prometheus(), "text/plain; version=0.0.4"
                elif self.path.startswith("/healthz"):
                    body, ctype = b"ok\n", "text/plain"
                else:
                    with outer.lock:
                        body, ctype = json.dumps(outer.m).encode(), "application/json"
                self.send_response(200)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *a):
                pass

        srv = ThreadingHTTPServer(("0.0.0.0", port), H)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        log(f"metrics: http://0.0.0.0:{port}/metrics")


# --------------------------------------------------------------- checkpoints ----
def latest_ckpt(store):
    if not store:
        return None
    name = store.get("latest")
    if name:
        name = name.decode().strip()
        if store.get(name) is not None:
            return name
    names = store.list("ckpt-")
    return names[-1] if names else None


def save_ckpt(store, step, model, opt, cfg, chars, gen, extra, keep, write_seconds):
    buf = io.BytesIO()
    torch.save({"step": step, "model": model.state_dict(), "optim": opt.state_dict(), "config": cfg.to_dict(),
                "chars": chars, "rng": gen.get_state(), "torch_rng": torch.get_rng_state(), **extra}, buf)
    if write_seconds > 0:
        time.sleep(write_seconds)  # stands in for a multi-gigabyte upload
    name = f"ckpt-{step:06d}.pt"
    store.put(name, buf.getvalue())
    store.put("latest", name.encode())
    if keep > 0:
        for old in store.list("ckpt-")[:-keep]:
            store.delete(old)
    return name


def write_model(uri, model, cfg, chars, meta):
    st = open_store(uri)
    buf = io.BytesIO()
    torch.save({"model": model.state_dict(), "config": cfg.to_dict(), "chars": chars}, buf)
    st.put("model.pt", buf.getvalue())
    st.put("model.json", json.dumps(meta, indent=1, sort_keys=True).encode())
    return st.uri


# --------------------------------------------------------------------- main ----
def main():
    args = parse_args()
    stop = {"sig": None}

    phase = {"training": False}

    def on_term(signum, _frame):
        if not phase["training"]:
            log(f"received {signal.Signals(signum).name} before training started: exiting")
            os._exit(EXIT_SIGTERM)
        stop["sig"] = signum
        log(f"received {signal.Signals(signum).name}: finishing this step, then writing a checkpoint")

    # In a container this process is often PID 1, and the kernel ignores
    # SIGTERM for PID 1 unless a handler is installed, so install one at once.
    # While torch blocks in C++ (the rendezvous), a Python handler cannot run;
    # the wakeup fd still receives the signal, and a watcher thread exits.
    signal.signal(signal.SIGTERM, on_term)
    rfd, wfd = os.pipe()
    os.set_blocking(wfd, False)
    signal.set_wakeup_fd(wfd)

    def watch_signals():
        while True:
            data = os.read(rfd, 1)
            if data and data[0] == signal.SIGTERM and not phase["training"]:
                log("received SIGTERM while waiting for the other workers: exiting")
                os._exit(EXIT_SIGTERM)

    threading.Thread(target=watch_signals, daemon=True).start()

    if args.threads > 0:
        torch.set_num_threads(args.threads)
    threads = torch.get_num_threads()
    limit = cpu_limit()

    dist = Dist(args.dist_timeout)
    host = socket.gethostname()
    run_name = args.run_name or os.environ.get("JOB_NAME", "") or host
    store = open_store(args.ckpt)
    out = open_store(args.out) if args.out else (store or open_store("/tmp/run"))
    if store:
        try:
            store.check()
        except Exception as e:
            log(f"error: checkpoint location {args.ckpt} is not usable: {e}")
            return 1

    text, data_info = load_data(args.data)
    chars = sorted(set(text))
    lut = torch.zeros(ord(chars[-1]) + 1, dtype=torch.long)
    lut[torch.tensor([ord(c) for c in chars])] = torch.arange(len(chars))
    data = lut[torch.frombuffer(bytearray(text.encode("utf-32-le")), dtype=torch.int32).long()]
    n = int(0.9 * len(data))
    train_data, val_data = data[:n], data[n:]

    seed = int(args.seed) if args.seed != "" else int.from_bytes(os.urandom(4), "little")
    cfg = GPTConfig(vocab_size=len(chars), block_size=args.block_size, n_layer=args.n_layer,
                    n_head=args.n_head, n_embd=args.n_embd)

    try:
        dist.init()
    except SystemExit:
        raise
    except Exception as e:
        log(f"error: could not connect to the other workers: {e}")
        return EXIT_PEER

    torch.manual_seed(seed)  # same initial weights on every rank
    model = GPT(cfg)
    opt = torch.optim.AdamW(model.parameters(), lr=args.lr)
    gen = torch.Generator().manual_seed(seed + 1000 * dist.rank)

    # ------------------------------------------------------------ resume ----
    start = 0
    prev = {}
    resumed_from = ""
    if args.resume == "auto" and store and dist.rank == 0:
        name = latest_ckpt(store)
        if name:
            resumed_from = name
    resumed_from = dist.broadcast(resumed_from)
    if resumed_from:
        # every rank reads rank 0's checkpoint, so all of them continue from the same step
        blob = store.get(resumed_from)
        if blob is None:
            log(f"error: rank {dist.rank} cannot read checkpoint {resumed_from} from {args.ckpt}: "
                "every worker must see the same checkpoint storage")
            return 1
        ck = torch.load(io.BytesIO(blob), weights_only=False)
        if ck["chars"] != chars or ck["config"] != cfg.to_dict():
            log(f"error: {resumed_from} was written for a different model or dataset; "
                "use a new checkpoint location or the same settings")
            return 1
        model.load_state_dict(ck["model"])
        opt.load_state_dict(ck["optim"])
        if dist.rank == 0:
            gen.set_state(ck["rng"])
        else:
            gen.manual_seed(seed + 1000 * dist.rank + ck["step"])
        start = ck["step"]
    if dist.rank == 0 and out:
        old = out.get("metrics.json")
        if old:
            try:
                prev = json.loads(old)
            except ValueError:
                prev = {}

    # From here on SIGTERM means: finish the step, write a checkpoint, exit 143.
    # Before, there was nothing to save, so the process just exits.
    phase["training"] = True

    if dist.on:
        from torch.nn.parallel import DistributedDataParallel
        ddp = DistributedDataParallel(model)
    else:
        ddp = model

    ranks = dist.gather({"rank": dist.rank, "host": host, "threads": threads, "cpu_limit": limit})
    runs = prev.get("runs", []) if resumed_from else []
    runs.append({"start_step": start, "host": host, "started": now(), "world_size": dist.world,
                 "hosts": [r["host"] for r in ranks]})
    metrics = Metrics(out, dist.rank == 0, args.metrics_port)
    metrics.update(run_name=run_name, status="running", step=start, steps=args.steps, loss=None, val_loss=None,
                   lr=args.lr, batch_size=args.batch_size, block_size=args.block_size, seed=seed,
                   seed_fixed=args.seed != "", threads=threads, cpu_limit=limit, world_size=dist.world,
                   ranks=ranks, params=model.num_params(), config=cfg.to_dict(), runs=runs,
                   resumed_from=resumed_from, ckpt_step=prev.get("ckpt_step") if resumed_from else None,
                   ckpt_location=args.ckpt, fail_at_step=args.fail_at_step, **data_info)
    metrics.write()

    warn = ""
    if limit and threads > max(1, round(limit)):
        warn = f"  WARNING: {threads} threads but the CPU limit is {limit:g} cores (set OMP_NUM_THREADS)"
    log(f"run={run_name} rank={dist.rank}/{dist.world} host={host} params={model.num_params()} "
        f"threads={threads} cpu_limit={limit if limit is not None else 'none'} seed={seed}"
        f"{'' if args.seed != '' else '(random)'}{warn}")
    log(f"data={data_info['data_path']} chars={data_info['data_chars']} vocab={len(chars)} "
        f"prepared={'yes' if data_info['data_prepared'] else 'no'} "
        f"batch_size={args.batch_size} block_size={args.block_size} lr={args.lr} steps={args.steps}")
    log(f"checkpoints={args.ckpt or 'none'} every={args.ckpt_every} "
        + (f"resumed from {resumed_from} at step {start}" if resumed_from else "starting at step 0"))

    fail_once = str(args.fail_once).lower() in ("1", "true", "yes")
    fail_marker = f"failed-once-at-{args.fail_at_step}"
    if args.fail_at_step and fail_once and store and store.get(fail_marker) is not None:
        log(f"fail-once: already crashed at step {args.fail_at_step} before, not again")
        args.fail_at_step = 0

    @torch.no_grad()
    def evaluate():
        model.eval()
        g = torch.Generator().manual_seed(1234)
        losses = []
        for _ in range(8):
            ix = torch.randint(len(val_data) - args.block_size - 1, (args.batch_size,), generator=g)
            x = torch.stack([val_data[i:i + args.block_size] for i in ix])
            y = torch.stack([val_data[i + 1:i + 1 + args.block_size] for i in ix])
            losses.append(model(x, y)[1].item())
        model.train()
        return sum(losses) / len(losses)

    def checkpoint(step):
        if store and dist.rank == 0:
            name = save_ckpt(store, step, model, opt, cfg, chars, gen, {"run_name": run_name},
                             args.keep, args.ckpt_write_seconds)
            metrics.update(ckpt_step=step, ckpt_name=name)
            metrics.write()
            return name
        return None

    def finish_run(status, step):
        runs[-1].update(end_step=step, end=status, ended=now())
        metrics.update(status=status, step=step, runs=runs, max_rss_mb=round(max_rss_mb(), 1))
        metrics.write()

    model.train()
    step = start
    window_loss, window_t0, window_steps = 0.0, time.time(), 0
    t_start = time.time()
    tokens_per_step = args.batch_size * args.block_size
    try:
        while step < args.steps:
            if dist.any(stop["sig"] is not None):
                name = checkpoint(step)
                log(f"stopping at step {step}: " + (f"wrote {name}" if name else
                    "rank 0 writes the checkpoint" if dist.rank else "no checkpoint location configured"))
                metrics.update(signal_step=step)
                finish_run("preempted", step)
                # the worker that got the signal says so; the others report "the group stopped"
                return EXIT_SIGTERM if stop["sig"] is not None else EXIT_PEER
            if args.fail_at_step and step == args.fail_at_step and args.fail_rank in (-1, dist.rank):
                if fail_once and store:
                    store.put(fail_marker, now().encode())  # remembered next to the checkpoints
                log(f"injected failure (FAIL_AT_STEP): crashing at step {step} (exit {args.fail_exit_code})")
                finish_run("failed", step)
                return args.fail_exit_code
            ix = torch.randint(len(train_data) - args.block_size - 1, (args.batch_size,), generator=gen)
            x = torch.stack([train_data[i:i + args.block_size] for i in ix])
            y = torch.stack([train_data[i + 1:i + 1 + args.block_size] for i in ix])
            _, loss = ddp(x, y)
            opt.zero_grad(set_to_none=True)
            loss.backward()
            opt.step()
            step += 1
            window_loss += loss.item()
            window_steps += 1
            if step % args.log_every == 0 or step == args.steps:
                dt = time.time() - window_t0
                avg = window_loss / window_steps
                tps = tokens_per_step * window_steps / dt if dt > 0 else 0
                metrics.update(step=step, loss=round(avg, 4), tokens_per_sec=round(tps, 1),
                               step_seconds=round(dt / window_steps, 4), elapsed_s=round(time.time() - t_start, 1),
                               max_rss_mb=round(max_rss_mb(), 1))
                extra = ""
                if args.eval_every and (step % args.eval_every == 0 or step == args.steps):
                    vl = evaluate()
                    metrics.update(val_loss=round(vl, 4))
                    extra = f" val_loss {vl:.4f}"
                log(f"step {step}/{args.steps} loss {avg:.4f}{extra} tok/s {tps:.0f}")
                metrics.write()
                window_loss, window_t0, window_steps = 0.0, time.time(), 0
            if step % args.ckpt_every == 0 and step < args.steps:
                name = checkpoint(step)
                if name:
                    log(f"checkpoint {name}")
    except RuntimeError as e:
        if dist.on:
            log(f"lost contact with another worker: {str(e).splitlines()[0]}")
            if dist.rank == 0:
                finish_run("peer-lost", step)
            return EXIT_PEER
        raise

    vl = evaluate()
    final_loss = metrics.m.get("loss")
    if final_loss is None:
        final_loss = round(vl, 4)
    metrics.update(val_loss=round(vl, 4))
    checkpoint(step)
    if args.model_out and dist.rank == 0:
        meta = {"run_name": run_name, "steps": step, "final_loss": final_loss, "val_loss": round(vl, 4),
                "params": model.num_params(), "config": cfg.to_dict(), "seed": seed, "lr": args.lr,
                "batch_size": args.batch_size, "world_size": dist.world, "created": now(),
                "data_sha256": data_info["data_sha256"], "data_chars": data_info["data_chars"],
                "checkpoint": f"{args.ckpt}/ckpt-{step:06d}.pt" if args.ckpt else ""}
        where = write_model(args.model_out, model, cfg, chars, meta)
        metrics.update(model_out=where)
        log(f"model written to {where}")
    finish_run("done", step)
    log(f"done: step {step} final_loss={final_loss:.4f} val_loss={vl:.4f} "
        f"elapsed={time.time() - t_start:.1f}s max_rss={max_rss_mb():.0f}MB")
    dist.close()
    return 0


def run():
    try:
        return main()
    except RuntimeError as e:
        # torch.distributed raises RuntimeError subclasses when a peer goes away
        # outside the training loop (rendezvous, DDP setup, broadcasts)
        if int(env("WORLD_SIZE", 1)) > 1:
            log(f"lost contact with another worker: {str(e).splitlines()[0]}")
            return EXIT_PEER
        raise


if __name__ == "__main__":
    sys.exit(run())

"""Train vs validation loss of the bigram model for several smoothing values.  make py F=loss_report.py"""
import math

from metrics import best_smoothing, perplexity, smoothing_sweep, uniform_baseline

tr = open("data/train.txt", encoding="utf-8").read()
va = open("data/val.txt", encoding="utf-8").read()
chars = sorted(set(tr) | set(va))
stoi = {c: i for i, c in enumerate(chars)}
tr_ids, va_ids = [stoi[c] for c in tr], [stoi[c] for c in va]
rows = smoothing_sweep(tr_ids, va_ids, len(chars), [0.0, 0.001, 0.01, 0.1, 0.3, 1.0, 3.0])
print("uniform baseline: loss %.3f perplexity %.1f" % (uniform_baseline(len(chars)), perplexity(uniform_baseline(len(chars)))))
print("%8s %12s %12s %10s" % ("smooth", "train loss", "val loss", "val ppl"))
for k, a, b in rows:
    print("%8g %12.4f %12.4f %10.2f" % (k, a, b, perplexity(b)))
print("best by validation:", best_smoothing(rows))

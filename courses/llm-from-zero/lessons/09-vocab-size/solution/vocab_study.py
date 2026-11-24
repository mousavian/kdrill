"""Lesson 09 - reference solution."""
from bpe import BPE

SPECIALS = ("<|endoftext|>",)


def tokens_per_word(ids, text):
    n = len(text.split())
    return len(ids) / n if n else 0.0


def bytes_per_token(ids, text):
    return len(text.encode("utf-8")) / len(ids) if ids else 0.0


def rare_fraction(tokenizer, ids, min_count=5):
    k = len(tokenizer.merges)
    if k == 0:
        return 0.0
    counts = [0] * k
    for i in ids:
        if 256 <= i < 256 + k:
            counts[i - 256] += 1
    return sum(c < min_count for c in counts) / k


def embedding_params(vocab_size, d_model):
    return vocab_size * d_model


def study(train_text, val_text, sizes, min_count=5):
    top = BPE.train(train_text, max(sizes) - 256 - len(SPECIALS), SPECIALS)
    rows = []
    for s in sizes:
        k = max(0, min(s - 256 - len(SPECIALS), len(top.merges)))
        tok = BPE(top.merges[:k], SPECIALS)
        ids = tok.encode(val_text)
        rows.append({"vocab_size": tok.vocab_size, "merges": k, "tokens_per_word": tokens_per_word(ids, val_text),
                     "bytes_per_token": bytes_per_token(ids, val_text), "rare_fraction": rare_fraction(tok, ids, min_count)})
    return rows


def choose_size(rows, max_rare=0.25):
    ok = [r["vocab_size"] for r in rows if r["rare_fraction"] <= max_rare]
    return max(ok) if ok else min(r["vocab_size"] for r in rows)

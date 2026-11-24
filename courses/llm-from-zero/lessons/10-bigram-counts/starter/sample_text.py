"""Train a bigram model on your training split and print some text.  make py F=sample_text.py
Uses tok_char.CharTokenizer from lesson 07 if you have it."""
import numpy as np

from bigram import BigramModel

text = open("data/train.txt", encoding="utf-8").read()
try:
    from tok_char import CharTokenizer
    tok = CharTokenizer().fit(text)
    ids, decode, V = tok.encode(text), tok.decode, tok.vocab_size
except Exception:
    chars = sorted(set(text))
    stoi = {c: i for i, c in enumerate(chars)}
    ids, V = [stoi[c] for c in text], len(chars)
    decode = lambda xs: "".join(chars[i] for i in xs)
for k in (0.0, 1.0):
    m = BigramModel(V, smoothing=k).fit(ids)
    print("--- smoothing", k)
    print(decode(m.sample(300, start=ids[0], seed=1)))

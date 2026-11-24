# Solution notes

- The pipeline is a straight line of calls to your own modules, and everything that crosses a boundary is explicit: the train and validation tensors go to `train_run`, the test tensor only to `perplexity_on_text` after training. That is what the leakage test verifies by spying on `train_run`.
- Seeds are set in three places (`build_dataset`, `torch.manual_seed` before building the model, the training generator inside `train_run`), plus a seeded generator per sample. That is why two runs are identical.
- `gpt_config` is stored as constructor keyword arguments, so `GPT(**ck["gpt_config"])` is the entire rebuild step. Storing the tokenizer as `to_dict()` data (not a pickled object) keeps the checkpoint loadable after you refactor your code.
- The reference model card quotes the data card's sources and splits and keeps the limitations paragraph short and specific. A real card would add intended users, known failure cases and a contact.
- With the real corpus and `capstone_run.py`'s defaults you get a model of about 0.9 million parameters; it writes plausible Victorian-sounding sentences with invented names, which is exactly what the limitations section should say.

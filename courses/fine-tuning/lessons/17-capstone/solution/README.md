# Solution notes

- **Order of operations is the leakage control**: clean, then decontaminate against the evaluation rows, then encode. The test hands `train_sft` through a
  spy and checks the items; a later refactor that moves the decontamination after encoding would fail it.
- **Baseline before tuning, by the same function**: `evaluate_qa` for base and tuned means the two columns of the report are comparable. The original-text
  loss is the forgetting check from lesson 03, kept in the report even when the task is the only thing you care about.
- **Report the spread**: `exact_per_seed` and `exact_std` come from the same seeds; the card prints them so nobody reads one lucky seed as the result.
- **The artifact reproduces the number**: the adapter file plus the base is enough to get the reported exact match; that is the property that makes a results
  file trustworthy (and the reason editing `results.json` by hand cannot pass the test).
- **The reference configurations** are LoRA on attention and MLP (rank 8, 150 to 250 steps) and full fine-tuning at a lower rate (100 to 150 steps); on the
  course's task over three seeds LoRA reaches 0.59 exact match with a sixth of the trainable parameters and full fine-tuning 0.37, with spreads of 0.09 and 0.12
  between seeds, which is why one seed would not have been enough to say so. Both forget the original text badly (loss 2.96 to 5.0 and 4.1): the card reports it.

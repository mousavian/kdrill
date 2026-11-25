# Solution notes

- **Prefixes end with a dot** so `blocks.1.` cannot match `blocks.10.`; validating them against the real names turns a
  silent no-op into an error.
- **Frozen means no gradient**: `requires_grad=False` parameters have `grad is None` after `backward()` and AdamW skips
  them (so even weight decay does not touch them). The test checks bit equality of every frozen tensor.
- **Count once**: tied parameters appear once in `model.parameters()`; counting `lm_head.weight` too would overstate the
  trainable share.
- **What the experiment shows**: the last block plus the final norm (29 percent of the parameters) gets about three
  quarters of the style gain of full fine-tuning (3.10 against 2.96, from 3.46) with less than half the damage to the original
  text (2.99 against 3.13, from 2.92); training only the final norm barely changes the style loss and leaves the original text
  where it was. How much of the model you free is a dial between "cannot learn"
  and "forgets".

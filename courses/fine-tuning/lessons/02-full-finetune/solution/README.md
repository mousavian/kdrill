# Solution notes

`solution/finetune.py` is a complete implementation.

- **The rate matters more than the step count.** In the experiment 1e-3 gives the best style loss, 3e-4 is nearly as good
  with much less damage to the original text, and 3e-3 is worse on both. Pre-training rates (here 4e-3) are far too large
  for a trained model.
- **Warm-up** is cheap insurance: AdamW's first steps divide by tiny second-moment estimates and take large, noisy
  steps; ramping the rate over a few steps avoids a jolt to a model that was in a good place.
- **Seeded batches**: passing one `torch.Generator` through every `get_batch` call makes the whole run reproducible and
  lets you compare two settings on the same data order.
- **Only parameters with `requires_grad`** go to the optimizer; with everything trainable this is all parameters, and it
  makes the same function work for freezing and LoRA later.
- The tied output layer shares its matrix with the token embedding, so "updating every weight" updates both uses of it.

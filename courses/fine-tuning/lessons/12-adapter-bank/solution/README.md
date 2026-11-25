# Solution notes

- **Sync before you switch.** Training happens in place on the live parameters; `activate` must copy them back into the
  adapter that was active, or the work is lost the moment you switch.
- **Copy into, do not replace.** `p.copy_(...)` keeps the same `Parameter` objects, which is what an optimizer or the
  wrapping `LoRALinear` holds on to.
- **"No adapter" means `B = 0`**: the update `B A x` vanishes and the layer returns `W x`; the test requires bit-identical logits
  to the plain base.
- **Isolation needs copies**: `state()` returns clones, and `add` builds new tensors rather than reusing the live ones, so an
  adapter cannot alias another.
- **Memory**: the report is plain arithmetic, 4 bytes per float32 value. Three adapters here cost 3 x 62,208 values against three
  extra full models of 384,864 values each.
- **The diagonal**: each adapter helps only its own task. Whether to train one adapter on both tasks or keep two is the kind of
  question the capstone's evaluation can answer.

"""Lesson 15 - Direct Preference Optimization, from the formula. Builds on prefs.py (lesson 14). Not allowed: trl, peft."""
import torch
import torch.nn.functional as F

from prefs import completion_logprobs, encode_pair


def implicit_rewards(pc, pr, rc, rr, beta=0.1):
    """DPO's implicit rewards: (beta * (pc - rc), beta * (pr - rr)), where pc, pr are the policy's summed log-probabilities
    of the chosen and rejected completions and rc, rr the reference model's. Tensors of shape (B,)."""
    # TODO
    raise NotImplementedError


def dpo_loss(pc, pr, rc, rr, beta=0.1):
    """The DPO loss, a scalar: the mean over the batch of
          - log sigmoid( beta * ((pc - rc) - (pr - rr)) ).
    Use F.logsigmoid (numerically stable), not log(sigmoid(x)): margins of -1000 must give a finite loss. The reference
    values rc, rr are constants (no gradient flows to them); pc and pr carry the gradient to the policy."""
    # TODO
    raise NotImplementedError


@torch.no_grad()
def reference_logprobs(ref_model, tok, pairs, batch_size=32):
    """(rc, rr): tensors (len(pairs),) of the reference model's summed log-probability of every chosen and every rejected
    completion (encode_pair, completion_logprobs, batches of batch_size). Eval mode during the call, the previous mode
    restored; the model is not modified."""
    # TODO
    raise NotImplementedError


def dpo_train(policy, ref_lp, tok, pairs, steps, lr, beta=0.1, batch_size=16, seed=0):
    """Train `policy` in place with DPO and return the list of the losses (floats, one per step).

    ref_lp is the (rc, rr) of reference_logprobs for exactly these pairs, computed ONCE before training (the reference
    is frozen: it never changes and is not needed again). Each step draws batch_size indices with
    torch.randint(0, len(pairs), (batch_size,), generator=g), g = torch.Generator().manual_seed(seed); computes the
    policy's pc and pr for those pairs with completion_logprobs, the loss with dpo_loss and the matching rc[ix], rr[ix];
    then AdamW (weight_decay 0, constant lr, over the parameters that require gradients), zero_grad, backward, step.
    Train mode during the run, previous mode restored."""
    # TODO
    raise NotImplementedError


def win_rate(policy, ref_model, tok, pairs):
    """The share of pairs where the policy has moved toward the chosen answer more than toward the rejected one, relative
    to the reference: (pc - rc) - (pr - rr) > 0 (strictly). beta does not change the sign, so it is not needed. Both models
    in eval mode, no gradients. A float in [0, 1]; 0.0 when policy and reference are the same model."""
    # TODO
    raise NotImplementedError

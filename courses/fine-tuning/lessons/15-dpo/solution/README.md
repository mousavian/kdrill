# Solution notes

- **The first loss is `ln 2`**: with the policy equal to the reference both differences are zero. If it is not, something differs between the two
  computations (mode, padding, a trained reference); it is the cheapest bug detector there is.
- **The reference is a constant**: its log-probs are computed once and detached; training only moves the policy. If the reference moved along, the margin
  would measure nothing.
- **`logsigmoid` is the stable form**: it is computed without ever forming a sigmoid that underflows to zero, which is what keeps a margin of -1000
  from becoming infinity.
- **Beta is a leash**: a small beta lets the policy drift far and fast (loss near zero, answers may degrade, as the beta 0.05 and 0.1 rows show with more
  steps); a large beta saturates early and moves the model little.
- **Win rate is relative to the reference** (change in log-prob), not raw log-probability, which would reward short answers; the generated answers
  (chatty share, right word) are the check that the win rate means what you think.

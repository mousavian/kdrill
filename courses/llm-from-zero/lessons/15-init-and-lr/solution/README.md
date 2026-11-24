# Solution notes

- On the bundled corpus the diagnostics look like this: `ln V` is 4.49; Kaiming scaling with a small output layer starts at about 4.5 (no hockey stick), a W2 scale of 1.0 starts several nats higher; with `W1` scale 3.0 most hidden units are saturated, with 0.05 the hidden layer is nearly silent.
- The range test on this model bottoms out around lr 3 to 4 and explodes beyond; one tenth of that (about 0.4) trains in 500 steps to a loss near 2.4, where 0.0004 has barely left 4.4 and 40 diverges.
- `lr_range_test` copies the parameters first: a diagnostic must never change the thing it measures. It records the loss *before* each update so the first row is the untrained loss at the smallest rate.
- These numbers are specific to this tiny model. The method (measure at init, test the rate, watch the ratios) transfers unchanged to a GPT.

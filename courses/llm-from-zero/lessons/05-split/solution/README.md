# Solution notes

- The split works on *sorted* names that are then shuffled with a seeded `random.Random`: the result depends only on the seed and the set of documents, never on the order a dict happened to be built in.
- The greedy "furthest below its target" rule gives good character shares when there are many documents; with few documents a special rule guarantees that validation and test are not empty.
- Run `leakage_demo.py` on your data: the OOV rate of the line split is far lower than that of the document split. That difference is exactly the leakage; a model evaluated on the line split would report an optimistic loss.
- Write the split down (`splits.json`) so that anyone can reproduce it: lesson 06 puts it in the data card.

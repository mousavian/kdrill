"""Lesson 16 - evaluation you can trust: contamination checks and error bars. Pure Python, no scipy or numpy needed."""
import math
import re

# two-sided 95% critical values of Student's t distribution, by degrees of freedom (n - 1)
T95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
       12: 2.179, 15: 2.131, 20: 2.086, 30: 2.042}


def words(text):
    """Lower-case words of a text: re.findall(r"[a-z0-9']+", text.lower())."""
    # TODO
    raise NotImplementedError


def ngrams(text, n):
    """The set of word n-grams (tuples of n consecutive words) of the text. A text with fewer than n words has no
    n-grams: for it return {tuple(words)} when it has any words (the whole text counts as one gram), else the empty set."""
    # TODO
    raise NotImplementedError


def build_index(texts, n):
    """The union of ngrams(t, n) over the texts."""
    # TODO
    raise NotImplementedError


def contaminated(eval_texts, train_texts, n=8):
    """A list of booleans, one per eval text: True when the eval text shares at least one n-gram with the training texts
    (short texts count as a whole, see ngrams). Index the training texts once."""
    # TODO
    raise NotImplementedError


def overlap_rate(eval_texts, train_texts, n=8):
    """The share of all the n-grams of the eval texts that also occur in the training texts (0.0 when the eval texts have
    no n-grams at all). Counts every n-gram occurrence in the eval texts, not only distinct ones."""
    # TODO
    raise NotImplementedError


def decontaminate(train_rows, eval_rows, n=8, field="question"):
    """(kept, removed): the training rows (dicts, in order) whose row[field] shares no n-gram with ANY eval row's row[field],
    and the rows removed. The eval rows are never changed."""
    # TODO
    raise NotImplementedError


def mean_std(values):
    """(mean, sample standard deviation with n - 1 in the denominator); the deviation of one value is 0.0."""
    # TODO
    raise NotImplementedError


def ci95(values):
    """(mean, half-width): half-width = t * std / sqrt(n) with t = T95[n - 1] (use the entry for the largest key not above n - 1
    when n - 1 is not in the table; for n - 1 above 30 use 1.96). One value: half-width = float('inf')."""
    # TODO
    raise NotImplementedError


def paired_summary(scores_a, scores_b):
    """Compare two settings run with the SAME seeds (scores_a[i] and scores_b[i] come from seed i; higher is better).
    Return {"mean_a", "mean_b", "std_a", "std_b", "diff": mean of (b - a), "ci": half-width of the 95% interval of the paired
    differences (ci95 of the list of differences), "b_better": diff - ci > 0}. ValueError for lists of different length."""
    # TODO
    raise NotImplementedError


def binomial_se(p, n):
    """Standard error of a proportion p measured on n items: sqrt(p * (1 - p) / n)."""
    # TODO
    raise NotImplementedError

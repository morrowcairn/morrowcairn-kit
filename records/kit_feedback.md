# Kit Feedback

**One line, at the moment of friction. Do not save it up.**

This file runs the transfer loop in reverse. The kit ships doctrine *into* a project; this is how the
project reports back — and **instance feedback is the only thing that legitimately advances a kit
version.** A pattern refined by imagining how it might be used is a pattern refined by guesswork; a
pattern refined because it did not fit a real job has evidence behind it.

Log it when it happens. Friction is remembered as "that was a bit awkward" within a day and as
nothing at all within a week, and by then the specific reason — the thing that would actually change
the template — is gone.

## What to log

- A **pattern that didn't fit** — and the shape of the mismatch, not just that it happened
- A **convention that cost more than it paid** — the strongest signal available, because it is
  direct evidence the portability filter's cost-asymmetry test was wrong about this rule
- A **missing template** — something you had to invent that the kit should have provided
- A **rule that misfired** — applied where it was tax, or where it was simply wrong

## What NOT to log

Project-specific decisions. Those belong in this project's own `decisions_log.md`. The test: *would
this observation mean anything to a different project using the same kit?* If not, it is not kit
feedback — it is work.

## Format

```
YYYY-MM-DD  [pattern|convention|missing|misfire]  one line: what happened and what it cost
```

Interpretation, when these are read back:

- **Two instances of the same friction is a signal.** One might be this project being unusual.
- **A rule that misfires twice is a removal candidate, not an exception candidate.** Adding a
  carve-out is how doctrine turns into scar tissue; the kit's prune posture prefers deletion.
- **"I ignored this and nothing bad happened"** is among the most valuable entries here, and the
  least likely to get written down. Write it down.

---

<!-- Entries below. Newest at the bottom; append, don't reorganize. -->

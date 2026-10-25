# Followup Queue

Operational backlog. **Not a wishlist** — items here should be actionable within the next few work
sessions. Anything further out belongs in a roadmap, not a queue.

## Conventions

**Triage by consequence, not by urgency.** Sort items by *what happens if this is never done*, which
is a question with an answer, rather than by how urgent they feel, which is a question that
re-answers itself every week:

| Tier | Test | Handling |
|---|---|---|
| **A — wrong now** | Something is visibly incorrect, or a loss is unrecoverable if it happens | Work these. Weight them; they are not equal. |
| **B — defends a real consumer, invisibly** | Nothing looks wrong today; something specific breaks silently if it's skipped | Draw from here as A drains. |
| **C — defends the taxonomy** | It's on the list because a review put it there | Draw an item **only** when it is the sole standing defense for a specific A/B failure — never because it is on the list. |

C grows on its own and is a **baseline you consult**, not a queue you burn. A backlog of 200 items
where 25 have real ends is a backlog of 25 with a morale problem attached.

**Dated items carry a `due:` and something that fires.** A date nobody is reminded of is a wish. If
an item has a real deadline, wire an alert; if it doesn't, don't give it a fake date.

**Archive, don't accrete.** Closed, killed, and parked items move to an archive file with their IDs
preserved and a one-line disposition. A queue that only grows stops being read, and a queue nobody
reads is worse than none — it *looks* like coverage.

**Killing an item is a real outcome.** Record the reason. "We decided not to" is a legitimate close
and is more useful than an entry that quietly rots for two years.

**IDs are permanent.** Never reuse a number, even after archiving — cross-references outlive entries.

---

## Open

<!-- 1. **Title.** What breaks if undone. Tier. `due:` if real. -->

## Archive

<!-- Closed / killed / parked, IDs preserved, one line each. -->

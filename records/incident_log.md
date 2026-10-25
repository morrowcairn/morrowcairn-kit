# Incident Log

One entry per incident. **Newest first.**

The point of this log is not blame or postmortem ceremony — it is **institutional memory**. Someone
hitting a similar symptom months from now should be able to search here and find the prior
occurrence and what fixed it, without reconstructing it from scratch.

It is also the half of the record-keeping machinery most often skipped, and the one a later
doctrine extraction most needs. A decisions log tells you what you chose; only an incident log tells
you what actually broke. See the README — *the project grows around the hole.*

## When to add an entry

When something breaks badly enough to investigate: roughly **>30 minutes spent**, or any
user-visible impact, or a **near-miss** (it didn't break, but only by luck — these are the highest
value entries and the easiest to skip).

Do not aim for exhaustive. Aim for *findable by the next person with the same symptom*.

## Entry schema

Every field earns its place. The two that get dropped under time pressure — **causal story** and
**verification** — are the two that make an entry useful later.

| Field | Why it's required |
|---|---|
| **Date** | When detected. Add "live since" if the defect predates detection — the gap is itself a finding about your monitoring. |
| **Symptom** | What was *visible*. This is the search target for "have we hit this before" — write it in the words someone would search, not the words you used after understanding it. |
| **Causal story** | Not just the bug: the *chain*. What made it possible, what let it survive, what surfaced it. A one-line root cause loses the part that generalizes. |
| **Fix** | What changed to make it stop. |
| **Preventive change** | What now catches this class — a guard, a counted skip path, a test, a schema constraint. If nothing, say so explicitly; "no preventive change" is a real answer and an honest one. |
| **Class** | Map to a known failure family where one fits (silent skip · false-OK · false absence · swallowed exception · partial artifact · caller-reports-success). Classes are how one incident teaches the next. |
| **Verification** | **How you know the fix holds.** Ideally: made it fail first, then pass. A fix believed-to-work and a fix shown-to-work read identically in a log six months on. |
| **References** | Commits, decisions-log entries, related incidents. |
| **Contradicts if true** | *Optional, filled at filing time.* The one observation that would mean this diagnosis is wrong: one concrete thing someone could go and check, not a list of caveats. Leave it out rather than padding it. |

---

## TEMPLATE — copy below the line for each new entry

## YYYY-MM-DD — one-line symptom, in searchable words

- **Symptom:**
- **Causal story:**
- **Fix:**
- **Preventive change:**
- **Class:**
- **Verification:**
- **References:**
- **Contradicts if true:**   *(optional)*

---

<!-- INSERTION POINT — newest entry goes directly below this line. -->

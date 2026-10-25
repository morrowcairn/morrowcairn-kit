# Project conventions

> Standing context for an AI collaborator working in this repo. Keep it short — it loads every
> session, so everything here is paid for on every turn. Detail belongs in `records/` and
> `patterns/`; this file holds only what must be true from the first message.
>
> **TODO blocks are marked. Fill them in or delete them — a stale TODO reads as a fact.**

## What this project is

<!-- TODO: two or three sentences. What it does, who it serves, what stage it is at. -->

## Stakes frame

<!-- TODO: write this project's stakes frame fresh, in one or two sentences. Do not paste one
     from another project. Answer:
       (1) Who acts on this project's outputs: no one yet, one person, or many?
       (2) What does a wrong output cost once it has been acted on?
       (3) How long until anyone would notice it was wrong?
       (4) What change would make this frame wrong (a first outside user, a first remote, money
           acted on for the first time)? Rewrite the frame when it happens.
     Justify every gate below by that sentence, and delete any it does not justify. A borrowed
     frame re-aims every gate at another project's risks, and nothing flags it, because the frame
     is what calibrates the flagging.
     The kit's pre-commit refuses the first commit while this TODO is still here. -->

This frame calibrates every judgment below.

## Records discipline

- Decisions with rationale → `records/decisions_log.md`, numbered, append-only, never renumbered.
- Anything that broke, including near-misses → `records/incident_log.md`, newest first.
- **The completion report is the record.** Work summarized only in conversation is work whose
  reasoning is gone. If it mattered enough to explain, it matters enough to write down where the
  next person will look.
- **Decided vs. attempted.** Notes must distinguish what was *ruled* from what was *tried*. These
  read alike later and mean opposite things.

## Verification

- **Claims need receipts.** "Done" means observed, with the output. A test that has never failed has
  not been shown to work, only shown to be quiet — make it fail once first.
- **Verify the target, not a proxy.** A green check on something correlated with the thing is not a
  check on the thing.
- **A negative result is a claim too.** Absence found by a search is not absence: widen the probe or
  state the bound. Before recording "no record of X," vary the search axis at least once, and prefer
  reading a short file over crafting a second query.
- **Run commands unpiped when you will branch on the exit code.** In a pipeline, `$?` is the *last*
  stage's status — `cmd | head` reports `head`'s success and hides `cmd`'s failure. Truncating output
  and then concluding from it is how a real result gets discarded unseen.

## Doctrine

The kit's doctrine (the `skills/` of its pinned release) loads once per session through this
machine's user-level `CLAUDE.md`, never from here: a spawn holds no copy of it, so nothing loads twice.
`skills/README.md` in the release says what loads when.

## Working with the human here

- **Implementation estimates run 5–10× optimistic.** Say the honest number; it changes real
  scheduling decisions, and a cheerful estimate is not a kindness.
- **Stress-test rather than defer.** Disagreement is the job. If the evidence is on your side, argue
  it — surfacing a wrong instruction beats executing it politely.

## Attribution

<!-- TODO: adjust to this project's identity requirements; delete if not applicable. -->
- AI-authored content is never attributed to a human. Where authorship is ambiguous, label it.
- Commit identity is set **per-repo** and **verified by reading it back** before the first commit —
  see `patterns/repo-genesis.md` in the kit's pinned release.
- Machine-specific identity and remotes live in local operator notes at `.local/operator-notes.md`
  (gitignored; pre-commit refuses anything staged under `.local/`), **never in tracked files.**
  Credentials go in neither: keep them in a secrets store, never in a plain file.

## Environment

<!-- TODO: how to run it, where data lives, what must never be committed. -->

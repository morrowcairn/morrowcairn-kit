# Decisions Log

Numbered, append-only. **Why, not just what.**

The code records *what* was decided. This file exists for the part the code cannot hold: what else
was considered, what the decision was trading off, who had the authority to make it, and what would
make it wrong later.

## Conventions

- **Numbered sections, never renumbered.** Other documents cite `§N`; a renumber silently breaks
  every citation. Gaps from abandoned entries are fine — leave them.
- **Append-only. Supersede, don't delete.** A superseded entry stays and gains a pointer to the one
  replacing it. A decisions log that only shows current state cannot answer "why did we change our
  mind," which is the question it exists for. Reversals are the most valuable entries here.
- **Every entry carries a "Would revisit if:" line.** This is the retirement condition. Without it,
  decisions accumulate and none ever retire, and a project ends up governed by constraints whose
  original conditions expired years ago.
- **Corrections are visible, not silent.** Fixing a factual error in an old entry is fine; do it
  with a dated note saying what changed, not a quiet edit.
- **Entry layout.** A heading `## §N. Title`, then a status line in italics carrying the date
  (*Decided YYYY-MM-DD. Status: active.*), then these paragraphs in this order, each led by its bold
  label: **Decision.** (what was ruled, in one or two sentences) · **Context.** (the situation and
  what was measured) · **Alternatives considered.** (a list; each one with why it lost) ·
  **Consequences.** (what follows, including costs accepted) · **Authority.** (who could make this
  call) · **Would revisit if:** · and the optional **Contradicts if true:**. The layout lives here,
  not in an example entry: a project that deletes the worked example keeps it.
- **Optional: "Contradicts if true:"**, filled at filing time. Name the one observation that, if it
  turned out to hold, would make the decision wrong: one concrete thing someone could go and check,
  not a risk list. Leave it out rather than padding it. It is answered once, in writing, when the
  entry is filed, and an entry whose condition later holds is exactly the one to reopen.

---

## §1. Worked example — this file's own format

*Decided 2026-07-21. Status: active.*

**Decision.** Decisions in this project are recorded in one numbered, append-only file rather than
distributed across pull-request descriptions and commit messages.

**Context.** Rationale that lives only in a PR description is findable if you already know which PR
to open — which is exactly the knowledge a newcomer, or the same person eighteen months later, does
not have. The failure is not that the reasoning was never written down; it is that it was written
somewhere unsearchable by the question that would prompt the search.

**Alternatives considered.**
- *Architecture Decision Records (one file per decision).* Better for large teams and tooling.
  Rejected here for a small project: directory sprawl, and cross-references become filename
  spelunking rather than `§N`.
- *A wiki.* Rejected — drifts from the repo, versions separately from the code it explains, and
  cannot be reviewed in the same diff as the change it justifies.
- *Nothing; rely on commit messages.* Rejected. Commit messages explain a change; they cannot
  explain a *choice between options*, because the options that lost never appear in a diff.

**Consequences.** One file grows monotonically and eventually needs section-level navigation.
Accepted deliberately: a long searchable file beats a tidy structure nobody searches. Citations
become stable (`§1`), which makes the log usable as provenance from other documents.

**Authority.** Project owner.

**Would revisit if:** the project takes on multiple independent maintainers who need to write
decisions concurrently — at which point per-entry files stop being sprawl and start being conflict
avoidance.

---

<!-- New entries below, ascending. Never renumber. -->

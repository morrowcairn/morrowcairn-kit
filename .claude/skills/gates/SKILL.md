---
name: gates
description: Use before changing anything whose job is to allow, block or alert (a hook, a CI check, a validator, a backup filter, an alert route, a secrets guard, a permission setting), and when a permission check has just stopped a command. Not for ordinary code.
---

# Gates

**Loaded:** when a task matches the description above; Claude Code reads it from this folder. It
applies whatever bar the project sets for stopping. Ordinary code isn't a gate.

## 4. Test a gate before you change it

1. Before changing the gate, write a test that feeds it an input it must refuse.
2. Run the test against the current version and against the changed one. The run against the current
   version is what shows whether the hole you're fixing exists.
3. Make sure the red is real. It must fail because of the input, not because of the test. A test that
   fails with and without the change proves nothing.
4. Name the test in your report, with both results.
5. One exception, a live incident only. If the gate is misfiring now (blocking every push, say), a
   stopgap marked as one may go first. The tested fix is queued, and it lands next.
6. A gate that applies to every session or every repository is also replayed against the past week's
   real commands or commits before it goes live, and any refusal is reported.
7. Install such a gate by swapping the whole file in, never by editing it in place while it is live.

**Would revisit if:** across a long run of gate changes, the run against the old version stops
finding holes.

## 13. A content gate finds its own terms

A content gate checks content against a list of terms or patterns: an identity, secret or leak gate.

1. It finds its terms itself, from a fixed path or its own named secret, never from the caller's
   environment. In CI the terms come from the gate's own named secret, checked against a pinned count
   or hash, so the gate can tell it got its whole list.
2. It honours a test override only in a mode that can't pass a real run.
3. Outside a git hook, it starts git with no inherited `GIT_` settings and sets back only what it
   needs. It always runs git with `GIT_NO_REPLACE_OBJECTS=1`, and refuses a repository that has
   grafts.
4. It refuses when its terms can't load, saying what is missing and how to fix it.
5. It is skipped (`--no-verify` or the like) only on the owner's ruling.

A change any item calls for is a gate change, made test first (procedure 4).

**Would revisit if:** git stops passing inherited settings to the processes it starts, or a long run
of new content gates meets every item without a test having to catch it.

## 5. Never reshape a command to get past a permission rule

1. When a permission rule asks or blocks, don't change the command's form so the rule no longer
   matches. That means no split or quoted name, no variable, no other path or wrapper, and no text
   moved into a file.
2. If the prompt is noise, report it, so the rule is fixed where it is defined.
3. Editing a file with the editor tool is ordinary work. It is not a way around a rule about running
   something.

**Would revisit if:** permission rules match what a command does, not how it is written.

*Provenance: `skills/PROVENANCE.md`, the lines for procedures 4, 5 and 13.*

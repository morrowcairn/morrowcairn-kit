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

**Would revisit if:** across a long run of gate changes, the run against the old version stops
finding holes.

## 5. Never reshape a command to get past a permission rule

1. When a permission rule asks or blocks, don't change the command's form so the rule no longer
   matches. That means no split or quoted name, no variable, no other path or wrapper, and no text
   moved into a file.
2. If the prompt is noise, report it, so the rule is fixed where it is defined.
3. Editing a file with the editor tool is ordinary work. It is not a way around a rule about running
   something.

**Would revisit if:** permission rules match what a command does, not how it is written.

*Provenance: `skills/PROVENANCE.md`, lines 4 and 5.*

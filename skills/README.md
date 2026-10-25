# skills/ — triggered and standing doctrine

This directory holds the kit's doctrine: one file per failure family. Each file opens by saying when
it loads, and every procedure in it carries a "Would revisit if:" retirement condition and a line in
the provenance appendix, [`PROVENANCE.md`](PROVENANCE.md).

## What is here, and how each loads

| File | Family | Loads |
|---|---|---|
| `skills/working-from-a-brief.md` | turning a brief into work: size, reopen, measured vs inferred, a project's own bar; compaction, rotation and the handoff file | always: an import line, once per session (below) |
| `skills/shell-commands.md` | silent-failure classes in shell commands | always: an import line, once per session (below) |
| `.claude/skills/gates/SKILL.md` | changing a gate; permission rules | when a task matches its description |
| `.claude/skills/record-stamps/SKILL.md` | time stamps in records | when a task matches its description |
| `.claude/skills/session-close/SKILL.md` | closing a session: hygiene, what needs a decision, what went wrong | when a task matches its description |

Two load always because they apply in nearly every session, and a load they missed would be silent.
The triggered ones live where Claude Code finds skills, `.claude/skills/<name>/SKILL.md`, and load
when a task matches the `description` in their front matter, which is written as trigger conditions
rather than a topic label. Both mechanisms were checked in a throwaway spawn before these files were
written: the import lines put the always-on files into the session's opening context with every tool
off, and each triggered file was loaded, unprompted, by a task that matched it and by no other.
`session-close` came later and was measured the same way before v0.9.0: it loaded first, unprompted,
on the operator's wrap-up phrasings, in fresh sessions and late in a long, compacted one, and on none
of three unrelated tasks.

Where the import lines live (v0.8.0): not in a project. A project holds no copy of these files, and its
`CLAUDE.md` template (`templates/CLAUDE.md`) imports nothing, so nothing loads twice. On a machine whose
user-level `CLAUDE.md` imports them from the pinned install, every session there loads them once, and
the triggered ones load from user-level skill entries pointing at the same install. Until that
user-level step, the kit's own `CLAUDE.md` imports them for the kit's sessions; a project made before
v0.8.0 keeps its copies until then (`patterns/local-upgrade.md`, step 3). A pin move brings their
corrections.

## The filter

The doctrine is the output of an extraction pass over a real corpus of incidents and decisions, run
through a deliberately brutal portability filter. Every rule must:

- name a failure *mechanism* that survives having its project nouns stripped;
- trace to a recorded incident in a project spawned from the kit, or in one of the projects
  run by the kit's operator;
- be cheap where it does not apply;
- read as a procedure rather than a prohibition.

Rules that cannot pass do not ship. Writing plausible-sounding skills ahead of the evidence would
fill the directory with exactly the unearned doctrine the filter exists to reject.

Planned families still to come: verification · deploy safety · monitoring and coverage · data
integrity · records and provenance (beyond time stamps) · public surfaces (beyond gates).

`patterns/` still carries most of the load, deliberately. A pattern you copy is doctrine you cannot
forget to read.

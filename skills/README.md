# skills/ — triggered and standing doctrine

This directory indexes the kit's doctrine, one file per failure family, and holds its provenance appendix,
[`PROVENANCE.md`](PROVENANCE.md). The doctrine lives in `rules/` and `.claude/skills/`; each file opens by saying
when it loads, and every procedure in a skill carries a "Would revisit if:" retirement condition and a line in the
appendix.

## What is here, and how each loads

| File | Family | Loads |
|---|---|---|
| `rules/morrowcairn.md` | the always-on rules: relays, reports, size, reopening, measuring, the shell, compaction and the handoff file, a project's own bar | always: `bin/kit-pin user` links it into the user-level rules folder |
| `.claude/skills/gates/SKILL.md` | changing a gate; permission rules | when a task matches its description |
| `.claude/skills/record-stamps/SKILL.md` | time stamps in records | when a task matches its description |
| `.claude/skills/session-close/SKILL.md` | closing a session: hygiene, what needs a decision, what went wrong | when a task matches its description |

The rules file loads always because it applies in nearly every session, and a load it missed would be silent.
The triggered ones live where Claude Code finds skills, `.claude/skills/<name>/SKILL.md`, and load
when a task matches the `description` in their front matter, which is written as trigger conditions
rather than a topic label.

Where the user-level entries live: not in a project. A project holds no copy of these files, and its
`CLAUDE.md` template (`templates/CLAUDE.md`) imports nothing, so nothing loads twice. `bin/kit-pin user vX.Y.Z`,
run once per machine, links the rules file into Claude Code's rules folder and each skill into its skills folder,
from the pinned install, and writes the kit's user pin; every session there then loads them once. A project made
before v0.8.0 keeps its copies until that step has run (`patterns/local-upgrade.md`, step 3). Moving the user pin
brings their corrections.

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

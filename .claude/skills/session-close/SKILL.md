---
name: session-close
description: Use when the operator asks to wrap up, close out, end or rotate a session, however it is worded and however long the session has run. Load it before starting the close, a handoff or a rotation yourself.
---

# Session close

**Loaded:** when a task matches the description above; Claude Code reads it from this folder.

## 12. Close a session on what needs a decision

When it applies: the operator asks to wrap up or close a session.

1. Hygiene first, and say what you did.
   - The decisions log, the follow-up queue and the handoff file are current, so a new session could take over
     from the handoff alone. The handoff file is the rules file's (`rules/morrowcairn.md`, section 10).
   - Say what's committed, pushed, tagged and deployed. Name anything finished but not shipped: committed but not
     released, or pushed but not deployed.
   - Name any public text that now describes something that has changed: a README, setup requirements, a website.
   - Scratch files, temporary copies of sensitive lists and test branches are removed.
   - Name any open item from this session that could be finished now.
2. Up to five items that most need a decision, ranked across these prompts. The prompts aren't sections, and some
   may give nothing while others give two:
   - something you wanted to work on more, or fix;
   - something that works but carries weight in a way that bothers you;
   - something the operator should have asked you to look into and didn't;
   - something nobody is checking.

   For each item, give what it is and the evidence, labeled measured or inferred. Then propose one of three
   dispositions: done now; dated, with an owner; or delete, with a one-line reason. The operator confirms or
   overrides each one. Record each in the queue or the decisions log.
3. Separately: what you got wrong this session, whether you or the operator caught it, and what you're still unsure
   about.
4. Close by saying whether the session has compacted and whether you'd recommend rotating: the rules file's
   compaction line and rotation (`rules/morrowcairn.md`, section 10).

Five is a ceiling, not a target. Don't recap the session's work; this report is about what needs a decision.

**Would revisit if:** close reports stop surfacing items the operator decides on, or the tool itself tracks what a
session leaves finished but not shipped.

*Provenance: `skills/PROVENANCE.md`, the line for procedure 12.*

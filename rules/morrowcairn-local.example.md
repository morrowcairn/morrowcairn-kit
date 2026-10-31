# This machine's settings for the kit's rules

Copy this file to `morrowcairn-local.md`, beside the kit's rules file in Claude Code's user-level rules folder, and write
each value on its setting's own line, after the colon, as in `- **[reply folder]:** ~/claude-replies`. Leave a setting
empty where the machine keeps none: the rule that names it then applies only where the machine keeps one. This file is
yours; an upgrade never changes it.

The kit's two hooks read their settings from this file, and only from these lines: [reply folder] and [compaction log],
each a path starting `/` or `~/`, as it is or in backticks. A hook whose setting is empty writes nothing, and neither
runs until your Claude Code settings name it.

- **[owner phrase]:**
  The words that open the owner's own lines in a message that also carries pasted text.
- **[reply folder]:**
  The folder where the kit's Stop hook writes each report to a file of its own, named by project, label, session and
  number, in that order; made if it isn't there.
- **[relay log]:**
  The append-only log that takes one line per sized ask, and how a line is appended to it.
- **[owner's queue]:**
  Where a question waiting on the owner is filed, and how.
- **[compaction log]:**
  The log the kit's PostCompact hook appends one line to per completed compaction: the time, the session ID and what
  triggered it.

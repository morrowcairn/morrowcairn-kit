# Shell commands

**Loaded:** always, once per session: the machine's user-level `CLAUDE.md` imports it from the kit's
pinned install, and a project holds no copy (`skills/README.md`). Nearly every working session runs a
shell command, so a trigger would save little, and a load it missed would be silent.

Load canary: kc-c7fa43c7c505cebd. A daily check looks for this line in what sessions loaded; leave it as it is.

The failure behind each procedure here is the same. The command doesn't break loudly. A different
command succeeds quietly.

## 6. A program reaches the shell one way

1. Pass any multi-line program or payload (Python, JSON, SQL, awk) through a heredoc with a quoted
   delimiter (`<<'PY'`) or a temporary file. Never put it inside a `-c`, `-d` or `-e` string.
2. Prose, an apostrophe or a `$` in a payload is the sign it doesn't belong on a command line.

**Would revisit if:** the shell tool takes a program and its interpreter as separate arguments, with
no second shell pass.

## 7. A destructive command's target is never an unchecked variable

1. Start every multi-line shell call with `set -u`.
2. In a path given to a command that deletes, extracts, moves or overwrites (`rm`, `tar -x` or `-C`,
   `mv`, `cp` onto a file, a `>` redirect), write each variable as `${VAR:?}`. An unset or empty
   value then stops the command before it runs.
3. Never `cd` and then delete by a relative glob. Name the full path on the line that deletes.
4. Don't add `set -e` everywhere. It aborts on exits checked on purpose (grep's 1 for no match), and
   it pushes toward `|| true`, which hides real failures.

**Would revisit if:** the shell tool refuses an unset variable in a destructive path by itself.

## 8. Inspect configuration by count and name

1. When inspecting crontab, environment, or config files, or a log that may hold secrets, print counts
   or names only, never raw lines or matched tokens.
2. A URL can be a credential: a ping or webhook URL is one. Treat any token a pattern catches as a
   value.
3. Never expand a secret variable in a command, not even to test that it is set. `${VAR:-x}` prints
   the value when the variable is set. Use a tool that reports set or unset and has no way to print
   a value.

**Would revisit if:** nothing a session can read holds a value that grants access.

## 11. A search that may conclude "none found" covers ignored, binary and non-UTF-8 files

A session's `grep` may not be the system's. In Claude Code's Bash tool it is a shell function that
runs ugrep with `--ignore-files`: `grep -r` skips every gitignored file and directory, silently, and
it skips binary and non-UTF-8 text files everywhere, named on the command line or piped in as well as
found by `-r`. A backslash does not help: `\grep` runs the same function, not an alias. On a skipped
file `-c` prints nothing and exits 1 instead of printing 0. It does read hidden files (dot files).
`/usr/bin/grep` and `command grep` read all of them, and read any file named on the command line.

1. A check that concludes something is absent -- a "none found", an empty or zero count, an empty
   result from piped output -- names the command it used and the exit status of each search command in
   it. A "none found" with no named search is not a finding.
2. The search must cover gitignored, binary and non-UTF-8 files: /usr/bin/grep or command grep under
   LC_ALL=C, with -l, -c or -q, or with -a when it prints lines; ripgrep only with --text --hidden
   --no-ignore; or a byte-level count (for example a short Python program over the raw bytes) that
   names how it walked the files and which files it could not read.
3. LC_ALL=C holds on every platform, since a reader may not know which grep comes first on its PATH:
   BSD grep (macOS's /usr/bin/grep) in a UTF-8 locale does not match ASCII text on a line holding
   invalid UTF-8, with -l, -c and -a alike, where GNU grep does. Under LC_ALL=C, -i folds case only for
   ASCII letters, and \b does not count a non-ASCII letter as part of a word: for a term with a
   non-ASCII letter, give each of its case forms as its own -e pattern, with no \b beside that letter,
   or use the byte-level count, folding case on the text it decodes.
4. Never grep -I: on a file holding a NUL, -I -- and a ripgrep folder walk without --text -- exits 1
   as if nothing matched. Absence needs exit status 1 from grep or ripgrep, or a zero from such a
   count. Exit status 0 with nothing printed means output was suppressed: without -a, a NUL hides
   every printed line across a piped stream, and in a UTF-8 locale a line holding invalid UTF-8 is
   dropped. Exit status 2 means a file could not be read, even under -s.
5. A subagent's "none found" is a lead, not a finding: re-run the check in the session itself before
   reporting it. Explore subagents do not receive these rules.
6. When a new shell or tool is in play, check which files its search skips: a scratch directory with a
   stand-in string in a plain file, a gitignored file, a dot file, a binary (NUL) file, a non-UTF-8
   file and an unreadable file, each searched and piped in, in the locale the searches will run in.
   Run the check in the session's own shell: a script started as a new process gets the system's
   `grep`, not the session's.
7. A search for an identity-list term counts or lists files (-c, -l, -q) and never prints matching
   lines, -a included.

**Would revisit if:** the shell tool's `grep` is the system's, or every search names the files it
skipped; for item 3, BSD grep in a UTF-8 locale matches ASCII text on a line holding invalid UTF-8.

*Provenance: `skills/PROVENANCE.md`, lines 6 to 8 and 11.*

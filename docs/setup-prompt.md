# The setup prompt

A text you give your own Claude Code, once per machine, to set the kit up: start Claude Code in any folder and paste the
block below. It checks what the kit needs, builds a release's install from this repository's tag, and shows you the one
command that links the session rules at your user level, which you run in your own terminal. It edits no settings
file: where a step needs a setting, it shows you the lines and you add them. It makes no do-not-publish list either:
each project's list is made with the project, by
[`patterns/local-spawn.md`](../patterns/local-spawn.md). On a machine your organization's IT manages,
read [`for-it.md`](for-it.md) first, or give it to your IT: it says what the kit writes, runs and sends, and how to
remove it.

The prompt is written for both cases: Claude Code's hooks and skills open to your own settings, or locked by your
organization's managed settings. Under a lock the kit's git hooks still run, since git runs them, and what the lock
costs is said at the step it reaches.

```text
Set up the Morrowcairn kit, release v0.12.0, on this machine. Take the steps below in order. Stop at the first one
that fails and tell me what failed and what it needs. Never edit a settings file. If a check refuses a command, tell
me what it said, at that moment. A plain read that needs no review may be rerun in that plain form, saying so, unless
the refusal was over what would be read rather than how the command was written. Once a check refuses a command,
anything that writes, deletes or sends waits for my say, in any form. The steps below, the clone and the install among
them, go ahead as written.

1. What the kit needs: git 2.31 or later, gitleaks on PATH (the kit is tested with 8.30.1), python3, and sha256sum or
   shasum. Check each with its own version command, one command per tool, with no loop and no variable, so that Claude
   Code's checks can read each command before it runs: git --version, gitleaks version, python3 --version, and
   sha256sum --version, or shasum --version where there is no sha256sum. Their own output shows the versions. Stop at
   the first tool that is missing or too old, and tell me what it needs and how to get it here; don't install it
   yourself.

2. My organization's settings: don't ask me which settings my IT turns on; I may not know. Ask me to run /status in
   Claude Code and read you its Setting sources line: when my organization's managed settings apply, it lists
   Enterprise managed settings, with how they reached this machine in parentheses. On Linux or WSL, also read
   /etc/claude-code/managed-settings.json and each file in /etc/claude-code/managed-settings.d/, where they exist, and
   tell me only whether either sets allowManagedHooksOnly (a lock on hooks) or strictPluginOnlyCustomization (a lock
   on skills), and to what; show me nothing else from them. If the line names (remote), those settings come from the
   admin console and aren't in a file here: ask me to get the policy from my IT. The same goes for any source but
   (file) or (drop-ins), such as a Windows policy standing above WSL's files. If none of this settles it, say so and
   go on, giving me both cases wherever a step differs. Then tell me which case we are in: no lock, a lock on hooks, a
   lock on skills, or both.

3. The kit's code: ask me where to keep a clone of the kit, then clone it there and check out the release's tag:
   git clone https://github.com/morrowcairn/morrowcairn-kit <that folder>
   git -C <that folder> checkout v0.12.0

4. The install: in the clone, run tools/install-release.sh v0.12.0. It runs the release's own hook suite on the staged
   install first, then puts the read-only install in ~/.local/share/morrowcairn/releases/v0.12.0. Report its last
   lines as it printed them, without explaining them.

5. The session rules: show me this command; I run it myself, in my own terminal, outside Claude Code:
   ~/.local/share/morrowcairn/releases/v0.12.0/bin/kit-pin user v0.12.0
   It writes into Claude Code's own folder, which this session's commands may not reach: where Claude Code's sandbox
   is on, it keeps a session's commands from writing to Claude Code's rules, skills and hooks folders. It links the
   rules file, the kit's three skills and the two optional hooks' scripts into that folder, and writes the kit's own
   pin for the user level; it changes no settings file, and replaces nothing that isn't its own link. Ask me for what
   it printed, and read it back to me. Under a lock on skills, tell me that the three skills (gates, record-stamps,
   session-close) won't load, and that Claude Code's documentation names no lock on rules files, so the rules file
   should still load (not yet tested under a lock).

6. My local settings: the rules read a few settings from morrowcairn-local.md, beside the rules file in Claude Code's
   rules folder. Show me the install's rules/morrowcairn-local.example.md and a command that copies it there without
   replacing a file already there; I run it in my own terminal, as in step 5, and fill in what I keep. Any setting may
   stay empty. Under a lock on hooks, tell me to leave [reply folder] and [compaction log] empty: the hooks that write
   those files won't run, and a setting left set would have every report name a file that never appears.

7. The two optional Claude Code hooks, each off until my own settings name it: reply-file, a Stop hook that writes
   each session report to a file of its own in [reply folder], and compaction-log, a PostCompact hook that adds one
   line per compaction to [compaction log]. Ask me which I want. For each, show me what to add to my user settings, in
   the form Claude Code's hooks documentation gives, running the link kit-pin user printed for it, and let me add it
   myself. Under a lock on hooks, tell me neither will run, and skip this step.

8. The daily load check, a check once a day that the session rules still load from the install. Ask me whether I want
   it, under a lock on skills too, telling me that it checks the rules file only: it sees that the skills are linked,
   not whether they load, so a lock on skills goes unnoticed by it. If I want it, show me a command that copies the
   install's bin/kit-load-check-stub to a folder of mine outside the install without replacing a file already there,
   and the daily line to add to my scheduler (a crontab line, say) that runs that copy, with a PATH that finds claude,
   since cron's is short. Tell me that each run sends one headless Claude Code request (claude -p) on my account, and
   sends a ping only if I set a ping URL in KIT_LOAD_CHECK_PING, its result to that URL each run; that URL is a
   credential, so it stays out of the line, kept the way I keep secrets. Tell me it edits nothing: it changes no
   settings and no project, and writes only its own folder, ~/.local/state/morrowcairn/load-probe/, and a report file
   if I name one in KIT_LOAD_CHECK_REPORT. I add the line myself.

9. New projects: tell me, from the install's patterns/local-spawn.md, what a project made from this release starts
   with: no do-not-publish list (one line at the list's place saying so, pinned) and no identity guard. Local-spawn
   asks once, as the project is made, whether it will hold terms I've agreed or am required to keep confidential, and
   if so puts its list in place; the identity guard (patterns/repo-genesis.md, step 1a) is a choice it offers, never a
   default.

10. Finish with a short summary: the versions step 1 found, what was installed and where, what was linked, which
    settings I set, which hooks I turned on, whether I set up the daily load check, which case of step 2 applies, and
    that docs/for-it.md in the install is the document for my IT.
```

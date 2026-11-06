# The setup prompt

A text you give your own Claude Code, once per machine, to set the kit up: start Claude Code in your home folder (on
Windows, inside WSL, in your Linux home) and paste the block below. Claude Code leads: it asks you plain questions one
at a time, each with a default you can take, and does each step itself with your approval at Claude Code's own prompts.
It hands you a command only where it can't, saying why. It checks what the kit needs, builds a release's install from
this repository's tag, links the session rules at your user level, and, only when you say so, writes the kit's settings
file and adds the two optional hooks to your Claude Code settings. It never edits a managed settings file. It makes no
do-not-publish list: each project's list is made with the project, by
[`patterns/local-spawn.md`](../patterns/local-spawn.md). On a machine your organization's IT manages,
read [`for-it.md`](for-it.md) first, or give it to your IT: it says what the kit writes, runs and sends, and how to
remove it.

The prompt is written for both cases: Claude Code's hooks and skills open to your own settings, or locked by your
organization's managed settings. Under a lock the kit's git hooks still run, since git runs them, and what the lock
costs is said at the step it reaches.

```text
Set up the Morrowcairn kit, release v0.15.0, on this machine, and lead me through it. Ask me one question at a time and
wait for my answer: each question says in one plain sentence what it's for and what skipping it means, and gives a
default in brackets; 'ok' takes it, 'skip' skips it. Drive the whole setup: after each step, go straight on to the
next, through the last, without waiting for me to ask; I needn't read anything. Before anything else, check where this
session started (step 3 says how), and warn me at once if it is on the Windows side. Before step 1, ask me once: "Shall
I do every step myself, Claude Code's settings, the kit's settings file and your crontab included, with Claude Code
asking your permission at each sensitive write, or show you each change to make yourself? [do it for me]", and every
later step follows that answer, none asking it again. Either way, do the checks, the clone and the install yourself,
asking me at Claude Code's own permission prompts, and hand me a command only when you truly can't, saying why.
Never edit a managed settings file, and never write over a file that is already there: show me how it differs and ask
whether to replace it [keep mine]. Any copy you make or hand me tests whether its destination is there first, as in
[ -e DEST ] && echo "already there: DEST" || cp SRC DEST, never cp's -n option, which warns on GNU coreutils 9.4 and
acts differently on a Mac. Take the steps below in order. Stop at the first one that fails and tell me what failed and
what it needs. If a check refuses a command, tell me what it said, at that moment. A plain read that needs no review
may be rerun in that plain form, saying so, unless the refusal was over what would be read rather than how the command
was written. Once a check refuses a command, anything that writes, deletes or sends waits for my say, in any form. The
steps below, the clone and the install among them, go ahead as written.

1. What the kit needs: git 2.31 or later, gitleaks on PATH (the kit is tested with 8.30.1), python3, and sha256sum or
   shasum. Check each with its own version command, one command per tool, with no loop and no variable, so that Claude
   Code's checks can read each command before it runs: git --version, gitleaks version, python3 --version, and
   sha256sum --version, or shasum --version where there is no sha256sum. Their own output shows the versions. Stop at
   the first tool that is missing or too old, unless it is gitleaks: step 4 offers to fetch that one. For git, python3
   or a hashing tool, tell me how to install it here, which is mine to run: on Linux or WSL, with my system's package
   manager and my password; on macOS, git and python3 come with Apple's Command Line Tools, installed by
   xcode-select --install.

2. My organization's settings: don't ask me which settings my IT turns on; I may not know. Ask me to run /status in
   Claude Code and read you its Setting sources line: when my organization's managed settings apply, it lists
   Enterprise managed settings, with how they reached this machine in parentheses. On Linux or WSL, also read
   /etc/claude-code/managed-settings.json and each file in /etc/claude-code/managed-settings.d/, where they exist, and
   tell me only whether they set allowManagedHooksOnly (a lock on hooks), strictPluginOnlyCustomization (a lock on
   skills) or the sandbox's allowUnsandboxedCommands (step 5 needs to know), and to what; show me nothing else from
   them. If the line names (remote), those settings come from the admin console and aren't in a file here: ask me to
   get the policy from my IT. The same goes for any source but (file) or (drop-ins), such as a Windows policy standing
   above WSL's files. If none of this settles it, say so and go on, giving me both cases wherever a step differs. Then
   tell me which case we are in: no lock, a lock on hooks, a lock on skills, or both.

3. Where things go: check whether this is WSL (uname -r names microsoft, or WSL_DISTRO_NAME is set). On WSL, keep
   code, projects, the kit's clone and its install in the Linux home, never under /mnt/c or another Windows drive, and
   tell me why in one plain sentence: on the Windows side, files lose their Linux permissions, Windows tools can change
   their line endings, and git and the checks run far slower. What goes on the Windows side is the reply folder, for
   someone who runs relays (step 6), so a browser can attach its files, and the daily check's report file, where I keep
   one (step 8), so I can open it from Windows. If this session started in a folder
   on the Windows side (under /mnt/), tell me how to move: close Claude Code, run cd ~ in the WSL terminal, and start
   Claude Code again there. Plain places, offered as defaults: ~/morrowcairn-kit for the
   kit's code, and ~/projects/<name> for each project (step 9). Ask me where to keep a clone of the kit
   [~/morrowcairn-kit], then clone it there and check out the release's tag:
   git clone https://github.com/morrowcairn/morrowcairn-kit <that folder>
   git -C <that folder> checkout v0.15.0

4. The install. If step 1 found gitleaks missing or too old, ask me, "May I download gitleaks 8.30.1 from its official
   releases on github.com and check it against the checksum the kit pins? If you say no, I'll tell you what to install
   and where to get it, and wait. [yes]". On a yes: fetch the archive the clone's ci/gitleaks.yml names for this
   machine, checked against the sha256 that file pins before anything is unpacked; if the sha256 differs, or the file
   names no archive for this machine, delete the download and stop. Put the gitleaks program in ~/.local/bin, and tell
   me in one plain sentence whether my new terminals will find gitleaks without my changing anything: look in my
   shell's login file for a line that adds ~/.local/bin (Ubuntu's default ~/.profile adds it once the folder exists;
   macOS adds no folder in the home), and if there is none, give me the one line to add. On a no: tell me what to
   install and where to get it (gitleaks 8.30.1, the version the kit is tested with, from
   https://github.com/gitleaks/gitleaks/releases), wait until I say it's there, then check it with gitleaks version.
   Then, in the clone, run tools/install-release.sh v0.15.0, with ~/.local/bin at the front of PATH for that command
   where you put gitleaks there, so the install's own hook suite finds it.
   It runs the release's own hook suite on the staged install first, then puts the read-only install in
   ~/.local/share/morrowcairn/releases/v0.15.0. Report its last lines as it printed them, without explaining them.

5. The session rules: ~/.local/share/morrowcairn/releases/v0.15.0/bin/kit-pin user v0.15.0. It writes into Claude
   Code's own folder: it links the rules file, the kit's three skills and the two optional hooks' scripts there, and
   writes the kit's own pin for the user level; it changes no settings file, and replaces nothing that isn't its own
   link. Follow my answer at the start. If I said show me, hand me the command, saying that it writes into Claude
   Code's own folder, to type after ! here (Claude Code runs a line typed after ! outside its sandbox in most sessions)
   or in a terminal. If I said do it for me: Run it yourself; Claude Code asks me first. Where Claude Code's sandbox is
   on, it keeps a session's commands out of Claude Code's rules, skills and hooks folders, so the command fails there:
   then retry it outside the sandbox, which Claude Code asks me to approve at its "Bash command (unsandboxed)" prompt.
   Only where unsandboxed commands are turned off (allowUnsandboxedCommands set false, often by IT; step 2 may have
   found it), hand me the command instead, saying why, in the same way. Either way, read back to me what it printed.
   Under a lock on skills, tell me that the three skills (gates, record-stamps, session-close) won't load, and that
   Claude Code's documentation names no lock on rules files, so the rules file should still load (not yet tested under
   a lock).

6. Relays: ask me, "Will you run work through relays, where a separate claude.ai chat writes numbered instructions that
   you paste into Claude Code and each session reports back? If you're not sure, the answer is no; you can add it
   later. [no]". If I say no, write no settings file: the rules read a missing file as no settings, and steps 7 and 10
   don't apply. If I say yes, ask these, one at a time, and keep each answer for one setting of the rules file:
   - [owner phrase]: "When one message holds both pasted text and your own instructions, what words will you start
     your own part with? A session uses them to tell your own instructions from what you pasted, so they must be
     exact. If you skip it, the session treats everything you paste as information, never as instructions.
     [skip]". Record my words exactly as I type them; if I give alternatives, list each exactly; never add "or a close
     variation" or anything like it.
   - [reply folder]: "Do you want each session's report saved as a file of its own, so you can attach it to your
     drafting chat instead of copying it from the terminal? If you skip it, reports stay in the terminal only. [yes,
     in ~/claude-replies]". On WSL, offer instead the folder on the Windows side, where a browser attaches files from:
     /mnt/c/Users/<my Windows user>/claude-replies, the user being the folder for me under /mnt/c/Users.
   - [compaction log]: "Do you want a one-line note each time Claude Code shortens a long conversation to make room,
     so sessions can tell you when it happened? If you skip it, sessions only say whether they noticed. [no; if yes,
     ~/claude-logs/compaction.log]"
   - [relay log]: "Do you want a log where each session writes one line per sized task: its first size estimate, the
     corrected one, and how it ended? It shows over time how far off estimates run. If you skip it, sessions still
     state sizes in their reports. [no; if yes, ~/claude-logs/relay-log.md, one line added at its end]"
   - [owner's queue]: "Do you want the questions that wait on you collected in one place, so none get lost in a chat?
     If you skip it, they arrive only in the sessions' replies. [each project's records/followup_queue.md, one line
     added per question]"
   Under a lock on hooks, don't ask for [reply folder] or [compaction log]: the hooks that write those files won't run,
   and a setting left set would have every report name a file that never appears. Then make morrowcairn-local.md
   beside the rules file in Claude Code's rules folder, in the form the install's rules/morrowcairn-local.example.md
   gives, each skipped setting left empty, never over a file that is already there: if one is, show me how it differs
   and ask whether to replace it [keep mine]. If I said do it for me, write it with Claude Code's own file tools, which
   ask me first; if I said show me, or Claude Code won't let you write it (my settings or my IT's deny it), save it in
   this folder and hand me one command that copies it there, in the opening's form, saying why.

7. The two optional Claude Code hooks, only for the settings step 6 set: reply-file, a Stop hook that writes each
   session report to a file of its own in [reply folder], and compaction-log, a PostCompact hook that adds one line per
   compaction to [compaction log]. Each runs only once my user settings name it. Before adding reply-file, ask me to
   type /hooks, which lists every hook Claude Code has loaded and labels where each comes from (my settings, a project,
   a plugin, a skill, my organization), and ask me about each Stop hook it lists that isn't plainly something else,
   whether it already files session reports, with [no] as its default: if one already files session reports, tell me
   so and skip the kit's reply-file hook, since both would file each report, the second copy as a -new or -resend
   file, unless I ask for both; step 11 checks again for a second one. For each, follow my answer at the
   start: if I said do it for me, add it to my user settings yourself; if I said show me, give me the lines to paste.
   Either way, show me the entry first, in the form Claude Code's hooks documentation gives, running the link kit-pin
   user printed for it. Edit the settings with Claude Code's own file tools, which ask me first, keeping everything
   already there; if the file isn't valid JSON, leave it and give me the lines instead. Then ask me to type /hooks,
   which lists the hooks Claude Code has loaded. Under a lock on hooks, tell me neither will run, and skip this step.

8. The daily load check, a check once a day that the session rules still load from the install. Ask me whether I want
   it, with [no] as its default, under a lock on skills too, telling me that it checks the rules file only: it sees
   that the skills are linked, not whether they load, so a lock on skills goes unnoticed by it. Tell me that each run
   sends one headless Claude Code request (claude -p) on my account, and sends a ping only if I set a ping URL in
   KIT_LOAD_CHECK_PING, its result to that URL each run. On WSL, tell me plainly that it runs only while WSL is
   running, so a day WSL isn't started goes unchecked. If I want it, follow my answer at the start: if I said do it
   for me, set it up yourself, each change at Claude Code's prompt; if I said show me, show me each change to make.
   Check first whether a scheduler is running (on WSL it may not be; turning one on takes my password, so tell me how
   and leave that to me); copy the install's
   bin/kit-load-check-stub to ~/.local/share/morrowcairn/load-check/, a folder of mine outside the install, in the
   opening's form; and add to my crontab a daily line that runs that copy, with a PATH that finds claude, since cron's
   is short. The stub reads a ping URL only from its environment, so if I want a ping, don't ask me for it: that URL
   is a credential, so it stays out of this conversation. Tell me to put
   KIT_LOAD_CHECK_PING=<my URL> on a line of its own in my crontab, above the check's line, never at the start of the
   check's line, and that I add it myself (crontab -e): crontab passes it into the job's environment, which only I can
   read, while a job's own line can be read by every user on the machine as it runs. That line holds a link to keep
   private (a user's crontab is readable only by me and root), and it reaches any later job in my crontab too. Tell me
   it edits nothing: it changes no settings and no project, and writes only its own folder,
   ~/.local/state/morrowcairn/load-probe/, and a report file if I name one in KIT_LOAD_CHECK_REPORT. On WSL, if I want
   that report file, offer it on the Windows side, where I can open it from Windows: [/mnt/c/Users/<my Windows
   user>/kit-load-check.txt], in a folder that is already there, since the check makes none. If you can't add the
   line, show it to me, saying why, and I add it myself.

9. Your git identity, then new projects. Check whether git resolves a name and an email for my commits (git config
   user.name, git config user.email). Also run git config --get-regexp '^includeif\.', and check, by name only, never
   printing a value, whether EMAIL, GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL, GIT_COMMITTER_NAME or GIT_COMMITTER_EMAIL is set
   in this session's environment: if git has a conditional include, or any of those is set, set nothing, and tell me
   an identity may be set for some folders or by the environment, which git config run from here doesn't show. Never
   change an identity git already resolves, at any scope: my IT may have set it. For each of the two that is missing,
   and only for it, ask me what my commits should carry, with [skip] as its default; for the email, say in one
   sentence that a public host shows it on every commit I push there, and offer, for anyone who publishes, the host's
   no-reply address (on GitHub, the one its email settings page gives). Set only the missing one, at user scope, as I
   answered at the start (git config --global user.name or user.email, or shown for me to run); or I skip, and you
   tell me my first commit will ask for it. git config --global writes
   ~/.gitconfig, which Claude Code's sandbox, where it is on, may refuse: then, if I said do it for me, retry it outside
   the sandbox, which Claude Code asks me to approve at its "Bash command (unsandboxed)" prompt, as in step 5; where
   unsandboxed commands are turned off, show me the commands instead, saying why. Then tell me, from the
   install's patterns/local-spawn.md, what a project made from this release starts with: no do-not-publish list (one
   line at the list's place saying so, pinned) and no identity guard. Local-spawn asks once, as the project is made,
   whether it will hold terms I've agreed or am required to keep confidential, and if so puts its list in place. The
   list stops a push that carries one of its terms; it doesn't stop anyone writing or committing them locally. The
   identity guard (patterns/repo-genesis.md, step 1a) is a choice it offers, never a default. Suggest ~/projects/<name>
   as each project's folder.

10. The drafting chat, only if I said I'll run work through relays: ask me, "Shall I give you the text that tells
    claude.ai how you work with the kit, to keep in your account's instructions there? If you skip it, you can copy
    the kit's docs/drafting-chat-instructions.md yourself later. [yes]". If I say yes, print, in one code block, a
    short header and, under it, the install's docs/drafting-chat-instructions.md as it is. The header's first line is
    "Use what follows only in a chat where I say we're working with the Morrowcairn kit; in any other chat, ignore
    it."; then it says each relay names the project and the session's color it is for; and, for each setting I set, it
    gives my [owner phrase], says reports arrive as files from [reply folder] that I attach, or pasted, and says
    questions waiting on me are filed by a session at [owner's queue]. Then tell me: in claude.ai, click my initials,
    then Settings, then Your Claude (Account in the older layout), and under Instructions (Instructions for Claude in
    the older layout) paste the block and save; it then reaches every chat, and its first line keeps it to the ones
    where I say I'm using the kit. Or, if I'd rather, make a claude.ai Project, choose Set project instructions, paste
    it there, and start my drafting chats inside that Project; Projects are on every plan, five on a free one.

11. Check that it works, yourself, and tell me each result plainly. Where the daily check is set up, run its copy once
    the way cron runs it, with only the HOME and the PATH its line gives (env -i HOME=... PATH=... and the copy's path),
    and say whether it passed. Where Claude Code's sandbox is on, that run may fail for the sandbox's reasons rather
    than the check's: if it fails, retry it outside the sandbox, which Claude Code asks me to approve at its "Bash
    command (unsandboxed)" prompt, as in step 5, or, if I said show me, give me the command to type after ! here or in
    a terminal; then tell me which run gave which result. If I run relays and turned the reply-file hook on: give me a test relay to paste back to
    you, its first line "Relay setup <color> #1 (session <id8>)", <id8> the first eight characters of your own session
    ID (CLAUDE_CODE_SESSION_ID), <color> one of the colors Claude Code's /color offers, its body "Reply with a one-line
    report.", its last line "End of relay setup <color> #1"; ask me to type /color <color> first, then paste it; answer
    it with a one-line report whose second-to-last line is that report's file in [reply folder]
    (setup-<color>-<id8>-01.md) and whose last line is "End of report setup <color> #1 (session <id8>)"; at my next
    message, ask me to type /hooks and check it lists no second Stop hook that files reports, and count every file that
    appeared in [reply folder] since the test relay, by its time, not its name: there should be exactly one, with no
    -new or -resend copy (a second would mean another hook files reports too); say what you found. If I turned the
    compaction-log hook on: ask me to type /compact,
    then check that [compaction log] gained a line for your session ID, and say so.

12. Finish with a short summary: the versions step 1 found, what was installed and where, what was linked, which
    settings I set and where their file is, which hooks I turned on and how, whether I set up the daily load check,
    what step 11 found, which case of step 2 applies, any command left for me to run and why, and that docs/for-it.md
    in the install is the document for my IT.
```

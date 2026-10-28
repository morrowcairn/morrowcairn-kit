# leak-detection

Two layers, shipped differently by necessity.

| Layer | Where the rules live | Ships |
|---|---|---|
| **Credential shapes** | `.gitleaks.toml`, committed | **Complete** — works with no configuration |
| **Listed terms**: the do-not-publish list (called the identity list in v0.11.0's messages), and CI's generic patterns | an untracked local file (the list) / a repository secret (the generic patterns only) | **Mechanism only** — fails closed until configured |

**Why the do-not-publish list cannot ship complete:** the pattern *is* the list — the exact
strings you are trying to keep out of a public repository. Committing it publishes them. So the
mechanism ships and the content does not, and the scan **fails closed** until someone supplies a
pattern. An adopter who pushes unconfigured gets a hard error rather than a green check that
examined nothing.

The list is private to each clone. It holds terms you've agreed or are required to keep confidential: a
client's or a matter's name, a research participant's details, a data partner your agreement says you won't
name, an unreleased product's codename, a private server's address. Most projects don't need one; a project
without one says so in a single pinned line (below).

## What neither layer catches: personal data

**The credential layer detects credential shapes, not personal data.** A spawned instance measured
this against this exact ruleset. A fake AWS key pair was blocked. A file holding a fake Social
Security number, date of birth, account and routing numbers, a passport number, a name and an
address committed clean. A CSV with "account number" in its header row and bare digits below is
missed entirely: keyword-anchored rules cannot reach across the line break, and un-anchoring them
would fire on every nine-digit identifier.

So a green hook is **not** the control for personal or financial records. The control is keeping
raw records out of the tree altogether, at any path, ignored or not. Write that rule in the
project's `CLAUDE.md`, and never let a green scan stand in for it.

## Setup

```bash
"$INST/bin/kit-pin" to vX.Y.Z                                      # a project: kit.pin and the stubs, per clone
git config core.hooksPath leak-detection                            # the kit itself: hooks from its working tree
echo "LEAK_PATTERN='marker1|marker2'" > "$(git rev-parse --git-dir)/leak-pattern"   # every term, local only
"$INST/bin/kit-pin" repin local --first                             # its pin, beside it (a first pin: below)
gh secret set LEAK_PATTERN < "$(git rev-parse --git-dir)/leak-pattern.ci"   # CI: the non-confidential terms only
"$INST/bin/kit-pin" repin ci --first                                # CI's pin: commit .github/leak-pattern.pin
```

A project runs these hooks from a release's install (`$INST`), through two stubs in `.git/hooks` that check
the install against the project's `kit.pin` first (`patterns/local-spawn.md`, `patterns/local-upgrade.md`).
The kit runs them from its own working tree: it is where releases come from, not a pinned project.

**What they need.** git 2.31 or later (both hooks and `bin/kit-pin` refuse an older one, naming it); gitleaks on
`PATH` (both hooks refuse without it, saying it may be missing or hidden, as a sandbox that blocks reading the home
folder hides it); `sha256sum` or `shasum`; and
python3, for a push that carries a binary and for `tools/install-release.sh`. gitleaks comes from its own
releases (the kit's CI installs 8.30.1, checked against its published sha256) or a package manager. On a Mac,
git and python3 come with Apple's developer tools (the Command Line Tools, or Xcode); without them,
`/usr/bin/git` and `/usr/bin/python3` only offer to install the tools (`xcode-select --install`), which the
kit hasn't measured. The kit repository's `CLAUDE.md`, under Environment, says what each system was measured
with.

**Their credential rules.** Both hooks and the binary scan name their gitleaks config: the project's
`.gitleaks.toml`, or else `spawn.gitleaks.toml` beside them (in a release's install, the release's own), and they
refuse when there is neither. Given no `--config`, gitleaks takes one from `GITLEAKS_CONFIG` or
`GITLEAKS_CONFIG_TOML` in the environment, ahead of a tracked `.gitleaks.toml`, so whoever sets those would choose
the rules; the hooks drop both. A hand copy of an early release's hooks, which runs gitleaks without `--config`, is
open to that: move it onto a release's install.

**The list file is read as data, never run.** It may hold blank lines, full-line comments (`#` first),
and exactly one `LEAK_PATTERN='...'` line as the setup line writes it, or `export LEAK_PATTERN='...'`,
with nothing after the closing quote. pre-push refuses a file in any other shape, a second
`LEAK_PATTERN` line included. A term can't hold an apostrophe yet.

**A project with no identity list says so with one line.** A missing list refuses every push, naming
the line, so "forgot" is never read as "don't want". The line is the reserved value, pinned like any
list:

```bash
echo "LEAK_PATTERN='kit:no-identity-list'" > "$(git rev-parse --git-dir)/leak-pattern"
"$INST/bin/kit-pin" repin local --first
```

With it, pre-push turns its identity layers off, says so on every push, and still runs the credential
scan; `kit-pin check` reports identity checks off. For CI, set the secret to that reserved line's value,
`kit:no-identity-list`, and pin it (`repin ci --first`); the tree scan then says identity checks are off. A list file that exists but
can't be read refuses with a message of its own, never the missing list's. The pin guards the line:
written over a real list, it doesn't match that list's pin, and changing a list's rows needs the
owner's words (below). A project going public needs a real list: `bin/kit-history-audit` refuses the
line. *A release older than this one* reads the line as a one-row list and, once it is pinned, passes
pushes with no note: move such a project onto this release before writing the line.

**Each list is pinned.** pre-push refuses unless the local list is the one `.git/leak-pattern.pin` names, and
CI's scan refuses unless the `LEAK_PATTERN` secret is the one the tracked `.github/leak-pattern.pin` names. A pin
holds the list's rows (its top-level alternatives) and the SHA-256 of its value, so a list cut, or changed in
place, refuses where a count alone would pass. The local pin stays untracked beside the list, as the list does: a
hash of the whole list lets anyone holding a guess at it confirm the guess. CI's list holds no confidential term, so its
pin is tracked, and a change to it is a reviewed commit. CI's secret can't be read back, so its exact value is kept,
untracked, in `.git/leak-pattern.ci`, with no trailing newline. A refusal gives rows, never a term or a hash.
`bin/kit-pin check` finishes with exit 3 while pre-push would refuse every push: no usable list, or one its pin
doesn't name.

**A first pin** is written once, with `--first`, after the list is checked against a source it didn't come from:
the copy its rows were made from (another list they were copied from, compared by exact text), or the records of
each row's addition; never the list against itself. A project moving onto an install takes its pins in that move
(`patterns/local-upgrade.md`). A project with no confidential terms of its own says so with the pinned line above;
it may instead keep a local list of only the terms that aren't confidential, the ones `kit-pin`'s setup text calls
"the terms that identify no one" (a synthetic canary, machine paths, an IP pattern), as its CI list does, and pin
it.

**Changing the list.** After any change, repin it, `bin/kit-pin repin local` (or `ci`), which tells an append from
anything else:
- An append, new rows after the old ones with the old untouched, is taken as it is: the session that makes it
  repins and records it.
- Any other change takes the owner's words: a row changed or removed, or retired by the never-matching placeholder
  that keeps its place (a list is append-only, so its rows keep their positions), because fewer rows, or other
  ones, protect less. repin refuses it without `--ruling §N`, the decisions-log § that holds those words.
- Every repin is recorded in the decisions log with the rows before and after, which repin prints, and why.
- For CI, change the secret and `.git/leak-pattern.ci` together, then `repin ci` and commit the pin.
- A list that doesn't match its pin is what the pin exists to catch: never repin to quiet a refusal you didn't
  expect, and put the list back instead.

**kit-pin never replaces a hooks path silently.** A hooks path sends git past the stubs, so `kit-pin to`
and `kit-pin check` refuse one set in the clone itself, and name it. `kit-pin migrate` is the
deliberate replacement, for a project that still runs a hooks path: it keeps any hooks in `.git/hooks`
aside, unsets the path, names it, and puts everything back if its check fails.

**An org's hooks still run.** Where an org's IT sets `core.hooksPath` at the system or global level,
`kit-pin to` sets a hooks path for the project's clone alone, on the stubs, and names the org's folder.
Each stub runs the org's hook for its event first, as git would: by its own path, with the same
arguments and standard input, from the top of the work tree. Then it runs the kit's checks. Either
refusing refuses the commit or push. `kit-pin check` refuses an org's hooks path the clone doesn't
override this way. A hook the project already has in `.git/hooks` is never overwritten: `to` keeps it
as `<hook>.project`, and the stub runs it after the org's hook and before the kit's checks. One it
can't run that way (a link, a folder, a file that isn't executable) makes `to` refuse and name it.
The kept hook is the kit's to run, so it is never skipped: if it later loses its execute bit, the stub
refuses the commit or push and names it, to restore the bit or remove the file, as with `hook-checks/`.
An org's hook that isn't executable is skipped, as git skips it, and the kit's checks still run.

**The two lists differ on purpose.** The local file holds every term. The repository secret holds
only the terms that aren't confidential themselves: a synthetic canary, machine-path patterns, an
IP-address pattern. A secret is stored with the forge, under the account that owns the repository, so
a confidential term put in a secret would hand it to the very service the list keeps it from.
The cost is real and should be written down where the project states its posture: CI does not check
the confidential terms, so an edit made on the forge reaches the remote with nothing checking it for
them, and a pull request's commits are checked for them only by the local hook of whoever pushed
them, which `--no-verify` skips.

### A project's own checks: `hook-checks/`

A project that needs one more check at commit or push time does not fork a hook or point
`core.hooksPath` at a wrapper folder. It puts an executable in `hook-checks/pre-commit/` or
`hook-checks/pre-push/`, tracked, and the kit's hooks run it:

- **After the kit's own checks pass, never instead of them.** Entries run in name order, and any
  non-zero exit refuses. A check can add a refusal; it cannot admit what the kit refused.
- **Nothing is skipped.** An entry that is not an executable file refuses, and so does a
  `hook-checks/<hook>` that is not a readable folder. Git skips a non-executable hook with a hint and
  lets the commit through; this runner does not.
- **pre-commit refuses a check that changes what is staged.** The credential scan read the index
  before the checks ran, so a check that restages would commit content the scan never saw.
- **pre-push checks get the hook's arguments** (remote name, URL) and, on stdin, the ref lines git
  sent.

The folder belongs to the project. The kit ships nothing in it, so an upgrade never touches it, and
an absent folder runs nothing. A fresh clone of a project needs only its stubs (`bin/kit-pin restore`
or `to`): the checks are tracked and run from wherever the release's hooks run, with `KIT_INSTALL`
naming the install. A project that points `core.hooksPath` at a wrapper folder moves the wrapper's
checks here, then runs `bin/kit-pin migrate`.

### Binary files: the reviewed list

**On or off.** The binary scan runs in a project only when the project turns it on, read at the pushed
tip as the reviewed list is: a tracked `kit.binaries` at the project's root holding the one line
`scan=on`, or a tracked `records/reviewed_binaries.txt`, even an empty one, which a project relying on
the scan already has, so none loses it at its move onto v0.11.0. Anything else in `kit.binaries`
refuses every push that carries a binary. Off, a push carrying a binary says so on one line ("binary
scan off for this project") and goes through unscanned; the identity layer still reads the tip's raw
bytes, binaries included, and gitleaks the text. **What off leaves unchecked:** credentials in binary
files, which gitleaks skips at commit, at push and in a project's CI job (`ci/gitleaks.yml`, which skips a PDF even
renamed `.txt`), and names in text compressed inside a binary, as in
most PDFs, whose raw bytes don't hold that text: a PDF whose text stream holds a list term, compressed,
commits and pushes with the scan off, and the same text uncompressed is refused. **Turning the scan on
is the guard**: a binary then passes only if all three checks below hold, and a PDF never does, since
its format isn't one the scan can read. To turn the scan off, remove both `kit.binaries` and the
reviewed list. A project that commits PDFs or Office files it can't review may leave it off, knowing
what that leaves; a project going public turns it on (`patterns/going-public.md`). `bin/kit-pin check`
says which it is.

gitleaks cannot read binary content. So, with the scan on, pre-push hands every binary file that any
of a push's new commits adds to `leak-detection/scan-binaries.py`, which needs python3 for such pushes only and runs
isolated (`python3 -I`), so no module planted on `PYTHONPATH` or in the user site runs in it. A binary
is cleared only if all three of these hold:

1. **Reviewed.** Its full blob id is on a line of `records/reviewed_binaries.txt` in the pushed
   tip's tree, as `<blob id>  <path>  <date>  <who>  <what was checked>`. The list is read from the
   tip, never from the working tree. `git hash-object <file>` prints the id, and a refusal prints the
   whole line to add. The review is a person looking at the image, or watching the clip, itself,
   because no scan reads pixels. The list goes by blob id, not path: a copy or a rename of reviewed
   bytes needs no new review, and any change to them does. A path would clear whatever lands at it
   next.
2. **Structurally plain.** A PNG, JPEG or WebP holding only chunk types that have no metadata
   field, the places where tools write authors, software, locations, paths and comments:
   - PNG: IHDR, IDAT, IEND, PLTE, tRNS, and the fixed-size colour and pixel-size chunks gAMA, cHRM,
     sBIT, bKGD, hIST, pHYs and sRGB.
   - JPEG: a 16-byte JFIF APP0 (no room for a thumbnail), every frame type (SOFn), DQT, DHT, DRI,
     SOS, and the restart markers inside scan data.
   - WebP: VP8X, ALPH, VP8, the set the spawns' images were measured to use.

   Anything else is refused by name:
   - metadata: text chunks, EXIF, XMP, colour profiles, time, comments, any other APPn;
   - bytes after the image's end;
   - any unknown chunk type, and any other format.

   An allowed chunk still holds bytes (a palette up to 768, the pixel data any number). Text put
   there is caught by the strings pass, item 3. Fix a refused image by re-encoding or stripping it.

   **Video**: an MP4 or WebM holding one video track and the structure a spawn's clean encodes
   were measured to use, each box or element allowed only inside its named parent:
   - MP4 (H.264): `ftyp`; `moov` with `mvhd`, one `trak` (`tkhd`, `edts/elst`, `mdia` with `mdhd`,
     `hdlr` and `minf`: `vmhd`, `dinf/dref/url `, and `stbl` with `stsd/avc1` (`avcC`, `colr`,
     `btrt`), `stts`, `stss`, `ctts`, `stsc`, `stsz`, `stco`), and `udta/meta` (`hdlr`, an empty
     `ilst`); `free`; `mdat`.
   - WebM (VP9): the EBML header; a Segment of SeekHead, Void, Info, Tracks (one TrackEntry with its
     Video and Colour), Tags, Clusters of SimpleBlocks, and Cues.

   Text fields are checked by value and never printed. A clean encode carries only fields its
   encoder writes itself, and those are admitted by their exact bit-exact values, with no version
   number, rather than required absent: WebM requires its muxing and writing app fields, so they
   cannot be encoded away. The values:
   - MP4: brands `isom`, `iso2`, `avc1`, `mp41`; handler name `VideoHandler`; compressor name
     `Lavc libx264`; the `udta/meta/ilst` holder empty. A name field may also be empty. The data
     reference must point inside the file, the `colr` box must be the plain `nclx` type, `free`
     must be zero bytes, and the creation and modification times must be zero.
   - WebM: DocType `webm`; MuxingApp and WritingApp `Lavf`; Language `und`; CodecID `V_VP9`;
     each SimpleTag one name and one value, either ENCODER = `Lavc libvpx-vp9` or DURATION = a
     timestamp. Void must be zero bytes, and a number element at most 8 bytes long.

   Anything else is refused by name: a `uuid` box (where a tool's raw download carries its
   provenance manifest), an `ilst` item (encoder, cover art), a title, a date, attachments,
   chapters, an audio track, a second track (no player shows it, so no review sees it), any
   unknown box or element, an element of unknown size (the live-stream form), and bytes after the
   end. The fix is to re-encode with no audio, no metadata or chapters carried over, and the
   encoder's bit-exact flags on the container and the codec; a versioned encoder string (`Lavf`
   followed by a version number) means those flags were off.

   The frame data (`mdat`, SimpleBlock) is not parsed, as a PNG's IDAT is not: text an encoder
   writes inside the H.264 stream, such as its settings string, is left to the strings pass. Strip
   it at the encode if it should not ship.
3. **No match in its strings.** Its bytes and their UTF-16 text are matched against `LEAK_PATTERN`
   with the identity layer's engine (`git grep -iE`), and its printable strings go through gitleaks.

The push's text is scanned as before, whatever the binary verdict. A binary in any other format still
has only `--no-verify`, which skips every check.

**Binaries are checked at push only.** pre-commit's credential scan reads the staged text and skips
binary content. Measured: a PNG carrying credential text committed cleanly, and pre-push refused it. So a
project that commits images but never pushes them has no binary check at all.

### Recovering the identity sentinel

The sentinel value lives in two places, neither of them the repo: the `LEAK_PATTERN` secret and the
operator's rotation checklist. If both are lost, the procedure still survives the value —
**mint a new sentinel → update the secret → re-fire the canary.** The point is that the value never
has to enter the repository to be recoverable, only the *procedure* does.

## Verify each scanner fires before you trust it green

A scan that has never blocked anything has not been shown to work — it has only been shown to be
quiet, and the two are indistinguishable in a log. **Each layer has its own canary**, because a
fail-closed red proves the guard fires, not that the detector detects — they are different code
paths and one green does not vouch for the other.

**Identity canary** (the marker scan):

1. Commit a file containing a known marker from your pattern.
2. Confirm the push is blocked locally, and that the CI run goes **red**.
3. Remove the marker.

**Credential canary** (the `.gitleaks.toml` rules). A synthetic fixture of fake secrets lives at
`leak-detection/fixtures/synthetic_config.txt`. It is **allowlisted** in `.gitleaks.toml`, so routine
scans stay green; to canary, scan a **copy** placed outside the allowlisted path:

```bash
cp leak-detection/fixtures/synthetic_config.txt /tmp/synthetic_config.txt
gitleaks dir /tmp/synthetic_config.txt --config .gitleaks.toml -v   # expect findings, exit 1
rm /tmp/synthetic_config.txt
```

**Expect all nine custom rules to fire** — the five that rarely see live traffic are the whole point;
a fixture that trips four of nine has reproduced the coverage gap it exists to close:
`generic-api-key-40char-in-config`, `generic-secret-assignment`, `kit-jwt`, `bearer-header`,
`db-url-with-password`, `private-key-pem`, `aws-named-access-key-id`, `aws-named-secret-access-key`,
`monitoring-ping-url-uuid`. (Three gitleaks *default* rules fire alongside them, `generic-api-key`,
`jwt` and `private-key` — expected, `useDefault` is on.)

`tests/hooks_test.sh` makes this check on every run, one case per rule (GR1 to GR9): each rule must
catch its own block of the fixture, scanned alone, under its own id. A refusal alone proves nothing
here, since the default rules refuse the whole fixture with no custom rule at all. Further shapes a rule
must catch have blocks of their own, under `# <rule id>, <note>`, and cases of their own (GR10 on). The
scan above stays as a way to see the findings for yourself.

Run each canary at setup, and again after any change to that layer's pattern, rules, or workflow.

## Expected findings — read this before investigating a red

Two committed-on-purpose findings. Neither is a live leak; both are self-describing.

1. **A history-wide identity scan reds on `CANARY.md` in the canary commits.** The synthetic sentinel
   was committed to prove the scan fires, then removed; the pattern still matches it and the object
   still exists in history. The current *tree* is clean, which is why the tree scan is green.
2. **A credential scan of a *copy* of the fixture reds** (nine custom rules). The fixture itself is
   allowlisted, so the committed tree stays green — but if someone copies it elsewhere and scans,
   that is the canary working, not a leak.

**Do not "fix" either by rewriting history or deleting the fixture.** The sentinel is a nonsense
string and every fixture value is fake; both are deliberately-preserved evidence that the detectors
work. Removing them destroys the receipt to tidy a non-problem — and leaves the scanners unproven.

## Layers, honestly ranked

Hooks are **per-clone** and do not survive `git clone`; `--no-verify` bypasses them. **CI is the only
clone-surviving layer**, and it holds for what it is given: credential shapes, and the terms in the
`LEAK_PATTERN` secret. The shipped workflows run on pull requests and on pushes to `main` only, so a
push to any other branch with its hooks skipped gets no CI scan. For identity terms it is given
nothing (see Setup), so the local pre-push hook is the only identity layer. It reads more than the
files now, but still not all of a push.

| Layer | Reads, for marker terms | Does not read |
|---|---|---|
| pre-push, local list | the contents of the files in the tree at each pushed ref's tip, every line read as text whatever bytes it holds (invalid UTF-8, a NUL); every binary file any new commit adds, its bytes and UTF-16 text (the binary scan, where the project turns it on); and the metadata the push adds: the author and committer names and emails and the message of every new commit, every new tag object (tagger, name, message), and the names of the refs pushed, the tag objects and ref names matched in two passes (`LC_ALL=C` and the caller's locale), so a line holding invalid UTF-8 is read on BSD grep too | file names, and the text files of every commit between what the remote has and the pushed tip |
| leak-scan CI, the secret | the contents of the tracked files at the pushed commit, every line read as text whatever bytes it holds | file names, author and committer names and emails, commit messages, tag objects (tagger and message), ref names, and every commit but the pushed one; and under Setup the secret holds no identity term at all |

**So an identity term in a file name, or in a file that a later commit undoes, reaches the remote
with nothing checking it.** A file added in one commit and deleted in the next passes both layers;
both cases were probed with a canary from a real list, and both reached the remote. The push check reads
the files at the pushed tip, not each commit's, so a name added and removed within one push isn't caught.
**A project that pushes straight to a public remote runs the history check before each such push**:
`bin/kit-history-audit --control`, then `bin/kit-history-audit --remote origin` (in the install, beside these
hooks; "Before a repository goes public", below), which reads every commit reachable from any ref here, the ones
about to be pushed among them; it has no mode that reads a push's commits alone (decisions log §320). An identity term
in an author or committer field, a message, a tag object or a pushed ref's name is refused at push
(pre-push's metadata layer); in CI it is not read at all. Credential shapes are different: pre-push
runs gitleaks over the lines every new commit adds, not only the tip, and the binary scan, where it is
on, over the strings of every binary file they add. A merge commit counts as a new commit like any other: its own
changes are read as its diff against its first parent, which holds a conflict resolution and anything
else the merge adds that neither parent has (and the merged branch's lines again), and that diff goes
through gitleaks and the binary scan; its author, committer and message go through the metadata layer.
Until v0.11.0 pre-push refused every merge instead, and the only way past was `--no-verify`, which
skips every layer. CI's gitleaks directory scan reads no image: measured with
gitleaks 8.30.1, it skipped a `.png` by its extension, and caught the same bytes renamed `.txt`.

**The locale: text handling byte-wise, matching in the caller's.** pre-push, the CI scan, pre-commit,
`bin/kit-pin` and the binary scan save the locale they were started in and set `LC_ALL=C`, so their
text tools (`cut`, `awk`, `sed`, `sort` and the rest) read every line byte by byte: on a Mac, in a UTF-8
locale, BSD's `cut` stops on a line holding invalid UTF-8 and its `grep` doesn't match one (both measured).
Every matcher (the tree scans'
`git grep`, the metadata scan's `git log -i`, the allowlist filter, the binary scan's `git grep`) runs in
the saved locale, so `-i` folds a non-ASCII letter's case as that locale does: with `LANG` unset or `C`,
only ASCII letters fold, and a list row holding a letter outside ASCII blocks only the case it's
written in. pre-push matches ref names, tag objects and the file names it reports twice, under `LC_ALL=C`
and in the saved locale, and a match in either counts. A project's own checks run in the saved locale.
The binary scan names each binary it refuses or clears, but withholds a path the list matches, and so
does pre-commit's refusal of a staged `.local/` path (its list from `.git/leak-pattern`; with none, no
name is listed).
`tests/install_test.sh`'s LG1 fails a gate that misses the rule, and any matcher its allowlist doesn't
name.

## Before a repository goes public: the full-history identity check

This check is one step of the going-public checklist, `patterns/going-public.md`, which lists the rest.
The layers above read what each push adds; none reads all of history, so a term in a file name, or in
a file a later commit removed, can sit in a repository that was never refused. Before a repository is
made public or given a public remote, run `bin/kit-history-audit` (in the install, beside these hooks)
in it. It reads every commit reachable from any ref, and every one only its reflog still holds, against
the project's own list in `.git/leak-pattern`, checked against its pin (a list in the environment is
ignored): author and committer names and emails, messages, the paths each commit touches and the lines
it adds (binary files' too, and a merge's against its first parent), every tag object's tagger and
message, and every ref name, the remote's included (`--remote NAME`, `origin` by default when there is
one, `none` to skip). Each field is searched by `git grep` and by `grep`, each under `LC_ALL=C` and in
the caller's locale, so a line holding a NUL or invalid UTF-8 is read too. It prints counts, commit and
tag object hashes and field names only, never a matched line, a term or a path: to see a hit, look at
that commit's field yourself. It refuses (exit 3) on any hit but a content line the project's allow
file pins (`--allow FILE`: one line per occurrence, `COMMIT WHERE SHA256 PATH`, the commit's full hash,
one word for where the allowance was decided, the SHA-256 of the line's bytes without its newline, and
the path; nothing but content can be allowed). It stops (exit 1) when it can't see all of the history:
a remote ref whose commit isn't here, a shallow clone, grafts, a list that doesn't match its pin. Any
hit found should be rewritten out of the history before the repository goes public: a force-push hides
old commits but a forge may keep them.

Run its control first, on the same list: `bin/kit-history-audit --control` makes a term from every row
of the list, none printed, plants one in all ten fields of a throwaway repository and each row's in a
commit of its own, and passes only when the audit refuses all ten fields and every row's commit. A row it
can't make a term from (a back-reference, say) fails the control, named by number. A clean audit is
evidence only after its control has gone red. `tests/hooks_test.sh`
holds its cases (HA0 to HA29, HC1 to HC6).

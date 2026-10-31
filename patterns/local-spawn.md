# Pattern: local-spawn

Create a new project from a release of this kit **on one machine.**

A project that will live on a forge is made the same way, then given its remote: (a) below says what it
takes on when it gains one. Never make a project from a fork or a template of the kit's repository: that
copies the kit's own files into the project, which the next paragraph rules out.

A project is made from a release's **install** (`tools/install-release.sh` builds one from a clone of
the kit), never from the kit's working tree. It gets the files a project owns, and no copy of anything
the kit owns: its hooks and tools run from the install, pinned by `kit.pin`.

## Procedure

```bash
set -u
REL=vX.Y.Z                          # the kit release to make the project from; its install must exist
DST=/path/to/new-project
: "${REL:?}" "${DST:?}"             # both set and not empty, or stop here, before anything is touched
INST="${KIT_INSTALL_ROOT:-$HOME/.local/share/morrowcairn/releases}/${REL:?}"
# SHA-256 by sha256sum, else shasum -a 256 (a stock Mac has only shasum). With neither, kit_hash names both, MH is
# empty, and ${MH:?} stops the block here, before anything is made.
kit_hash() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; elif command -v shasum >/dev/null 2>&1; then shasum -a 256
             else echo "neither sha256sum (GNU coreutils) nor shasum (Perl) is installed" >&2; return 1; fi; }
MH=$(kit_hash < "${INST:?}/MANIFEST.sha256"); MH=${MH%% *}
"${INST:?}/bin/kit-pin" verify "${REL:?}" "sha256:${MH:?}"

# A destination that already holds files: list them, and decide each one BEFORE git init. Whatever
# is still here at commit one is one reflexive `git add -A` from the commit that cannot be rewritten.
# Move it out, ignore it (.gitignore, with a line saying why), or take it into the project on purpose.
if [[ -e "${DST:?}" ]]; then find "${DST:?}" -mindepth 1 -maxdepth 2 | sort; du -sh "${DST:?}"; fi

mkdir -p "${DST:?}"
# The files the release ships for a project to own: class "spawn" in the install's CLASSES (the CLAUDE.md
# template, records/, .gitignore), each under its own name, a template without its templates/ folder.
# Nothing kit-owned is copied, and no license. kit.forks and kit-pin.tests start as one comment line each.
awk '$1 == "spawn" {print $2}' "${INST:?}/CLASSES" | while read -r f; do
    t="${DST:?}/${f#templates/}"; mkdir -p "${t%/*}" && install -m 0644 "${INST:?}/$f" "$t" && echo "copied: ${f#templates/}"
done
echo '# Kit-owned files kept changed here, one per line: PATH  sha256:<64 hex>  §N  why' > "${DST:?}/kit.forks"
echo '# Test commands of this project, one per line; bin/kit-pin to runs them before it keeps a pin move' > "${DST:?}/kit-pin.tests"

cd "${DST:?}"
git init -b main                    # name the branch: the default is git's choice, not the kit's
"${INST:?}/bin/kit-pin" to "${REL:?}"   # BEFORE commit one: kit.pin and the stubs guard the commit that cannot be rewritten
# No do-not-publish list to start, the kit's default: the one line saying so, at the list's place, which the install's
# reader names from kit.list-id (never written over a file there), and its first pin.
( . "${INST:?}/leak-detection/read-leak-pattern.sh" && kit_list_file && set -C && umask 077 \
  && echo "LEAK_PATTERN='kit:no-identity-list'" > "${KL_FILE:?}" )
"${INST:?}/bin/kit-pin" repin local --first
echo "This project starts with no do-not-publish list: the one line saying so is at its place,"
echo "pinned, so its pushes say the do-not-publish check is off, and still scan for credentials."
echo "If it will hold terms you've agreed or are required to keep confidential, write them there"
echo "now and repin (patterns/local-spawn.md): nothing will remind you later."
echo "The identity guard is off: commit one goes under the identity git resolves here. patterns/repo-genesis.md says how"
echo "to check that identity, and how to turn the guard on."
# ...then patterns/repo-genesis.md (in the release's install): check the identity git will record, then commit one.
```

**Run the block whole, in one shell.** An agent's shell calls often keep no variables, so a piece of
the block run on its own starts with `REL` and `DST` empty. Every use is written `${VAR:?}` under
`set -u`, so such a piece stops at its first use. Without the guards, `cd ""` succeeded and stayed
put: a spawned instance found that an empty `DST` extracted the kit into whatever folder the shell
was in, and gave that folder's repository the placeholder identity. In a terminal of your own,
`set -u` stays on after the block; `set +u` turns it off.

**Pin before the first commit, not after.** A new repository has no hooks at all, and the first commit
is the one the hooks most need to see: nothing earlier can be rewritten away. `kit-pin to` writes
`kit.pin` and the two stubs in `.git/hooks`, which check the install against the pin on every commit
and push and then run the release's hooks. It also writes `kit.list-id`, a random id that names the
project's do-not-publish list, and makes the list's folder, `~/.config/morrowcairn/lists/` (mode 700; `~` the
home folder the user database gives): the list lives there, as `lists/<id>`, outside every repository,
the same file for every clone. Commit one carries `kit.list-id`. `to` prints where pre-push will read
the do-not-publish list from, or the next step if no list is set.

**Inventory a destination that is not empty.** The first spawned instance's destination already held
a folder of sixteen files that was not part of the project and that the kit's `.gitignore` does not
cover. Nothing in the procedure would have stopped `git add -A` from sweeping it into commit one. The
`find` above is the step: every item it lists is decided, one way or another, before `git init`.

**Name the branch at `git init`.** The default branch name is a per-machine git setting, and a spawn
whose `git init` produced `master` had to rename an unborn branch to match the kit's `main`.
`git init -b main` pins it.

**Two checks start off; below, how to turn on each.** The kit's default is the setup an organization's IT would
accept, so a new project starts with neither of these; the block says so as it ends.
- *The do-not-publish list.* The block writes the one line saying the project has none,
  `LEAK_PATTERN='kit:no-identity-list'`, at the list's place, and pins it. `bin/kit-pin check` (the install's:
  `"$INST/bin/kit-pin" check`) passes, saying the do-not-publish check is off; every push says so too and still scans for
  credentials. Ask once, now: **will this project hold terms you've agreed or are required to keep confidential?**
  Nothing reminds the project later. *Yes:* put the list in place of the line, then repin it, citing the § of the
  project's decisions log that records the decision (a change other than an append takes one). The write below refuses
  unless the file at the list's place holds that line alone, and only then replaces it, in one step, through a file
  beside it:
  ```sh
  ( f=~/.config/morrowcairn/lists/"$(cat kit.list-id)"
    [ "$(cat "$f" 2>/dev/null)" = "LEAK_PATTERN='kit:no-identity-list'" ] \
      || { echo "refused: $f doesn't hold the no-list line alone; nothing written" >&2; exit 1; }
    umask 077 && set -C && echo "LEAK_PATTERN='term1|term2'" > "$f.new" && mv "$f.new" "$f" )
  ```
  Then `"$INST/bin/kit-pin" repin local --ruling §N` (`leak-detection/README.md`, Setup and Changing the list). A
  project going public needs a real list: `bin/kit-history-audit` refuses the line.
- *The identity guard.* Commit one goes under the identity git resolves for this clone: the machine's, or the one its
  organization's IT sets. To turn the guard on, write `patterns/repo-genesis.md`'s sentinel identity in the clone
  before commit one (its step 1a): pre-commit then refuses every commit until a real identity is set and read back.
A project made before this release keeps its list and its identity as they are: moving it (`kit-pin to`) changes neither.
The project holds no hook suite: the kit's suites test the hooks before every release.

**Record where the kit lives.** Put the kit's location and the release you made the project from in
`.local/operator-notes.md`, under a `Kit` heading. `kit.pin` records the release too, tracked; the
notes say where the kit's repository is, which a restore needs (`bin/kit-pin restore`). A spawned
instance that did not record this later had its own kit mistaken for "not a separate repository" by
a session that could not find it.

Copying by the install's `CLASSES` means only files the kit ships for a project to own can ride along:
untracked scratch in the kit, its own front page and its own tests never reach the install, and its
kit-owned files stay in the install, run from there. A spawn that carried the kit's README presented
the kit as its front page at commit one, and one whose hook suite carried the kit's document tests
was red by construction, two cases on every run. **Inheriting another project's untracked files is
the same contamination class the kit warns about for inherited configs** — with the added problem
that untracked files are, by construction, the ones nobody reviewed.

**A new project starts with no license.** The kit's `LICENSE` covers the kit only (`kit-manifest.txt`
classes it `kit`), so the copy leaves it behind: a copy would name the kit's contributors as the new
project's copyright holder. A project with no license is all rights reserved, the safe default. Choose
the project's own license before it publishes anything.

## Then, before the first commit

1. Fill in the `CLAUDE.md` TODO blocks, or delete them. **A stale TODO reads as a fact.**
2. Write the project's `README.md`. The kit's stays in the kit (`kit-manifest.txt`): it describes
   the kit, and the spawn that carried it presented the kit as its own front page at commit one.
3. List the project's own test commands in `kit-pin.tests`, or leave the comment line: an empty list
   is a choice, written down. `kit-pin to` runs them before it keeps a later pin move.
4. Start `records/kit_feedback.md` the moment something is awkward — that file is how the kit
   improves, and it only works if entries are written at the moment of friction.

## Two consequences of having no remote — say them out loud

**(a) No CI runs.** The project holds no workflows, and with no remote nothing would run them anyway,
so **the pre-commit hook, through the stub, is the project's only live leak guard** — a per-clone
hook that a `--no-verify` bypasses. That is an acceptable posture for a private local project, and it
is *only* acceptable while it is **stated rather than assumed**.

If the project later gains a remote, take the files the install's `ci/copies.txt` lists: copy each
line's release file to its project path. That gives the project the `ci/` workflow variants (the
scans, none of the kit's own suites), `scan-tree.sh`, and `leak-detection/spawn.gitleaks.toml` as its
`.gitleaks.toml`, not the kit's own config, which exempts the kit's credential fixture by path. The
checked-copies layer keeps each equal to that release file, or declared in `kit.forks`, and refuses
the kit's own files there, naming the file each is held to. The identity scan then
**fails closed** until a `LEAK_PATTERN` secret exists. That is the correct order of events: the
guard arrives before the exposure.

**(b) `repo-genesis` still runs — but identity criticality is a property of the destination, not of
the pattern.** On a local-only project with no publication path, whatever identity the machine
already uses is usually fine. The **verify step still matters**, because its value was never solely
about identity: it is the habit of confirming a configured state rather than assuming it, and habits
that are skipped when stakes are low are not available when stakes are high.

Run the pattern. Note in the project's decisions log that the identity choice was deliberate and
why — a future reader finding a machine-default identity cannot otherwise tell "chosen" from
"never considered."

## Would revisit if:

The manifest's completeness test (in `tests/kit_docs_test.sh`) stops running before a release, or
the manifest starts naming files one by one outside `tests/`. A hand-maintained inventory is a promise
to update it that nobody keeps: the kit's own README once listed every file by name and
went stale in the same commit that added two of them. The manifest is an inventory too, but one whose
drift fails a test, and it names directories, so a new file usually needs no new line.

*Earlier conditions, retired:* "the kit gains machine-readable manifests that make copying selective
by declaration" was met by the manifest in v0.2.1. "`kit-manifest.txt` stops being a short list of
exceptions" was met on purpose when every tracked path was given a class: a file added without one
had been travelling to every spawn unreviewed. In v0.8.0 the copy reads the install's `CLASSES`,
which `tools/install-release.sh` writes from the manifest.

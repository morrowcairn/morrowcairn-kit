# Pattern: local-upgrade

Take a kit release into a project **on one machine**: the project moves its pin, and never copies a kit file.

From v0.8.0 a project holds no copy of what the kit owns. Its hooks and tools run from a release's
**install** (`tools/install-release.sh` builds one, read-only, from a tag the kit's remote has), and
`kit.pin`, tracked, says which install and holds the hash of its manifest. Two stubs in `.git/hooks`
check the install against the pin on every commit and push, then run the release's hooks. So a later
release is one command, and a project made before v0.8.0 moves onto an install once, below. The
project's own session does both; the kit's session writes nothing in a project.

## Taking a later release

```bash
"$INST/bin/kit-pin" to vX.Y.Z      # $INST: the install of the release you take, or of the one you hold
```

`kit-pin to` refuses a release with no install or one that fails its own manifest, a work tree with
uncommitted changes, a hooks path set in the clone itself, and a project with no `kit-pin.tests`. Under
an org's hooks path, set at the system or global level, it sets the clone's own path to the stubs, which
run the org's hooks first (`leak-detection/README.md`). It writes `kit.pin` and the stubs, keeping a
hook the project already has as `<hook>.project`, then runs the release's list reader's selftest, the checked-copies layer (every kit-owned file
the project still holds must equal the release's, or be declared in `kit.forks`), and each command in
`kit-pin.tests`. On any red it puts `kit.pin` and the stubs back byte for byte. On green it leaves
`kit.pin` for you to commit, and that commit runs through the new stubs.

## Moving a project made before v0.8.0 onto an install

A project made before v0.8.0 holds the kit-owned files it was given, and runs its hooks from a hooks
path (`core.hooksPath=leak-detection`, from v0.2.0) or from `.git/hooks` (v0.1.0). The move pins it,
switches git to the stubs, and removes the kit-owned copies, in that order.

### 0. Before you start

- The release's install exists (`tools/install-release.sh vX.Y.Z` in a clone of the kit).
- The project is committed and clean.
- `kit-pin.tests` lists the project's own test commands, one per line (a comment line alone is a
  choice, written down). Its own checks of a list, if it has any, move onto the install's reader first.
- Every kit-owned file the project changed and keeps is in `kit.forks`: the path, `sha256:` and the
  hash of the project's version, and the § of the project's decisions log that rules the fork. A fork
  with no § refuses, and so does one whose hash is stale. A file you changed but don't need to keep
  is simply removed with the rest. A CI workflow the project changed (a step of its own) is a fork
  too: declare it, or the move replaces it with the release's variant.
- A project's CI files are kept, not removed: each path the install's `ci/copies.txt` names that the
  project holds becomes the release's file for a project. Its workflows become the `ci/` variants,
  which run the scans and none of the kit's own suites. Its `.gitleaks.toml` becomes the spawn config,
  never the kit's own, which exempts the kit's credential fixture by path.

### 1. The list reader's value

The install's reader must read the project's live list to the same value the project's own reader
does, or the move changes what the hooks scan for. Compared in memory; nothing is printed.

```bash
set -u
REL=vX.Y.Z                    # the release to move onto
DST=/path/to/project          # the project, committed and clean
: "${REL:?}" "${DST:?}"
INST="${KIT_INSTALL_ROOT:-$HOME/.local/share/morrowcairn/releases}/${REL:?}"
lp="$(git -C "${DST:?}" rev-parse --absolute-git-dir)/leak-pattern"
new=$(bash -c '. "$1" && read_leak_pattern "$2" && printf "%s" "$LP_VALUE"' _ "${INST:?}/leak-detection/read-leak-pattern.sh" "$lp")
if grep -q '^read_leak_pattern() {' "${DST:?}/leak-detection/pre-push" 2>/dev/null; then   # v0.7.0: in pre-push
    f=$(mktemp); sed -n '/^read_leak_pattern() {/,/^}/p' "${DST:?}/leak-detection/pre-push" > "${f:?}"
    old=$(bash -c '. "$1" && read_leak_pattern "$2" && printf "%s" "$LP_VALUE"' _ "${f:?}" "$lp"); rm -f "${f:?}"
else                                                                 # v0.6.0 and older ran the file as shell
    old=$(bash -c 'unset LEAK_PATTERN; . "$1" >/dev/null 2>&1; printf "%s" "${LEAK_PATTERN-}"' _ "$lp")
fi
if [[ -n "$new" && "$new" == "$old" ]]; then echo "list reader: the same value"; else echo "STOP: the readers disagree, or one read nothing"; fi
unset new old
```

A `STOP` goes back to whoever owns the list before anything moves: a project whose checks fingerprint
the list's value would see every fingerprint lapse.

### 1b. The list's pins

From v0.9.0 pre-push refuses unless the identity list is the one its pin names, and CI's scan refuses unless
the `LEAK_PATTERN` secret is the one its tracked pin names (`leak-detection/README.md`, Setup). A project takes
both pins in this move. First check the list against a source it didn't come from, never against itself: rows
copied from another list (the kit's, say) by exact text against that list, and the project's own rows against
the records of their addition (its decisions log). Count only: print no row. The check is the session's, and
it is recorded in step 4.

```bash
set -u
REL=vX.Y.Z                    # the release to move onto
DST=/path/to/project          # the project, its list checked as above
: "${REL:?}" "${DST:?}"
INST="${KIT_INSTALL_ROOT:-$HOME/.local/share/morrowcairn/releases}/${REL:?}"
cd "${DST:?}"
"${INST:?}/bin/kit-pin" repin local --first      # .git/leak-pattern.pin, untracked, beside the list
# A project with CI: the LEAK_PATTERN secret's exact value, kept untracked in .git/leak-pattern.ci with no trailing
# newline; its pin, .github/leak-pattern.pin, is committed with the move.
if [[ -f .github/workflows/leak-scan.yml ]]; then "${INST:?}/bin/kit-pin" repin ci --first; fi
```

A project with no identity terms of its own pins the list it has, the terms that identify no one.

### 2. Move onto the install

```bash
set -u
REL=vX.Y.Z                    # the release to move onto
DST=/path/to/project          # the project, committed and clean, with kit-pin.tests and kit.forks written
: "${REL:?}" "${DST:?}"
INST="${KIT_INSTALL_ROOT:-$HOME/.local/share/morrowcairn/releases}/${REL:?}"
cd "${DST:?}"
# The stubs into .git/hooks (any hooks there kept as <name>.pre-kit-pin), kit.pin, the hooks path unset, and
# kit-pin check at once; on a red check everything goes back. Check's exit 3, every push refused until the list and
# its pin agree, keeps the switch: step 1b was skipped or its pin is stale, and the rest still runs. Then, in one
# commit through the stubs: each file the project keeps for its CI (the install's ci/copies.txt) becomes the
# release's file for a project (its ci/ variant, the spawn config, scan-tree.sh); the doctrine copies (skills/,
# .claude/skills/) become the release's, since the stubs refuse a commit while a kit-owned copy differs from the
# release, and step 3 removes them; every other kit-owned copy goes; CI's pin goes in. A fork kit.forks declares stays
# as it is.
"${INST:?}/bin/kit-pin" migrate "${REL:?}"; rc=$?
(( rc == 0 || rc == 3 )) && {
    forked() { awk -v f="$1" '$1 == f {k = 1} END {exit !k}' kit.forks 2>/dev/null; }
    kept() { awk -v f="$1" '$1 == f {k = 1} END {exit !k}' "${INST:?}/ci/copies.txt"; }
    while read -r mine theirs _; do
        [[ -z "$mine" || "$mine" == \#* || ! -e "$mine" ]] && continue
        forked "$mine" && continue
        m=0644; [[ -x "${INST:?}/$theirs" ]] && m=0755
        install -m "$m" "${INST:?}/$theirs" "$mine" && git add -- "$mine"
    done < "${INST:?}/ci/copies.txt"
    awk '$1 == "owned" {print $2}' "${INST:?}/CLASSES" | while read -r f; do
        [[ -e "$f" ]] && ! kept "$f" && ! forked "$f" || continue
        case "$f" in
            skills/*|.claude/skills/*) install -m 0644 "${INST:?}/$f" "$f" && git add -- "$f" ;;   # until step 3
            *) git rm -q -- "$f" ;;
        esac
    done
    git add kit.pin kit-pin.tests && { [[ ! -f kit.forks ]] || git add kit.forks; } \
        && { [[ ! -f .github/leak-pattern.pin ]] || git add .github/leak-pattern.pin; }
    git commit -q -m "Onto kit ${REL:?}: pinned to its install, hooks from the stubs, CI held to the release, other kit-owned copies removed"
}
```

Run it whole: its second half depends on the first. If `migrate` refuses, nothing is removed. If it finishes
with exit 3, the move is made and every push is refused until the list and its pin agree: do step 1b, then
`"$INST/bin/kit-pin" check` passes with exit 0.

### 3. The doctrine

On a machine whose user-level `CLAUDE.md` imports the kit's doctrine from the pinned install, and holds
its triggered skills (the kit's design, section k), the project's copies are a second load of the same
rules. Once that user-level step has run, remove the project's `@skills/...` lines from its `CLAUDE.md`,
and its `skills/` and `.claude/skills/` copies, in one commit through the stubs. Before it has run they
are the project's only doctrine, so they stay, as the release's copies step 2 made them.

### 4. Record

A line in the project's decisions log: the release, the reader comparison's result, the first pins (the rows of
each, and what the local list was checked against), the forks and the §s that rule them, and the commit. The kit's location and the release go in `.local/operator-notes.md`
under `Kit`; a restore (`bin/kit-pin restore <kit clone>`) needs the clone.

## A LICENSE the kit copied in

Releases through v0.8.0 copied the kit's own `LICENSE` into every new project: the Apache-2.0 text,
with the kit's copyright line, "Copyright 2026 Morrowcairn contributors". Later releases don't copy it:
the kit's `LICENSE` covers the kit only (`kit-manifest.txt` classes it `kit`). A project that carries
that file byte for byte didn't choose it; it was copied in. In the project:

```bash
# SHA-256 by sha256sum, else shasum -a 256 (a stock Mac has only shasum); with neither, it names both and says no more.
kit_hash() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; elif command -v shasum >/dev/null 2>&1; then shasum -a 256
             else echo "neither sha256sum (GNU coreutils) nor shasum (Perl) is installed" >&2; return 1; fi; }
[[ -f LICENSE ]] && h=$(kit_hash < LICENSE) && [[ "${h%% *}" == 1eba867c29a6e5d920f993266e344d847a7046dab968762b7349d09e3bbdb42e ]] \
    && echo "LICENSE is the kit's Apache-2.0 file, copied in at spawn: the project's owner decides"
```

If it is, the project's owner decides whether to keep a license, and which one. Neither path above
moves, changes or removes it: the move removes kit-owned copies only, and `LICENSE` never was one.
Record the decision in the project's decisions log.

## Would revisit if:

A release needs a project to hold a file the kit owns, beyond a declared fork or a CI checked copy; or
installs stop being read-only and hash-checked, so a pin no longer says exactly what runs.

*Earlier, retired in v0.8.0:* the copy-based upgrade (a plan comparing a project's kit-owned files at
its release and the next, then an apply that copied them). A project holds no kit-owned copies now, so
there is nothing to compare or copy; its procedure is in this file's history.

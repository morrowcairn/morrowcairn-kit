#!/usr/bin/env bash
#
# load_check_test.sh — tests for the daily load check (bin/kit-load-check) and its stub (bin/kit-load-check-stub),
# which watch that the user level still loads the kit's rules file and skills from the pinned install.
#
#   tests/load_check_test.sh [ROOT]    ROOT = a checkout of this kit (default: the one holding this file)
#
# Every case works under a temp dir: an install built from ROOT's staged tree (its hook suite replaced by a stand-in,
# as install_test's v1.0.0, and a stand-in rules file added), the kit's user pin, the user-level rules entry linked to
# the install's rules file, a user-level CLAUDE.md that imports no kit file, user-level skill entries, and a stand-in
# `claude` for the headless probe. No real session, transcript, ping or Claude Code run is touched. The check
# reads no transcript; the SYNTHETIC transcripts some cases write, and the one the stand-in
# claude writes as a run without --no-session-persistence would, are there to show they no longer affect the result
# (LQ5). The stand-in refuses a probe run without that flag (LC14).
#
# Each failing case must fail for its stated reason and only that one: the report names every reason it failed, so
# a check that lost one test but failed another would otherwise stay red for the wrong reason. Exit 0 only when every
# case passed AND at least one case ran.
#
set -uo pipefail

ROOT=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd) || exit 1
command -v python3 >/dev/null 2>&1 || { echo "load_check_test: python3 is required" >&2; exit 1; }
# Under Git Bash, python3 is a Windows program: it reads paths in Windows form and starts only Windows programs, and the
# load check is python3. native prints a path the way that python3 reads it.
PY_OS=$(python3 -I -c 'import os; print(os.name)' 2>/dev/null | tr -d '\r')
native() { if [[ "$PY_OS" == nt ]]; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
TMP=$(mktemp -d) || exit 1
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL="$TMP/global.gitconfig" GIT_CONFIG_NOSYSTEM=1; : > "$GIT_CONFIG_GLOBAL"
PASS=0; FAIL=0; SKIP=0
result() { if [[ $2 -eq 0 ]]; then PASS=$((PASS+1)); printf 'ok    %s\n' "$1"
           else FAIL=$((FAIL+1)); printf 'FAIL  %s  -- %s\n' "$1" "$3"; fi; }
skip() { SKIP=$((SKIP+1)); printf 'skip  %s  -- %s\n' "$1" "$2"; }
want_ok() { if [[ $2 -eq 0 && ( -z "${4:-}" || "$3" == *"$4"* ) ]]; then result "$1" 0
            else result "$1" 1 "exit $2${4:+, want '$4'}: $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-200)"; fi; }
sha() { local s; s=$(sha256sum < "$1") && printf '%s' "${s%% *}"; }

CASES=(LC0 LC0b LC16 LC4 LC5 LC7 LC8 LC9 LCe LC12 LC13 LC13b LC13c LC13d LC14 LC15 LQ2 LQ2b LQ4 LQ5 LCa LCb LCc LCd LCf LCg
       LQ1 LS1 LS2 LS3 LS4 LS5 LS6 LS6b LS7 LS8 LP3 LS14 LS14b LP1a LP1b LP1c LP1d LP1e LP2a LP2b LP2c LP2d LP2e LP2f LP2g
       LP2h LS13 LS9 LS10 LS11 LS11b LS12 EG25 EG26 EG27 LP1f LP3b LP4)
if ! git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null 2>&1; then
    for c in "${CASES[@]}"; do skip "$c" "no commits yet in $ROOT: rerun after commit one"; done
    echo; echo "load_check_test: $PASS passed, $FAIL failed, $SKIP skipped"; exit 0
fi

# ============================== an install, a user-level file, skills, a projects folder =======
export KIT_INSTALL_ROOT="$TMP/releases"; mkdir -p "$KIT_INSTALL_ROOT"
K="$TMP/kit"; git init -q -b main "$K"; git -C "$ROOT" checkout-index -a --prefix="$K/"
printf '#!/usr/bin/env bash\necho "hooks_test: a stand-in"\n' > "$K/tests/hooks_test.sh"
# A stand-in for the kit's rules file, the one file the user level loads from the install.
mkdir -p "$K/rules"; printf '# A stand-in rules file\n\nLoad canary: kc-5a17e0aa00c0ffee\n' > "$K/rules/morrowcairn.md"
git -C "$K" add -A && git -C "$K" -c user.name=t -c user.email=t@invalid.local -c core.hooksPath=/dev/null commit -q -m kit
git -C "$K" -c user.name=t -c user.email=t@invalid.local tag -a v1.0.0 -m v1.0.0
git init -q --bare "$TMP/kit-remote.git"; git -C "$K" remote add origin "$TMP/kit-remote.git"
git -C "$K" push -q --no-verify origin v1.0.0 2>/dev/null
(cd "$K" && tools/install-release.sh v1.0.0) > "$TMP/install.log" 2>&1 || echo "load_check_test: the install could not be built: $(tail -n 1 "$TMP/install.log")" >&2
I="$KIT_INSTALL_ROOT/v1.0.0"; PRISTINE="$TMP/pristine"; cp -a "$I" "$PRISTINE" 2>/dev/null
reset_i() { chmod -R u+w "$I" 2>/dev/null; rm -rf "${I:?}"; cp -a "$PRISTINE" "$I" 2>/dev/null; }
H="sha256:$(sha "$I/MANIFEST.sha256" 2>/dev/null)"
IMPORTS=(rules/morrowcairn.md .claude/skills/gates/SKILL.md)   # what the synthetic transcripts list (LQ1, LQ5): files the install has
canary() { grep -oE 'kc-[0-9a-f]{16}' "$I/$1" 2>/dev/null | head -n 1; }

# The user level, as kit-pin's user mode leaves it: the kit's own pin, in a file of the kit's
# own; the rules entry, a link to the install's rules file; and the person's own CLAUDE.md, which imports no kit file.
RULES=rules/morrowcairn.md
UPIN="$TMP/hm/.config/morrowcairn/user.pin"; mkdir -p "${UPIN%/*}"
userpin() { printf 'release=%s\nmanifest=%s\n' "${1:-v1.0.0}" "${2:-$H}" > "$UPIN"; }   # [RELEASE] [HASH]
userpin
RF="$TMP/hm/.claude/rules/morrowcairn.md"; mkdir -p "${RF%/*}"
rules() { rm -f "$RF"; ln -s "$I/$RULES" "$RF"; }
rules
UF="$TMP/hm/.claude/CLAUDE.md"; mkdir -p "${UF%/*}"
userfile() {  # [an import line naming a kit file of RELEASE]
    { printf '# the user-level file\n\nA rule of the person'"'"'s own.\n'
      [[ -z "${1:-}" ]] || printf '@%s/%s\n' "$(native "${KIT_INSTALL_ROOT}/$1")" "${IMPORTS[1]}"; } > "$UF"; }
userfile
SK="$TMP/hm/.claude/skills"; mkdir -p "$SK"
skills() { rm -rf "${SK:?}"/*; local d; for d in "$I"/.claude/skills/*/; do d=${d%/}; ln -s "$d" "$SK/${d##*/}"; done; }
skills
P="$TMP/hm/.claude/projects"; mkdir -p "$P"
PROBE="$TMP/hm/.local/state/morrowcairn/load-probe"

# A synthetic transcript: one instructions attachment listing the user-level file, the imports (each with its
# canary unless named in DROP or BLANK) and a project file, then one model turn; VERSION on every line. The no-turn
# shapes: localonly, two local commands and nothing else, as an abandoned /color and /rename leave
# it; localthen, those commands and then the full session; synthetic, a prompt answered only by Claude Code's own
# API-error record (model <synthetic>); noturn:<rel>, an instructions record without that import and no model turn.
transcript() {  # FILE VERSION [MODE]   MODE: full (default), noimport:<rel>, nocanary:<rel>, nouser, noattach, garbage,
                #                        localonly, localthen, synthetic, noturn:<rel>
    local f=$1 v=$2 mode=${3:-full}; mkdir -p "${f%/*}"
    python3 -I - "$f" "$v" "$mode" "$UF" "$I" "${IMPORTS[@]}" <<'PY'
import json, sys, datetime
f, v, mode, uf, inst, *imports = sys.argv[1:]
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
if mode == "garbage":
    open(f, "w").write("this is not json\n{\"half\": \n")
    sys.exit(0)
lines = []
if mode in ("localonly", "localthen"):
    for cmd, out in (("/color", "Session color set to: blue"), ("/rename", "Session renamed to: zq")):
        lines.append({"type": "system", "subtype": "local_command", "timestamp": now, "version": v,
                      "content": f"<command-name>{cmd}</command-name>"})
        lines.append({"type": "system", "subtype": "local_command", "timestamp": now, "version": v,
                      "content": f"<local-command-stdout>{out}</local-command-stdout>"})
if mode == "synthetic":
    lines.append({"type": "user", "timestamp": now, "version": v, "message": {"content": "hello"}})
    lines.append({"type": "assistant", "timestamp": now, "version": v, "isApiErrorMessage": True,
                  "message": {"model": "<synthetic>", "content": [{"type": "text", "text": "API Error"}]}})
if mode in ("localonly", "synthetic"):
    with open(f, "w") as out:
        for l in lines:
            out.write(json.dumps(l) + "\n")
    sys.exit(0)
files = []
if mode != "nouser":
    files.append({"path": uf, "type": "User", "content": open(uf).read()})
for rel in imports:
    if mode in ("noimport:" + rel, "noturn:" + rel) or mode == "nouser":
        continue
    text = open(f"{inst}/{rel}").read()
    if mode == "nocanary:" + rel:
        text = "\n".join(l for l in text.splitlines() if "kc-" not in l)
    files.append({"path": f"{inst}/{rel}", "type": "User", "content": text})
files.append({"path": "/some/project/CLAUDE.md", "type": "Project", "content": "# a project"})
lines.append({"type": "user", "timestamp": now, "version": v, "message": {"content": "hello"}})
if mode != "noattach":
    lines.append({"type": "attachment", "timestamp": now, "version": v, "attachment": {"type": "instructions", "files": files}})
if not mode.startswith("noturn:"):
    lines.append({"type": "assistant", "timestamp": now, "version": v,
                  "message": {"model": "claude-zq-test", "content": [{"type": "text", "text": "hi"}]}})
with open(f, "w") as out:
    for l in lines:
        out.write(json.dumps(l) + "\n")
PY
}
fresh_projects() { rm -rf "${P:?}"; mkdir -p "$P"; }
# The helper's own input holds: every file it lists is in the install, so a transcript is written, not a traceback in
# its place (two files v0.12.0 retired were listed once, and every probe run printed a FileNotFoundError).
fresh_projects; lq1=$(transcript "$P/-q/q1.jsonl" 2.1.290 2>&1); [[ -s "$P/-q/q1.jsonl" && -z "$lq1" ]]
result "LQ1 the synthetic transcript helper writes its transcript, every file it lists in the install" $? "helper said: $(printf '%s' "$lq1" | tr '\n' ' ' | cut -c1-200)"
fresh_projects
# A transcript the freeze damaged: transcript's lines with a line of NUL bytes after the first, the shape the 10-19
# freeze left in four transcripts on one machine.
damaged() {  # FILE VERSION
    transcript "$1" "$2"
    python3 -I - "$1" <<'PY'
import sys
f = sys.argv[1]; lines = open(f, "rb").read().split(b"\n")
open(f, "wb").write(b"\n".join(lines[:1] + [b"\0" * 40] + lines[1:]))
PY
}
# A stand-in claude for the probe. FAKE_MODE: pass, auth, timeout, nocanary, exit93 (no answer, exit status 93),
# zqanswer (an answer and error output holding a stand-in term, no canary). It answers as `claude -p --output-format
# json` does and writes the transcript a real run would, under the projects folder.
FB="$TMP/fakebin"; mkdir -p "$FB"
cat > "$FB/claude" <<'SH'
#!/usr/bin/env bash
printf '%s' "${KIT_LOAD_PROBE:-unset}" > "$FAKE_SEEN"     # the probe marker, as this process sees it
printf '%s\0' "$@" > "$FAKE_ARGS"                         # the probe's arguments, NUL-separated (LC14)
compgen -e > "$FAKE_ENV"                                  # the names in its environment, never their values (LC15)
case " $* " in *" --no-session-persistence "*) ;;          # a probe run keeps no session on disk
  *) echo "the stand-in claude: no --no-session-persistence, so this run's session would stay on disk" >&2; exit 94 ;; esac
case "${FAKE_MODE:-pass}" in
  auth)    echo '{"type":"result","subtype":"success","is_error":true,"result":"Invalid API key · Please run /login"}'; exit 1 ;;
  timeout) sleep 30; exit 0 ;;
  exit93)  exit 93 ;;
  zqanswer) echo 'zqplant-stderr' >&2; echo '{"type":"result","subtype":"success","is_error":false,"result":"zqplant-answer"}'; exit 0 ;;
esac
sid=0b0e5a5e-0000-4000-8000-$(printf '%012d' $$)
mode=full; [[ "${FAKE_MODE:-pass}" == nocanary ]] && mode="nocanary:rules/morrowcairn.md"
slug=$(python3 -I -c 'import os, re; print(re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(os.getcwd())))' | tr -d '\r')   # as the check names it
bash "$FAKE_TRANSCRIPT" "$FAKE_PROJECTS/$slug/$sid.jsonl" "${FAKE_VERSION:-2.1.291}" "$mode"
answer=$(grep -ohE 'kc-[0-9a-f]{16}' $FAKE_ANSWER_FILES | sort -u)
[[ "${FAKE_MODE:-pass}" == nocanary ]] && answer="the rules file did not load"
python3 -I -c 'import json,sys; print(json.dumps({"type":"result","subtype":"success","is_error":False,"result":sys.argv[1],"session_id":sys.argv[2]}))' "$answer" "$sid"
SH
chmod +x "$FB/claude"
# A Windows python3 can't start a script: there the probe gets a .cmd that hands its arguments to bash and the stand-in.
CLAUDE_AT=""
if [[ "$PY_OS" == nt ]]; then
    printf '@"%s" "%s" %%*\r\n' "$(cygpath -w "$(command -v bash)")" "$(cygpath -w "$FB/claude")" > "$FB/claude.cmd"
    CLAUDE_AT="KIT_CLAUDE=$(cygpath -w "$FB/claude.cmd")"
fi
# The stand-in calls this to write its transcript (the same synthetic form as above).
{ echo 'set -uo pipefail'; declare -f transcript; echo 'UF='"'$UF'"; echo 'I='"'$I'"; echo "IMPORTS=(${IMPORTS[*]})"; echo 'transcript "$@"'; } > "$TMP/write_transcript.sh"
export FAKE_TRANSCRIPT="$TMP/write_transcript.sh" FAKE_PROJECTS="$P" FAKE_ANSWER_FILES="$I/$RULES"
export FAKE_SEEN="$TMP/probe-seen" FAKE_ARGS="$TMP/probe-args" FAKE_ENV="$TMP/probe-env"

STUB="$ROOT/bin/kit-load-check-stub"
REPORT="$TMP/report.txt"
# Run the check through its stub, as the cron line does. Prints the report; returns the stub's exit status. The stub
# runs from LC_STUB under LC_BASH: the pass-point cases (EG25 on) set them for copies of it and for bash 3.
LC_BASH=bash; LC_STUB=$STUB; LC_ARGS=()
lc() {  # [ENV=VALUE...]; LC_ARGS, more of the check's own arguments
    rm -f "$REPORT"
    env -u CLAUDE_CONFIG_DIR -u KIT_USER_PIN -u KIT_USER_CLAUDE_MD HOME="$TMP/hm" XDG_CONFIG_HOME="$TMP/hm/.config" \
        KIT_LOAD_CHECK_REPORT="$REPORT" PATH="$FB:$PATH" ${CLAUDE_AT:+"$CLAUDE_AT"} "$@" \
        "$LC_BASH" "$LC_STUB" --skills "$SK" --rules "$RF" --probe-dir "$PROBE" --timeout 5 ${LC_ARGS[@]+"${LC_ARGS[@]}"} > "$TMP/lc.out" 2>&1
    local rc=$?; cat "$REPORT" 2>/dev/null; return $rc; }
# NAME RC REPORT REASON...: the run failed, its report says FAIL, and its fail lines are exactly the REASONs given.
fails_for() { local name=$1 rc=$2 rep=$3; shift 3
    local got want; got=$(printf '%s\n' "$rep" | grep '^fail: ' | sort); want=$(printf 'fail: %s\n' "$@" | sort)
    if [[ $rc -ne 0 && "$rep" == *"kit load check: FAIL"* && "$got" == "$want" ]]; then result "$name" 0
    else result "$name" 1 "exit $rc; want [$(echo $want)]; got [$(echo $got)] $(head -c 160 "$TMP/lc.out" | tr '\n' ' ')"; fi; }
passes() { if [[ $2 -eq 0 && "$3" == *"kit load check: PASS"* && "$3" != *"fail: "* ]]; then result "$1" 0
           else result "$1" 1 "exit $2: $(printf '%s' "$3" | tr '\n' ' ' | cut -c1-200) $(head -c 160 "$TMP/lc.out" | tr '\n' ' ')"; fi; }

# ============================== the load check ==================================================
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290; transcript "$P/-b/s2.jsonl" 2.1.291
rep=$(lc); rc=$?;                              passes "LC0 a passing probe, its answer holding every import's canary, and every skill linked: PASS" $rc "$rep"
{ [[ -n "$rep" ]] && ! grep -qE "kc-[0-9a-f]{16}" <<<"$rep" && ! grep -qF "$TMP" <<<"$rep"; }
                                               want_ok "LC0b the report holds no canary and no absolute path" $? "$rep"
# The check sees that each skill is linked or copied, not that it loads: its probe asks for the rules file's canary
# alone, so a lock on skills goes unnoticed by it. Its report says so, rather than claim more than it checks.
[[ "$rep" == *"skills: gates linked"*"; whether they load isn't checked"* ]]
                                               want_ok "LC16 the report says the skills are linked, and that whether they load isn't checked" $? "$rep"
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
rep=$(lc FAKE_MODE=auth); rc=$?;               fails_for "LC4 a probe that can't authenticate fails, for auth" $rc "$rep" "probe: auth"
rep=$(lc FAKE_MODE=timeout); rc=$?;            fails_for "LC5 a probe that runs past its time fails, for timeout" $rc "$rep" "probe: timeout"
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
rm "$SK/gates"; ln -s "$TMP" "$SK/gates"
rep=$(lc); rc=$?;                              fails_for "LC7 a user-level skill whose link points elsewhere fails" $rc "$rep" "skill gates: its link points elsewhere than the pinned install"
skills; rm "$SK/record-stamps"; mkdir -p "$SK/record-stamps"; { cat "$I/.claude/skills/record-stamps/SKILL.md"; echo "an edit"; } > "$SK/record-stamps/SKILL.md"
rep=$(lc); rc=$?;                              fails_for "LC8 a user-level skill copy that differs from the pinned install fails" $rc "$rep" "skill record-stamps: its copy differs from the pinned install"
skills; rm -rf "$SK/record-stamps"; mkdir -p "$SK/record-stamps"; cp "$I/.claude/skills/record-stamps/SKILL.md" "$SK/record-stamps/"
fresh_projects; rep=$(lc); rc=$?;           passes "LC9 a skill copy that matches the pinned install passes" $rc "$rep"
skills; fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
rep=$(lc FAKE_MODE=nocanary); rc=$?;           fails_for "LCe a probe whose answer lacks the rules file's canary fails, naming the rules file" $rc "$rep" "probe: missing from the answer: $RULES"
# The user level's rules entry is the kit's link into the pinned install, or a byte-equal copy: missing, linked into another release, or a copy that differs, it fails, as a skill entry does. And a
# user-level CLAUDE.md that still imports a kit file loads the kit a second way, from whichever release it names, so it
# fails too: the kit loads from the rules folder alone.
fresh_projects; rm -f "$RF"; rep=$(lc); rc=$?; fails_for "LCa a missing user-level rules entry fails" $rc "$rep" "no rules file at user level"
mkdir -p "$KIT_INSTALL_ROOT/v0.0.1/rules"; cp "$I/$RULES" "$KIT_INSTALL_ROOT/v0.0.1/$RULES"; ln -s "$KIT_INSTALL_ROOT/v0.0.1/$RULES" "$RF"
rep=$(lc); rc=$?;                              fails_for "LCb a rules link into another release fails, naming it" $rc "$rep" "the rules link points into v0.0.1; the pin names v1.0.0"
rm -rf "${KIT_INSTALL_ROOT:?}/v0.0.1"; rm -f "$RF"; { cat "$I/$RULES"; echo "an edit"; } > "$RF"
rep=$(lc); rc=$?;                              fails_for "LCc a rules copy that differs from the pinned install fails" $rc "$rep" "the rules file's copy differs from the pinned install"
rm -f "$RF"; cp "$I/$RULES" "$RF"
rep=$(lc); rc=$?;                              passes "LCf a rules copy that matches the pinned install passes" $rc "$rep"
rules; userfile v1.0.0
rep=$(lc); rc=$?;                              fails_for "LCd a user-level CLAUDE.md that still imports a kit file fails, naming it" $rc "$rep" "the user-level CLAUDE.md still imports a kit file (v1.0.0/${IMPORTS[1]}); the kit's rules load from the rules folder"
rm -f "$UF"; rep=$(lc); rc=$?;                 passes "LCg with no user-level CLAUDE.md at all, the check passes" $rc "$rep"
userfile
# The probe carries a marker, KIT_LOAD_PROBE=1, set for its process alone: if the hooks-off setting doesn't keep the
# user-level hooks quiet in a real run, they can skip any run that carries it (a hooks edit, outside the kit).
fresh_projects; rm -f "$FAKE_SEEN"; rep=$(lc); rc=$?
[[ "$(cat "$FAKE_SEEN" 2>/dev/null)" == 1 && -z "${KIT_LOAD_PROBE:-}" ]] || rc=1
                                               passes "LC12 the probe process carries KIT_LOAD_PROBE=1, and the stand-in claude sees it" $rc "$rep"
# The probe never gets a tool that can act: its hooks are off only because no guard can fire without one. Its
# invocation must hold one empty --tools, --strict-mcp-config and one --settings with disableAllHooks true, and no
# other flag that names tools or MCP servers. The stand-in recorded the arguments.
fresh_projects; rm -f "$FAKE_ARGS"; rep=$(lc); rc=$?
why=$(python3 -I - "$FAKE_ARGS" <<'PY'
import json, sys
try:
    a = [x.decode() for x in open(sys.argv[1], "rb").read().split(b"\0")[:-1]]
except OSError:
    print("no arguments recorded"); sys.exit(1)
bad = []
t = [i for i, x in enumerate(a) if x == "--tools"]
if len(t) != 1 or t[0] + 1 >= len(a) or a[t[0] + 1] != "":
    bad.append("--tools is not one empty value")
if any(x.startswith(("--tools=", "--allowedTools", "--allowed-tools", "--mcp-config")) for x in a):
    bad.append("another tool or MCP flag")
if "--strict-mcp-config" not in a:
    bad.append("no --strict-mcp-config")
if "--no-session-persistence" not in a:
    bad.append("no --no-session-persistence")
s = [i for i, x in enumerate(a) if x == "--settings"]
try:
    hooks_off = len(s) == 1 and json.loads(a[s[0] + 1]).get("disableAllHooks") is True
except (IndexError, ValueError, AttributeError):
    hooks_off = False
if not hooks_off:
    bad.append("disableAllHooks is not true in one --settings")
if bad:
    print("; ".join(bad)); sys.exit(1)
PY
) || rc=1
if [[ $rc -eq 0 && "$rep" == *"kit load check: PASS"* ]]; then result "LC14 the probe gets no tool and keeps no session: one empty --tools, --strict-mcp-config, disableAllHooks, --no-session-persistence" 0
else result "LC14 the probe gets no tool and keeps no session: one empty --tools, --strict-mcp-config, disableAllHooks, --no-session-persistence" 1 "exit $rc; ${why:-the run did not pass}"; fi
# One Healthchecks check, one ping per run: its URL on a pass, its /fail route on a fail. A stand-in server counts. It
# answers GET /ready without counting, and the runs start only once it has: a server not up within the limit fails
# LC13 as not ready, never as a missing ping. The old wait gave the server 5 seconds to write its port, and a macOS
# runner once took longer.
cat > "$TMP/hc.py" <<'PY'
import http.server, sys, time
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        ready = self.path == "/ready"
        self.send_response(200 if ready else 404); self.end_headers()
        if ready:
            self.wfile.write(b"zq-ready")
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with open(sys.argv[2], "a") as f:
            f.write(self.path + "\n")
        with open(sys.argv[2] + ".body", "ab") as f:       # what each ping carried (LP2)
            f.write(body + b"\n")
        self.send_response(200); self.end_headers(); self.wfile.write(b"OK")
    def log_message(self, *a):
        pass
time.sleep(float(sys.argv[3]))                    # a slow start, for LC13b and LC13d
s = http.server.HTTPServer(("localhost", 0), H)
open(sys.argv[1], "w").write(str(s.server_address[1]))
s.serve_forever()
PY
hc_start() {  # DELAY: start the stand-in server, its start held back DELAY seconds
    rm -f "$TMP/hc.port" "$TMP/hc.hits" "$TMP/hc.hits.body"; python3 -I "$TMP/hc.py" "$TMP/hc.port" "$TMP/hc.hits" "$1" & HC=$!; }
hc_stop() { kill "$HC" 2>/dev/null; wait "$HC" 2>/dev/null; }
hc_ready() {  # LIMIT: 0 once the server answers GET /ready, printing the seconds it took; 1 if not within LIMIT seconds
    python3 -I - "$TMP/hc.port" "$1" <<'PY'
import sys, time, urllib.request
get = urllib.request.build_opener(urllib.request.ProxyHandler({})).open
t0 = time.monotonic()
while time.monotonic() - t0 < float(sys.argv[2]):
    try:
        port = open(sys.argv[1]).read().strip()
        if port and get(f"http://localhost:{port}/ready", timeout=2).read() == b"zq-ready":
            print(f"{time.monotonic() - t0:.1f}"); sys.exit(0)
    except OSError:
        pass
    time.sleep(0.1)
sys.exit(1)
PY
}
# DELAY LIMIT [PING]: the server held back DELAY s and waited for up to LIMIT s; then one passing and one failing run,
# each given PING (default: the server's URL; none: no ping URL). 0 when each run pinged once, to its own route, and
# printed nothing of it; 1 when the pings were wrong; 2 when the server wasn't ready. Sets url, lc13_t and lc13_why,
# and leaves the server up for hc_stop.
lc13_check() {
    local up ping shown; hc_start "$1"
    lc13_t=$(hc_ready "$2"); up=$?
    url="http://localhost:$(cat "$TMP/hc.port" 2>/dev/null)/zq-check"
    (( up == 0 )) || { lc13_why="stand-in server not ready after $2 s"; return 2; }
    ping=${3:-$url}; [[ "$ping" == none ]] && ping=""
    fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
    lc KIT_LOAD_CHECK_PING="$ping" no_proxy=localhost NO_PROXY=localhost >/dev/null
    pass_hits=$(cat "$TMP/hc.hits" 2>/dev/null); shown=$(cat "$TMP/lc.out")
    : > "$TMP/hc.hits"; lc KIT_LOAD_CHECK_PING="$ping" no_proxy=localhost NO_PROXY=localhost FAKE_MODE=auth >/dev/null
    fail_hits=$(cat "$TMP/hc.hits" 2>/dev/null); shown+=$(cat "$TMP/lc.out")
    lc13_why="server ready after $lc13_t s; pass: [$(echo $pass_hits)] fail: [$(echo $fail_hits)]"
    [[ "$pass_hits" == "/zq-check" && "$fail_hits" == "/zq-check/fail" && "$shown" != *zq-check* ]]
}
lc13_check 0 60; lc13_rc=$?; lc13_saw=$lc13_why
# The probe holds none of the check's credentials: the ping URL is the check's to send, after the probe has
# exited, and a probe that could read it would hold the check's one secret. The stand-in recorded the names in its
# environment, never their values; HOME and the marker show it recorded a real environment.
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290; rm -f "$FAKE_ENV"
rep=$(lc KIT_LOAD_CHECK_PING="$url" no_proxy=localhost NO_PROXY=localhost); env_rc=$?
hc_stop
                                               want_ok "LC13 a run pings one check once: its URL on a pass, /fail on a fail, and never prints it" $lc13_rc "$lc13_saw"
[[ $lc13_rc -eq 0 ]] && echo "note  LC13: the stand-in server answered after $lc13_t s"
names=$(cat "$FAKE_ENV" 2>/dev/null)
{ [[ $env_rc -eq 0 && "$rep" == *"kit load check: PASS"* ]] && grep -qx HOME <<<"$names" && grep -qx KIT_LOAD_PROBE <<<"$names" \
  && ! grep -qx KIT_LOAD_CHECK_PING <<<"$names" && ! grep -q 'zq-check' "$FAKE_ENV"; }
                                               want_ok "LC15 the probe's environment holds none of the check's credentials: no KIT_LOAD_CHECK_PING" $? "exit $env_rc; KIT_LOAD_CHECK_PING among the probe's $(grep -c . <<<"$names") names: $(grep -cx KIT_LOAD_CHECK_PING <<<"$names")"
# LC13's own harness: a server slow to start is waited for; with it up and the check given no ping URL,
# LC13's test fails, for the missing pings (the control); a server not up within the limit is reported as not ready.
lc13_check 7 60; rc=$?; hc_stop;               want_ok "LC13b a stand-in server that starts 7 s late, past the old 5-second wait, is waited for, and both pings arrive" $rc "$lc13_why"
lc13_check 0 60 none; rc=$?; hc_stop
[[ $rc -eq 1 && "$lc13_why" == *"pass: [] fail: []" ]]
                                               want_ok "LC13c control: with the server up and the check given no ping URL, LC13's test fails, for the missing pings" $? "returned $rc: $lc13_why"
lc13_check 3 1; rc=$?; hc_stop
[[ $rc -eq 2 && "$lc13_why" == "stand-in server not ready after 1 s" ]]
                                               want_ok "LC13d a server not up within the limit fails LC13 as not ready, never as a missing ping" $? "returned $rc: $lc13_why"

# ============================== the check, trimmed ================================================
# The check reads no transcript: its probe's answer and the skill entries are the check. The probe runs without
# DISABLE_AUTOUPDATER, so Claude Code's updates lead. Under an org's managed-mcp.json, where the probe's
# --strict-mcp-config makes Claude Code exit at startup (code.claude.com/docs/en/managed-mcp.md), the probe is skipped,
# saying so, and never reported as passing; --managed-mcp names the file, so the suite can plant one. A failing probe
# still fails the run (LC4, LC5, LC10, LS13, before and after).
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290; mkdir -p "$TMP/org"; printf '{"mcpServers": {}}\n' > "$TMP/org/managed-mcp.json"
rm -f "$FAKE_SEEN"; LC_ARGS=(--managed-mcp "$TMP/org/managed-mcp.json"); rep=$(lc); rc=$?; LC_ARGS=()
[[ "$rep" == *"probe: skipped"* && "$rep" != *"probe: pass"* && ! -e "$FAKE_SEEN" ]] || rc=1
                                               passes "LQ2 under an org's managed-mcp.json the probe is skipped, saying so, never run and never reported as passing" $rc "$rep"
rm -f "$FAKE_SEEN"; LC_ARGS=(--managed-mcp "$TMP/org/none.json"); rep=$(lc); rc=$?; LC_ARGS=()
[[ "$rep" == *"probe: pass"* && -e "$FAKE_SEEN" ]] || rc=1
                                               passes "LQ2b with no managed-mcp.json where it is named, the probe runs and passes (control)" $rc "$rep"
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290; rm -f "$FAKE_ENV"; rep=$(lc); rc=$?
names=$(cat "$FAKE_ENV" 2>/dev/null); [[ -n "$names" && $'\n'"$names"$'\n' != *$'\n'DISABLE_AUTOUPDATER$'\n'* ]] || rc=1
                                               passes "LQ4 the probe's environment carries no DISABLE_AUTOUPDATER" $rc "$rep"
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290; transcript "$P/-c/s3.jsonl" 2.1.290 garbage; damaged "$P/-d/d1.jsonl" 2.1.290
transcript "$P/-b/s2.jsonl" 2.1.291 "noimport:rules/morrowcairn.md"
rep=$(lc); rc=$?;                              passes "LQ5 transcripts the old scan failed on, unreadable, damaged or missing an import, no longer affect the result" $rc "$rep"

# ============================== the stub: the check's own code, verified first ==================
# The stub reads the kit's user pin and verifies the whole install against it before any of the install's code runs; a
# refusal still reports, so a stopped check is never a silent one.
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
stub_refused() {  # NAME RC REPORT REASON: refused, with one REFUSING line, for REASON, and the report says so
    local n; n=$(grep -c 'REFUSING' "$TMP/lc.out")
    if [[ $2 -ne 0 && $n -eq 1 && "$(cat "$TMP/lc.out")" == *"$4"* && "$3" == *"kit load check: FAIL"* && "$3" == *"$4"* ]]; then result "$1" 0
    else result "$1" 1 "exit $2, $n refusal(s), want '$4': $(head -c 200 "$TMP/lc.out" | tr '\n' ' ') | report: $(echo $3 | cut -c1-120)"; fi; }
rm -f "$UPIN"; rep=$(lc); rc=$?;              stub_refused "LS1 the stub refuses with no user pin" $rc "$rep" "no kit user pin can be read"
printf 'release=v1.0.0\nmanifest=sha256:12\n' > "$UPIN"
rep=$(lc); rc=$?;                              stub_refused "LS2 the stub refuses a malformed user pin" $rc "$rep" "the kit user pin is malformed"
userpin v9.9.9; rep=$(lc); rc=$?;              stub_refused "LS3 the stub refuses a pin whose install is missing" $rc "$rep" "no install for v9.9.9"
userpin v1.0.0 "sha256:$(printf '0%.0s' {1..64})"; rep=$(lc); rc=$?
                                               stub_refused "LS4 the stub refuses a manifest that doesn't match the user pin" $rc "$rep" "manifest doesn't match the pin"
userpin
chmod -R u+w "$I"; echo "# an edit" >> "$I/bin/kit-load-check"
rep=$(lc); rc=$?;                              stub_refused "LS5 the stub refuses a load-check file that doesn't match the manifest" $rc "$rep" "bin/kit-load-check in the install doesn't match its manifest line"
reset_i; chmod -R u+w "$I"; echo "a changed rule" >> "$I/$RULES"
rep=$(lc); rc=$?;                              stub_refused "LS6 the stub refuses the rules file edited in the install" $rc "$rep" "$RULES in the install doesn't match its manifest line"
sum=$(sha "$I/$RULES"); sed -i "s|^[0-9a-f]*  $RULES\$|$sum  $RULES|" "$I/MANIFEST.sha256"
rep=$(lc); rc=$?;                              stub_refused "LS6b and the same file with its manifest line edited to match" $rc "$rep" "manifest doesn't match the pin"
reset_i; chmod u+w "$I/bin"; echo 'print("x")' > "$I/bin/extra.py"
rep=$(lc); rc=$?;                              stub_refused "LS7 the stub refuses a file the manifest doesn't list" $rc "$rep" "bin/extra.py is in the install but not in its manifest"
reset_i
# A refusal reaches the ping as a failure, by its own route: a stand-in curl records what it was sent, its arguments
# and, where it is handed a config on its standard input (-K -), each line of that, marked "STDIN: ".
mkcurl() {
    cat > "$FB/curl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$TMP/curl-args"
case " \$* " in *" -K - "*) sed 's/^/STDIN: /' >> "$TMP/curl-args" ;; esac
EOF
    chmod +x "$FB/curl"; }
mkcurl
userpin v9.9.9; rm -f "$TMP/curl-args"; rep=$(lc KIT_LOAD_CHECK_PING=https://ping.invalid/zq-test); rc=$?
grep -q 'https://ping.invalid/zq-test/fail' "$TMP/curl-args" 2>/dev/null && ! grep -q 'zq-test' "$TMP/lc.out" || rc=0
                                               stub_refused "LS8 a refusal pings the check's fail route, and never prints the ping URL" $rc "$rep" "no install for v9.9.9"
# The ping URL is a credential, and a command line is readable by every local user while it runs: the stub hands the
# URL to curl on its standard input, as a config line, and never as an argument.
cargs=$(awk '!/^STDIN: /' "$TMP/curl-args" 2>/dev/null); cin=$(awk '/^STDIN: /' "$TMP/curl-args" 2>/dev/null)
[[ $rc -ne 0 && -n "$cargs" && "$cargs" != *"ping.invalid"* && "$cin" == *'url = "https://ping.invalid/zq-test/fail"'* ]]
                                               result "LP3 the stub's fail ping hands curl the URL on its standard input, never on its command line" $? "args: $(printf '%s' "$cargs" | tr '\n' ' ' | cut -c1-160) | stdin: $(printf '%s' "$cin" | tr '\n' ' ' | cut -c1-120)"
userpin
# The ping never names a file someone put in the install, only how many there are: such a name is text the kit didn't
# write, and could be a listed term or a machine path. The report on the machine names the first. Two unlisted files, each named with a stand-in term: the ping says 2 and carries neither name.
reset_i; chmod u+w "$I" "$I/bin"; echo x > "$I/bin/zqunlisted-term.py"; echo y > "$I/zqsecond-term.txt"
rm -f "$TMP/curl-args"; rep=$(lc KIT_LOAD_CHECK_PING=https://ping.invalid/zq-test); rc=$?; ca=$(cat "$TMP/curl-args" 2>/dev/null)
[[ "$ca" == *"https://ping.invalid/zq-test/fail"* && "$ca" == *"2 files are in the install but not in its manifest"* \
   && "$ca" != *zqunlisted* && "$ca" != *zqsecond* ]] || rc=0
                                               stub_refused "LS14 the fail ping says how many files the manifest doesn't list, naming none; the report names the first" $rc "$rep" "bin/zqunlisted-term.py is in the install but not in its manifest"
reset_i; chmod u+w "$I/bin"; echo x > "$I/bin/zqunlisted-term.py"
rm -f "$TMP/curl-args"; rep=$(lc KIT_LOAD_CHECK_PING=https://ping.invalid/zq-test); rc=$?; ca=$(cat "$TMP/curl-args" 2>/dev/null)
[[ "$ca" == *"1 file is in the install but not in its manifest"* && "$ca" != *zqunlisted* ]] || rc=0
                                               stub_refused "LS14b ... and one such file is counted as one, by name only in the report" $rc "$rep" "bin/zqunlisted-term.py is in the install but not in its manifest"
# The ping carries the kit's fixed words alone: pass or fail, the probe's result and, on a failure, the kind of each
# problem; its one number is how many files the manifest doesn't list. Every value the stub and the check read from
# the machine stays in the report there. A stand-in term is planted in each such
# value, and the pinned release is watched too: no ping carries one, and the report on the machine still names it.
PL=zqplant
# NAME RC REPORT KIND PLANT...: a refused run whose fail ping says FAIL and fail: KIND, carrying no PLANT and no
# absolute path, while the report file or the stub's own output names the first PLANT. The stand-in curl's log is the
# ping: its body is one of the arguments it was given.
stub_ping_clean() {
    local name=$1 rc=$2 rep=$3 kind=$4 ca out p why=""; shift 4
    ca=$(cat "$TMP/curl-args" 2>/dev/null); out=$(cat "$TMP/lc.out" 2>/dev/null)
    [[ $rc -ne 0 ]] || why+="the run passed; "
    [[ "$ca" == *"https://ping.invalid/zq-test/fail"* && "$ca" == *"kit load check: FAIL"* ]] || why+="no fail ping; "
    [[ "$ca" == *"fail: $kind"* ]] || why+="the ping doesn't say: $kind; "
    for p in "$@"; do [[ "$ca" != *"$p"* ]] || why+="the ping carries $p; "; done
    [[ "$ca" != *"$TMP"* ]] || why+="the ping carries an absolute path; "
    [[ "$rep$out" == *"$1"* ]] || why+="the report on the machine doesn't name $1; "
    if [[ -z "$why" ]]; then result "$name" 0
    else result "$name" 1 "exit $rc; $why| ping: $(printf '%s' "$ca" | tr '\n' ' ' | cut -c1-240)"; fi; }
stub_ping_run() { rm -f "$TMP/curl-args"; rep=$(lc KIT_LOAD_CHECK_PING=https://ping.invalid/zq-test "$@"); rc=$?; }
reset_i; chmod -R u+w "$I"; sed -i "s/^tag=.*/tag=$PL-tag/" "$I/RELEASE"
stub_ping_run;                                 stub_ping_clean "LP1a the stub's ping holds back the tag an install's RELEASE names, saying only that it isn't the pin's" $rc "$rep" "the install's RELEASE names a release other than the pin's" "$PL"
reset_i; userpin v31.41.59; stub_ping_run
                                               stub_ping_clean "LP1b ... and the pinned release, when it has no install" $rc "$rep" "no install for the pinned release" "31.41.59"
userpin; chmod -R u+w "$I"; echo planted > "$I/$PL-listed.txt"
printf '%s  %s\n' "$(sha "$I/$PL-listed.txt")" "$PL-listed.txt" >> "$I/MANIFEST.sha256"; userpin v1.0.0 "sha256:$(sha "$I/MANIFEST.sha256")"
echo changed > "$I/$PL-listed.txt"; stub_ping_run
                                               stub_ping_clean "LP1c ... and the name of a file the manifest lists, changed" $rc "$rep" "a file in the install doesn't match its manifest line" "$PL"
rm -f "$I/$PL-listed.txt"; stub_ping_run;     stub_ping_clean "LP1d ... or missing" $rc "$rep" "a file the install's manifest lists is missing from the install" "$PL"
reset_i; userpin; mkdir -p "$TMP/$PL-hm/.claude"; printf '# the person'"'"'s own file\n' > "$TMP/$PL-hm/.claude/CLAUDE.md"
stub_ping_run KIT_INSTALL_ROOT="$TMP/$PL-root" HOME="$TMP/$PL-hm"
                                               stub_ping_clean "LP1e ... and the install root and the home folder, and the release they hold no install for" $rc "$rep" "no install for the pinned release" "$PL" "v1.0.0"
# The check's own ping, at the stand-in server, which keeps what each ping carried.
hc_start 0; hc_ready 60 >/dev/null; lp_up=$?; url="http://localhost:$(cat "$TMP/hc.port" 2>/dev/null)/zq-check"
check_ping_run() { : > "$TMP/hc.hits.body"; rep=$(lc KIT_LOAD_CHECK_PING="$url" no_proxy=localhost NO_PROXY=localhost "$@"); rc=$?
                   pb=$(cat "$TMP/hc.hits.body" 2>/dev/null); }
# NAME VERDICT KIND PLANT...: the last run's ping says VERDICT and, where KIND is given, fail: KIND, carrying no PLANT
# and no absolute path; the report on the machine names the first PLANT, unless it is written -PLANT (a value the report
# doesn't show either).
check_ping_clean() {
    local name=$1 verdict=$2 kind=$3 p why=""; shift 3
    (( lp_up == 0 )) || why+="the stand-in server wasn't ready; "
    [[ ( $verdict == PASS && $rc -eq 0 ) || ( $verdict == FAIL && $rc -ne 0 ) ]] || why+="exit $rc for a $verdict; "
    [[ "$pb" == *"kit load check: $verdict"* ]] || why+="the ping doesn't say $verdict; "
    [[ -z "$kind" || "$pb" == *"fail: $kind"* ]] || why+="the ping doesn't say: $kind; "
    for p in "$@"; do [[ "$pb" != *"${p#-}"* ]] || why+="the ping carries ${p#-}; "; done
    [[ "$pb" != *"$TMP"* ]] || why+="the ping carries an absolute path; "
    [[ "$1" == -* || "$rep" == *"$1"* ]] || why+="the report on the machine doesn't name $1; "
    if [[ -z "$why" ]]; then result "$name" 0
    else result "$name" 1 "$why| ping: $(printf '%s' "$pb" | tr '\n' ' ' | cut -c1-240)"; fi; }
mkdir -p "$KIT_INSTALL_ROOT/$PL-rel/rules"; cp "$I/$RULES" "$KIT_INSTALL_ROOT/$PL-rel/$RULES"; rm -f "$RF"; ln -s "$KIT_INSTALL_ROOT/$PL-rel/$RULES" "$RF"
check_ping_run;                                check_ping_clean "LP2a the check's ping holds back the folder a rules link points into, and the release" FAIL "the rules link points into another release than the pin names" "$PL" "v1.0.0"
rm -rf "${KIT_INSTALL_ROOT:?}/$PL-rel"; rules; userfile "$PL-imp"
check_ping_run;                                check_ping_clean "LP2b ... the path an @-import in the user-level CLAUDE.md names" FAIL "the user-level CLAUDE.md still imports a kit file; the kit's rules load from the rules folder" "$PL" "v1.0.0"
userfile; check_ping_run FAKE_MODE=exit93;     check_ping_clean "LP2c ... the probe's exit status" FAIL "probe: non-zero exit" "(93)" "v1.0.0"
check_ping_run FAKE_MODE=zqanswer;             check_ping_clean "LP2d ... the probe's answer and its error output, which the report doesn't show either" FAIL "probe: missing from the answer: $RULES" "-$PL" "v1.0.0"
reset_i; chmod -R u+w "$I"; mkdir -p "$I/.claude/skills/$PL-skill"; cp "$I/.claude/skills/gates/SKILL.md" "$I/.claude/skills/$PL-skill/SKILL.md"
printf '%s  %s\n' "$(sha "$I/.claude/skills/$PL-skill/SKILL.md")" ".claude/skills/$PL-skill/SKILL.md" >> "$I/MANIFEST.sha256"
userpin v1.0.0 "sha256:$(sha "$I/MANIFEST.sha256")"
check_ping_run;                                check_ping_clean "LP2e ... the name of a skill the user level lacks" FAIL "a skill has no user-level entry" "$PL" "v1.0.0"
skills; check_ping_run;                        check_ping_clean "LP2f ... and on a pass, the release and the skills' names" PASS "" "$PL" "v1.0.0" "record-stamps"
reset_i; userpin; skills
lp_claude=(); [[ "$PY_OS" == nt ]] || { mkdir -p "$TMP/$PL-bin"; cp "$FB/claude" "$TMP/$PL-bin/claude"; lp_claude=(KIT_CLAUDE="$TMP/$PL-bin/claude"); }
LC_ARGS=(--probe-dir "$TMP/$PL-probe" --managed-mcp "$TMP/$PL-org/none.json")
check_ping_run FAKE_MODE=auth HOME="$TMP/$PL-hm" CLAUDE_CONFIG_DIR="$TMP/$PL-cc" ${lp_claude[@]+"${lp_claude[@]}"}; LC_ARGS=()
                                               check_ping_clean "LP2g ... and every path it reads: the home folder, the config folder, the user-level CLAUDE.md, the probe's folder, managed-mcp.json's and claude's" FAIL "probe: auth" "v1.0.0" "-$PL"
hc_stop
# A reason the check doesn't list goes to its ping as a fixed line, so a reason added later can't send a value read
# from the machine; a listed one with a value goes as its kind.
lpk=$(python3 -I -B - "$(native "$ROOT/bin/kit-load-check")" <<'PY' 2>&1 | tr -d '\r'   # -B: no bytecode beside it
import importlib.machinery, importlib.util, sys
loader = importlib.machinery.SourceFileLoader("kit_load_check", sys.argv[1])
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("kit_load_check", loader)); loader.exec_module(m)
print(m.ping_kind("a reason added later, naming zqplant"))
print(m.ping_kind("skill zqplant: no user-level entry"))
PY
)
[[ "$lpk" == $'a check failed (the report on the machine says which)\na skill has no user-level entry' ]]
                                               want_ok "LP2h a reason the check's ping doesn't list goes as a fixed line, and a listed one naming a value as its kind" $? "$lpk"
reset_i; rm -f "$FB/curl"
# The stub hands over to the load check under python3 -I, so a module the caller's environment plants can't stand in
# for it: here a sitecustomize on PYTHONPATH that exits 0 at once, before any check runs. A run
# whose probe fails must still fail, for that reason.
mkdir -p "$TMP/plant"; printf 'import os\nos._exit(0)\n' > "$TMP/plant/sitecustomize.py"
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
rep=$(lc PYTHONPATH="$TMP/plant" FAKE_MODE=auth); rc=$?
                                               fails_for "LS13 a sitecustomize planted on PYTHONPATH doesn't stand in for the load check: a failing probe still fails" $rc "$rep" "probe: auth"
# One verifier text in all three of its homes (install_test VT1 covers the hook stub and kit-pin).
vf() { awk '/^kit_verify_install\(\) \{/ {p=1} p {print} p && /^\}/ {exit}' "$1" 2>/dev/null; }
a=$(vf "$ROOT/leak-detection/stub-hook"); b=$(vf "$ROOT/bin/kit-load-check-stub")
[[ -n "$a" && "$a" == "$b" ]];                 want_ok "LS9 the load check's stub carries the same install verifier as the hook stub" $? ""
modes=$(git -C "$ROOT" ls-files -s -- bin/kit-load-check bin/kit-load-check-stub tests/load_check_test.sh)
bad=$(printf '%s\n' "$modes" | awk 'NF && $1 != "100755" {print $4}'); n=$(printf '%s\n' "$modes" | awk 'NF' | wc -l)
[[ "$n" -eq 3 && -z "$bad" ]];                 want_ok "LS10 the check, its stub and this suite are tracked executable" $? "tracked $n of 3; not 100755: $(echo $bad)"

# ============================== hashing without sha256sum =======================================
# A stock Mac has shasum and no sha256sum. The stub verifies with either; with neither it refuses, names both and
# reports the refusal (install_test HS1 holds its routine to the other scripts'). Each PATH here holds a link to every
# command on PATH but the ones left out, each left out with its .exe, which Git Bash runs by the bare
# name; one ln per folder of PATH (hooks_test).
pathless() {   # DIR NAME...: links in DIR to the first command of each name on PATH, except each NAME and NAME.exe
    local dir=$1 d f n i; local -a dirs add; shift; mkdir -p "$dir"
    IFS=: read -ra dirs <<< "$PATH"
    for d in "${dirs[@]}"; do
        [[ -d "$d" ]] || continue
        add=()
        for f in "$d"/*; do
            n=${f##*/}
            [[ -f "$f" && -x "$f" && ! -e "$dir/$n" && ! -L "$dir/$n" ]] || continue
            [[ " $* " == *" ${n%.exe} "* ]] || add+=("$f")
        done
        for (( i = 0; i < ${#add[@]}; i += 500 )); do ln -s "${add[@]:i:500}" "$dir/"; done
    done
}
NOSHA="$TMP/path-nosha"; pathless "$NOSHA" sha256sum shasum
SHAONLY="$TMP/path-shasum"; pathless "$SHAONLY" sha256sum
NOTOOL="neither sha256sum (GNU coreutils) nor shasum (Perl) is installed"
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
rep=$(lc PATH="$FB:$NOSHA"); rc=$?; n=$(grep -c 'REFUSING' "$TMP/lc.out")
[[ $rc -ne 0 && $n -eq 1 && "$rep" == *"kit load check: FAIL"* ]]
                                               want_ok "LS11 with neither tool, the stub refuses and reports a failed run" $? "exit $rc, $n refusal(s): $(head -c 200 "$TMP/lc.out" | tr '\n' ' ')"
                                               stub_refused "LS11b and the refusal names both tools" $rc "$rep" "$NOTOOL"
if (PATH="$SHAONLY"; command -v shasum >/dev/null 2>&1); then
    rep=$(lc PATH="$FB:$SHAONLY"); rc=$?;      passes "LS12 with shasum and no sha256sum, the stub verifies the install and the check passes" $rc "$rep"
else
    skip LS12 "shasum is not installed here"
fi

# ============================== the stub: a pass only from the hand-over ========================
# The stub passes only by handing over (exec) to the install's check, and any other end of it is a failed run it reports:
# an exit 0 short of the hand-over, a stop on an unset variable, a failed exec. Copies with one
# line put right after its first check must refuse and report; a passing check must still pass. Under the bash 3 that
# KIT_TEST_BASH3 names too (a test tool, never a kit dependency), skipped, counted, without it.
B3=${KIT_TEST_BASH3:-}; b3why=""
if [[ -z "$B3" ]]; then b3why="KIT_TEST_BASH3 is not set"
elif [[ "$("$B3" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null)" != 3 ]]; then b3why="KIT_TEST_BASH3 is not a bash 3"; fi
inj() {  # SRC DST ANCHOR LINE: DST is SRC with LINE put before its first line starting ANCHOR; 0 only when one line went in
    mkdir -p "${2%/*}"; awk -v a="$3" -v l="$4" '!done && index($0, a) == 1 {print l; done = 1} {print}' "$1" > "$2"; chmod +x "$2"
    [[ $(( $(wc -l < "$2") - $(wc -l < "$1") )) -eq 1 ]]; }
STOPPED="stopped before it finished"
inj "$STUB" "$TMP/stub-exit/kit-load-check-stub" 'release=""' 'exit 0'; sx=$?
inj "$STUB" "$TMP/stub-unset/kit-load-check-stub" 'release=""' ': "$zq_unset_probe"'; su=$?
eg_stub_run() {  # SUFFIX BASH
    local s=$1 rep rc
    fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
    LC_BASH=$2; LC_STUB="$TMP/stub-exit/kit-load-check-stub"; rep=$(lc); rc=$?; (( sx == 0 )) || rc=0
    stub_refused "EG25$s the stub: an exit 0 right after its first check refuses, and reports a failed run" $rc "$rep" "$STOPPED"
    LC_STUB="$TMP/stub-unset/kit-load-check-stub"; rep=$(lc); rc=$?; (( su == 0 )) || rc=0
    stub_refused "EG26$s the stub: an unset variable right after its first check refuses, and reports a failed run" $rc "$rep" "$STOPPED"
    fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
    LC_STUB=$STUB; rep=$(lc); rc=$?
    passes "EG27$s the stub: a passing check still passes, handed over to it" $rc "$rep"
    LC_BASH=bash; LC_STUB=$STUB
}
eg_stub_run "" bash
if [[ -z "$b3why" ]]; then eg_stub_run " (bash 3)" "$B3"
else for c in EG25 EG26 EG27; do skip "$c (bash 3)" "$b3why"; done; fi
# The stub's ping, likewise: a copy with one refusal its ping doesn't list, its reason naming a stand-in term, put right
# after its first check, pings the fixed line and keeps the reason in the report.
mkcurl
inj "$STUB" "$TMP/stub-plant/kit-load-check-stub" 'release=""' "refuse \"the machine names $PL here\""; sp=$?
fresh_projects; LC_STUB="$TMP/stub-plant/kit-load-check-stub"; stub_ping_run; LC_STUB=$STUB; (( sp == 0 )) || rc=0
                                               stub_ping_clean "LP1f a refusal the stub's ping doesn't list goes as a fixed line, its reason kept in the report" $rc "$rep" "the stub refused (the report on the machine says why)" "$PL"
# The fail ping under bash 3 too: a stock Mac runs the stub under its /bin/bash, 3.2, where EG25 to EG27 set no ping, so
# the ping's own lines had only been parsed there. A refusal (a pinned release with no install) still pings, the URL
# reaching curl on its standard input and never on curl's command line or in the stub's output, as LS8 and LP3 check
# under this suite's bash. It catches a ping 3.2 doesn't send, a URL 3.2 puts on the command line or prints, and a
# refusal it doesn't report. lp3b_run SUFFIX BASH.
lp3b_run() {
    local rep rc cargs cin
    userpin v9.9.9; rm -f "$TMP/curl-args"
    LC_BASH=$2; rep=$(lc KIT_LOAD_CHECK_PING=https://ping.invalid/zq-test); rc=$?; LC_BASH=bash
    cargs=$(awk '!/^STDIN: /' "$TMP/curl-args" 2>/dev/null); cin=$(awk '/^STDIN: /' "$TMP/curl-args" 2>/dev/null)
    [[ -n "$cargs" && "$cargs" != *"ping.invalid"* && "$cin" == *'url = "https://ping.invalid/zq-test/fail"'* \
       && "$(cat "$TMP/lc.out")" != *"zq-test"* ]] || rc=0
    stub_refused "LP3b$1 the stub's fail ping: sent, its URL on curl's standard input alone, never printed, the refusal reported" $rc "$rep" "no install for v9.9.9"
    userpin; }
lp3b_run "" bash
if [[ -z "$b3why" ]]; then lp3b_run " (bash 3)" "$B3"; else skip "LP3b (bash 3)" "$b3why"; fi
rm -f "$FB/curl"
# The same ping with this machine's real curl, which reads the URL from its standard input (-K -): the stand-in above
# only records what it was handed. A listener on the loopback address (built below at run time, as `lo`, not written
# out), a small Python server, records each request it gets; the
# case passes when the stub's fail ping arrives there, a POST to the URL's /fail with the fail line in its body, and the
# URL is in neither the stub's output nor its report. no_proxy keeps a proxy setting from taking the request elsewhere.
# It skips, saying why, with no curl or where no local port can be opened. lp4_run SUFFIX BASH.
cat > "$TMP/lp4-server.py" <<'PY'
import http.server, os, sys, time
port_file, rec, addr = sys.argv[1], sys.argv[2], sys.argv[3]
class Rec(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        with open(rec, "ab") as f:
            f.write(b"POST " + self.path.encode() + b"\n" + body + b"\n")
        self.send_response(200); self.send_header("Content-Length", "0"); self.end_headers()
    def log_message(self, *a):
        pass
try:
    srv = http.server.HTTPServer((addr, 0), Rec)
except OSError as e:
    with open(port_file, "w") as f:
        f.write("nobind %s\n" % e.strerror)
    sys.exit(0)
with open(port_file + ".part", "w") as f:
    f.write("%d\n" % srv.server_address[1])
os.rename(port_file + ".part", port_file)
srv.timeout = 0.5
end = time.time() + 120
while time.time() < end:
    srv.handle_request()
PY
lp4why=""; lp4pid=""; lp4port=""; lo=$(printf '%d.%d.%d.%d' 127 0 0 1)
if ! command -v curl >/dev/null 2>&1; then lp4why="curl is not installed here"
else
    rm -f "$TMP/lp4-port" "$TMP/lp4-rec" "$TMP/lp4-server.err"
    python3 -I "$TMP/lp4-server.py" "$TMP/lp4-port" "$TMP/lp4-rec" "$lo" 2> "$TMP/lp4-server.err" & lp4pid=$!
    for _ in $(seq 1 300); do [[ -s "$TMP/lp4-port" ]] && break; sleep 0.1; done   # up to 30 s: a slow runner's python
    lp4port=$(cat "$TMP/lp4-port" 2>/dev/null)
    if [[ "$lp4port" == nobind* ]]; then lp4why="no local port could be opened (${lp4port#nobind })"
    elif [[ ! "$lp4port" =~ ^[0-9]+$ ]]; then
        lp4why="the listener named no port within 30 seconds$(awk 'NF {printf ": %s", substr($0, 1, 120); exit}' "$TMP/lp4-server.err" 2>/dev/null)"
    fi
fi
lp4_run() {
    local rep rc recd url="http://$lo:$lp4port/zq-lp4"
    userpin v9.9.9; rm -f "$TMP/lp4-rec"
    LC_BASH=$2; rep=$(lc no_proxy="$lo" NO_PROXY="$lo" KIT_LOAD_CHECK_PING="$url"); rc=$?; LC_BASH=bash
    recd=$(cat "$TMP/lp4-rec" 2>/dev/null)
    [[ "$recd" == "POST /zq-lp4/fail"$'\n'"kit load check: FAIL"* && "$(cat "$TMP/lc.out")" != *"zq-lp4"* \
       && "$rep" != *"zq-lp4"* && "$(cat "$TMP/lc.out")" != *"did not go through"* ]] || rc=0
    stub_refused "LP4$1 the stub's fail ping with the real curl reaches a listener on this machine, its URL never printed" $rc "$rep" "no install for v9.9.9"
    userpin; }
if [[ -n "$lp4why" ]]; then skip "LP4" "$lp4why"; skip "LP4 (bash 3)" "$lp4why"
else
    lp4_run "" bash
    if [[ -z "$b3why" ]]; then lp4_run " (bash 3)" "$B3"; else skip "LP4 (bash 3)" "$b3why"; fi
fi
[[ -z "$lp4pid" ]] || { kill "$lp4pid" 2>/dev/null; wait "$lp4pid" 2>/dev/null; }

echo
echo "load_check_test: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 && $PASS -gt 0 ]]

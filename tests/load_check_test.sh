#!/usr/bin/env bash
#
# load_check_test.sh — tests for the daily load check (bin/kit-load-check) and its stub (bin/kit-load-check-stub),
# which watch that the user-level CLAUDE.md still loads the kit's doctrine from the pinned install.
#
#   tests/load_check_test.sh [ROOT]    ROOT = a checkout of this kit (default: the one holding this file)
#
# Every case works under a temp dir: an install built from ROOT's staged tree (its hook suite replaced by a stand-in,
# as install_test's v1.0.0), a user-level CLAUDE.md that imports from it with a pin line, user-level skill entries, and
# a stand-in `claude` for the headless probe. No real session, transcript, ping or Claude Code run is touched. The check
# reads no transcript (decisions log §274 ruling 3); the SYNTHETIC transcripts some cases write, and the one the stand-in
# claude writes as a real probe run would, are there to show they no longer affect the result (LQ5).
#
# Each failing case must fail for its stated reason and only that one: the report names every reason it failed, so
# a check that lost one test but failed another would otherwise stay red for the wrong reason. Exit 0 only when every
# case passed AND at least one case ran.
#
set -uo pipefail

ROOT=$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd) || exit 1
command -v python3 >/dev/null 2>&1 || { echo "load_check_test: python3 is required" >&2; exit 1; }
# Under Git Bash, python3 is a Windows program: it reads paths in Windows form and starts only Windows programs, and the
# load check is python3 (decisions log §102). native prints a path the way that python3 reads it.
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

CASES=(LC0 LC0b LC4 LC5 LC7 LC8 LC9 LC10 LC12 LC13 LC13b LC13c LC13d LC14 LC15 LQ2 LQ2b LQ4 LQ5 LS1 LS2 LS3 LS4 LS5 LS6 LS6b LS7 LS8 LS13 LS9 LS10 LS11 LS11b LS12
       EG25 EG26 EG27)
if ! git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null 2>&1; then
    for c in "${CASES[@]}"; do skip "$c" "no commits yet in $ROOT: rerun after commit one"; done
    echo; echo "load_check_test: $PASS passed, $FAIL failed, $SKIP skipped"; exit 0
fi

# ============================== an install, a user-level file, skills, a projects folder =======
export KIT_INSTALL_ROOT="$TMP/releases"; mkdir -p "$KIT_INSTALL_ROOT"
K="$TMP/kit"; git init -q -b main "$K"; git -C "$ROOT" checkout-index -a --prefix="$K/"
printf '#!/usr/bin/env bash\necho "hooks_test: a stand-in"\n' > "$K/tests/hooks_test.sh"
git -C "$K" add -A && git -C "$K" -c user.name=t -c user.email=t@invalid.local -c core.hooksPath=/dev/null commit -q -m kit
git -C "$K" -c user.name=t -c user.email=t@invalid.local tag -a v1.0.0 -m v1.0.0
git init -q --bare "$TMP/kit-remote.git"; git -C "$K" remote add origin "$TMP/kit-remote.git"
git -C "$K" push -q --no-verify origin v1.0.0 2>/dev/null
(cd "$K" && tools/install-release.sh v1.0.0) > "$TMP/install.log" 2>&1 || echo "load_check_test: the install could not be built: $(tail -n 1 "$TMP/install.log")" >&2
I="$KIT_INSTALL_ROOT/v1.0.0"; PRISTINE="$TMP/pristine"; cp -a "$I" "$PRISTINE" 2>/dev/null
reset_i() { chmod -R u+w "$I" 2>/dev/null; rm -rf "${I:?}"; cp -a "$PRISTINE" "$I" 2>/dev/null; }
H="sha256:$(sha "$I/MANIFEST.sha256" 2>/dev/null)"
IMPORTS=(skills/working-from-a-brief.md skills/shell-commands.md)
canary() { grep -oE 'kc-[0-9a-f]{16}' "$I/$1" 2>/dev/null | head -n 1; }

# The user-level file, as the import edit writes it: the import lines and the pin line beside them (design k, 2).
UF="$TMP/hm/.claude/CLAUDE.md"; mkdir -p "${UF%/*}"
userfile() {  # [RELEASE] [HASH]
    { printf '# the user-level file\n\n'
      for f in "${IMPORTS[@]}"; do printf '@%s/%s\n' "$(native "${KIT_INSTALL_ROOT}/${1:-v1.0.0}")" "$f"; done
      printf '<!-- kit pin: release=%s manifest=%s -->\n' "${1:-v1.0.0}" "${2:-$H}"; } > "$UF"; }
userfile
SK="$TMP/hm/.claude/skills"; mkdir -p "$SK"
skills() { rm -rf "${SK:?}"/*; local d; for d in "$I"/.claude/skills/*/; do d=${d%/}; ln -s "$d" "$SK/${d##*/}"; done; }
skills
P="$TMP/hm/.claude/projects"; mkdir -p "$P"
PROBE="$TMP/hm/.local/state/morrowcairn/load-probe"

# A synthetic transcript: one instructions attachment listing the user-level file, the imports (each with its
# canary unless named in DROP or BLANK) and a project file, then one model turn; VERSION on every line. The no-turn
# shapes (decisions log §241): localonly, two local commands and nothing else, as an abandoned /color and /rename leave
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
# A transcript the freeze damaged: transcript's lines with a line of NUL bytes after the first, the shape the 10-19
# freeze left in four transcripts on one machine (decisions log §213, §214).
damaged() {  # FILE VERSION
    transcript "$1" "$2"
    python3 -I - "$1" <<'PY'
import sys
f = sys.argv[1]; lines = open(f, "rb").read().split(b"\n")
open(f, "wb").write(b"\n".join(lines[:1] + [b"\0" * 40] + lines[1:]))
PY
}
# A stand-in claude for the probe. FAKE_MODE: pass, auth, timeout, nocanary. It answers as `claude -p --output-format
# json` does and writes the transcript a real run would, under the projects folder.
FB="$TMP/fakebin"; mkdir -p "$FB"
cat > "$FB/claude" <<'SH'
#!/usr/bin/env bash
printf '%s' "${KIT_LOAD_PROBE:-unset}" > "$FAKE_SEEN"     # the probe marker, as this process sees it
printf '%s\0' "$@" > "$FAKE_ARGS"                         # the probe's arguments, NUL-separated (LC14)
compgen -e > "$FAKE_ENV"                                  # the names in its environment, never their values (LC15)
case "${FAKE_MODE:-pass}" in
  auth)    echo '{"type":"result","subtype":"success","is_error":true,"result":"Invalid API key · Please run /login"}'; exit 1 ;;
  timeout) sleep 30; exit 0 ;;
esac
sid=0b0e5a5e-0000-4000-8000-$(printf '%012d' $$)
mode=full; [[ "${FAKE_MODE:-pass}" == nocanary ]] && mode="nocanary:skills/shell-commands.md"
slug=$(python3 -I -c 'import os, re; print(re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(os.getcwd())))' | tr -d '\r')   # as the check names it
bash "$FAKE_TRANSCRIPT" "$FAKE_PROJECTS/$slug/$sid.jsonl" "${FAKE_VERSION:-2.1.291}" "$mode"
answer=$(grep -ohE 'kc-[0-9a-f]{16}' $FAKE_ANSWER_FILES | sort -u)
[[ "${FAKE_MODE:-pass}" == nocanary ]] && answer=$(grep -ohE 'kc-[0-9a-f]{16}' $(echo $FAKE_ANSWER_FILES | cut -d' ' -f1) | sort -u)
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
export FAKE_TRANSCRIPT="$TMP/write_transcript.sh" FAKE_PROJECTS="$P" FAKE_ANSWER_FILES="$I/${IMPORTS[0]} $I/${IMPORTS[1]}"
export FAKE_SEEN="$TMP/probe-seen" FAKE_ARGS="$TMP/probe-args" FAKE_ENV="$TMP/probe-env"

STUB="$ROOT/bin/kit-load-check-stub"
REPORT="$TMP/report.txt"
# Run the check through its stub, as the cron line does. Prints the report; returns the stub's exit status. The stub
# runs from LC_STUB under LC_BASH: the pass-point cases (EG25 on) set them for copies of it and for bash 3.
LC_BASH=bash; LC_STUB=$STUB; LC_ARGS=()
lc() {  # [ENV=VALUE...]; LC_ARGS, more of the check's own arguments
    rm -f "$REPORT"
    env HOME="$TMP/hm" KIT_LOAD_CHECK_REPORT="$REPORT" PATH="$FB:$PATH" ${CLAUDE_AT:+"$CLAUDE_AT"} "$@" \
        "$LC_BASH" "$LC_STUB" --skills "$SK" --probe-dir "$PROBE" --timeout 5 ${LC_ARGS[@]+"${LC_ARGS[@]}"} > "$TMP/lc.out" 2>&1
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
rep=$(lc FAKE_MODE=nocanary); rc=$?;           fails_for "LC10 a probe whose answer lacks an import's canary fails, naming the import" $rc "$rep" "probe: import missing: skills/shell-commands.md"
# The probe carries a marker, KIT_LOAD_PROBE=1, set for its process alone: if the hooks-off setting doesn't keep the
# user-level hooks quiet in a real run, they can skip any run that carries it (a hooks edit, outside the kit).
fresh_projects; rm -f "$FAKE_SEEN"; rep=$(lc); rc=$?
[[ "$(cat "$FAKE_SEEN" 2>/dev/null)" == 1 && -z "${KIT_LOAD_PROBE:-}" ]] || rc=1
                                               passes "LC12 the probe process carries KIT_LOAD_PROBE=1, and the stand-in claude sees it" $rc "$rep"
# The probe never gets a tool that can act: its hooks are off only because no guard can fire without one (§61). Its
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
if [[ $rc -eq 0 && "$rep" == *"kit load check: PASS"* ]]; then result "LC14 the probe gets no tool: one empty --tools, --strict-mcp-config, disableAllHooks" 0
else result "LC14 the probe gets no tool: one empty --tools, --strict-mcp-config, disableAllHooks" 1 "exit $rc; ${why:-the run did not pass}"; fi
# One Healthchecks check, one ping per run: its URL on a pass, its /fail route on a fail. A stand-in server counts. It
# answers GET /ready without counting, and the runs start only once it has: a server not up within the limit fails
# LC13 as not ready, never as a missing ping. The old wait gave the server 5 seconds to write its port, and a macOS
# runner once took longer (queue 454; decisions log §127).
cat > "$TMP/hc.py" <<'PY'
import http.server, sys, time
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        ready = self.path == "/ready"
        self.send_response(200 if ready else 404); self.end_headers()
        if ready:
            self.wfile.write(b"zq-ready")
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with open(sys.argv[2], "a") as f:
            f.write(self.path + "\n")
        self.send_response(200); self.end_headers(); self.wfile.write(b"OK")
    def log_message(self, *a):
        pass
time.sleep(float(sys.argv[3]))                    # a slow start, for LC13b and LC13d
s = http.server.HTTPServer(("localhost", 0), H)
open(sys.argv[1], "w").write(str(s.server_address[1]))
s.serve_forever()
PY
hc_start() {  # DELAY: start the stand-in server, its start held back DELAY seconds
    rm -f "$TMP/hc.port" "$TMP/hc.hits"; python3 -I "$TMP/hc.py" "$TMP/hc.port" "$TMP/hc.hits" "$1" & HC=$!; }
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
# The probe holds none of the check's credentials (queue 195): the ping URL is the check's to send, after the probe has
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
# LC13's own harness (queue 454): a server slow to start is waited for; with it up and the check given no ping URL,
# LC13's test fails, for the missing pings (the control); a server not up within the limit is reported as not ready.
lc13_check 7 60; rc=$?; hc_stop;               want_ok "LC13b a stand-in server that starts 7 s late, past the old 5-second wait, is waited for, and both pings arrive" $rc "$lc13_why"
lc13_check 0 60 none; rc=$?; hc_stop
[[ $rc -eq 1 && "$lc13_why" == *"pass: [] fail: []" ]]
                                               want_ok "LC13c control: with the server up and the check given no ping URL, LC13's test fails, for the missing pings" $? "returned $rc: $lc13_why"
lc13_check 3 1; rc=$?; hc_stop
[[ $rc -eq 2 && "$lc13_why" == "stand-in server not ready after 1 s" ]]
                                               want_ok "LC13d a server not up within the limit fails LC13 as not ready, never as a missing ping" $? "returned $rc: $lc13_why"

# ============================== the check, trimmed (R3, decisions log §274 ruling 3) ==============
# The check reads no transcript: its probe's answer and the skill entries are the check. The probe runs without
# DISABLE_AUTOUPDATER, so Claude Code's updates lead (§263). Under an org's managed-mcp.json, where the probe's
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
transcript "$P/-b/s2.jsonl" 2.1.291 "noimport:skills/working-from-a-brief.md"
rep=$(lc); rc=$?;                              passes "LQ5 transcripts the old scan failed on, unreadable, damaged or missing an import, no longer affect the result" $rc "$rep"

# ============================== the stub: the check's own code, verified first ==================
# The stub reads the pin line in the user-level file and verifies the whole install against it before any of the
# install's code runs; a refusal still reports, so a stopped check is never a silent one.
fresh_projects; transcript "$P/-a/s1.jsonl" 2.1.290
stub_refused() {  # NAME RC REPORT REASON: refused, with one REFUSING line, for REASON, and the report says so
    local n; n=$(grep -c 'REFUSING' "$TMP/lc.out")
    if [[ $2 -ne 0 && $n -eq 1 && "$(cat "$TMP/lc.out")" == *"$4"* && "$3" == *"kit load check: FAIL"* && "$3" == *"$4"* ]]; then result "$1" 0
    else result "$1" 1 "exit $2, $n refusal(s), want '$4': $(head -c 200 "$TMP/lc.out" | tr '\n' ' ') | report: $(echo $3 | cut -c1-120)"; fi; }
grep -v 'kit pin:' "$UF" > "$TMP/uf.tmp"; cp "$TMP/uf.tmp" "$UF"
rep=$(lc); rc=$?;                              stub_refused "LS1 the stub refuses a user-level file with no pin line" $rc "$rep" "no kit pin line"
printf '<!-- kit pin: release=v1.0.0 manifest=sha256:12 -->\n' >> "$UF"
rep=$(lc); rc=$?;                              stub_refused "LS2 the stub refuses a malformed pin line" $rc "$rep" "the kit pin line is malformed"
userfile v9.9.9; rep=$(lc); rc=$?;             stub_refused "LS3 the stub refuses a pin whose install is missing" $rc "$rep" "no install for v9.9.9"
userfile v1.0.0 "sha256:$(printf '0%.0s' {1..64})"; rep=$(lc); rc=$?
                                               stub_refused "LS4 the stub refuses a manifest that doesn't match the pin line" $rc "$rep" "manifest doesn't match the pin"
userfile
chmod -R u+w "$I"; echo "# an edit" >> "$I/bin/kit-load-check"
rep=$(lc); rc=$?;                              stub_refused "LS5 the stub refuses a load-check file that doesn't match the manifest" $rc "$rep" "bin/kit-load-check in the install doesn't match its manifest line"
reset_i; chmod -R u+w "$I"; echo "a changed rule" >> "$I/skills/shell-commands.md"
rep=$(lc); rc=$?;                              stub_refused "LS6 the stub refuses an imported file edited in the install" $rc "$rep" "skills/shell-commands.md in the install doesn't match its manifest line"
sum=$(sha "$I/skills/shell-commands.md"); sed -i "s|^[0-9a-f]*  skills/shell-commands.md\$|$sum  skills/shell-commands.md|" "$I/MANIFEST.sha256"
rep=$(lc); rc=$?;                              stub_refused "LS6b and the same file with its manifest line edited to match" $rc "$rep" "manifest doesn't match the pin"
reset_i; chmod u+w "$I/bin"; echo 'print("x")' > "$I/bin/extra.py"
rep=$(lc); rc=$?;                              stub_refused "LS7 the stub refuses a file the manifest doesn't list" $rc "$rep" "bin/extra.py is in the install but not in its manifest"
reset_i
# A refusal reaches the ping as a failure, by its own route: a stand-in curl records what it was sent.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl-args"\n' "$TMP" > "$FB/curl"; chmod +x "$FB/curl"
userfile v9.9.9; rm -f "$TMP/curl-args"; rep=$(lc KIT_LOAD_CHECK_PING=https://ping.invalid/zq-test); rc=$?
grep -q 'https://ping.invalid/zq-test/fail' "$TMP/curl-args" 2>/dev/null && ! grep -q 'zq-test' "$TMP/lc.out" || rc=0
                                               stub_refused "LS8 a refusal pings the check's fail route, and never prints the ping URL" $rc "$rep" "no install for v9.9.9"
userfile; rm -f "$FB/curl"
# The stub hands over to the load check under python3 -I, so a module the caller's environment plants can't stand in
# for it (decisions log §147): here a sitecustomize on PYTHONPATH that exits 0 at once, before any check runs. A run
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
# command on PATH but the ones left out (decisions log §88), each left out with its .exe, which Git Bash runs by the bare
# name; one ln per folder of PATH (hooks_test, §102).
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
# an exit 0 short of the hand-over, a stop on an unset variable, a failed exec (decisions log §100, §105). Copies with one
# line put right after its first check must refuse and report; a passing check must still pass. Under the bash 3 that
# KIT_TEST_BASH3 names too (a test tool, never a kit dependency), skipped, counted, without it.
B3=${KIT_TEST_BASH3:-}; b3why=""
if [[ -z "$B3" ]]; then b3why="KIT_TEST_BASH3 is not set"
elif [[ "$("$B3" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null)" != 3 ]]; then b3why="KIT_TEST_BASH3 is not a bash 3"; fi
inj() {  # SRC DST ANCHOR LINE: DST is SRC with LINE put before its first line starting ANCHOR; 0 only when one line went in
    mkdir -p "${2%/*}"; awk -v a="$3" -v l="$4" '!done && index($0, a) == 1 {print l; done = 1} {print}' "$1" > "$2"; chmod +x "$2"
    [[ $(( $(wc -l < "$2") - $(wc -l < "$1") )) -eq 1 ]]; }
STOPPED="stopped before it finished"
inj "$STUB" "$TMP/stub-exit/kit-load-check-stub" 'pins=$(grep' 'exit 0'; sx=$?
inj "$STUB" "$TMP/stub-unset/kit-load-check-stub" 'pins=$(grep' ': "$zq_unset_probe"'; su=$?
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

echo
echo "load_check_test: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 && $PASS -gt 0 ]]

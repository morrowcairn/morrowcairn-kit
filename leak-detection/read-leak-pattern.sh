# read-leak-pattern.sh — the kit's one reader of a project's do-not-publish list, and the one place that says where it
# lives. Sourced, never run: the hooks source it from the folder they sit in, bin/kit-pin from the install it checks and
# the history audit from beside it, and none holds a reader of its own (hooks test LP0). Sourcing it defines four
# functions and nothing else: no output, no variable, no exit (RF1). A caller runs the selftest before it reads a list,
# and refuses if the file is missing, does not load, lacks a function, or fails the selftest.
#
# kit_list_file
# Where this project's list lives: <home>/.config/morrowcairn/lists/<id>, outside every repository. The id is the one
# line of kit.list-id at the work tree's top, a random name the project tracks, so every clone of it on a machine reads
# the same file, a renamed or moved folder keeps it, and the name tells nothing about the project. Sets KL_ID, KL_FILE
# and KL_SHOW (the same path written from ~, for messages); returns 1 with LP_ERROR saying why when there is no work
# tree, no kit.list-id, one that isn't 32 lowercase hex digits (so it can name no other path), or no home folder.
# It reads kit.list-id and nothing else.
#
# kit_list_home
# The running user's home folder, from the user database by user id (python3's pwd, run isolated): never HOME,
# XDG_CONFIG_HOME or ~, which whoever starts a hook can set, since a content gate finds its terms from a fixed place,
# never from the caller's environment. Prints it, or returns 1. The kit's suites run copies of this file with this one
# body swapped for a scratch home, and check that the copies differ in nothing else (hooks test LH8).
#
# read_leak_pattern FILE
# The list file is read as data, never run as shell. Sourcing it let an apostrophe in a term end its
# quoting, and the rest ran as a command or quietly changed the list; a second assignment silently
# dropped every term of the first. Accepted: blank lines, full-line comments (# first after any
# blanks), and exactly one assignment in a shape the kit documents, LEAK_PATTERN='...' or
# export LEAK_PATTERN='...', with nothing after the closing quote but blanks. Sets LP_VALUE (empty
# when there is no assignment) and LP_EXPORT; on anything else returns 1 with LP_ERROR, which names
# line numbers only, never a term.
#
# read_leak_pattern_selftest
# Runs read_leak_pattern on built-in lists: returns 0 only if every must-refuse list refuses and every
# must-pass list gives its exact value, so a reader edited or cut short stops its caller instead of
# reading a list wrong. Prints nothing, and leaves the caller's LP_* as they were. The hooks suite keeps
# its own copy of the must-refuse set (RF3), so one edit here can't weaken both.

read_leak_pattern() {   # FILE
    local line n=0 at=0 re="^(export )?LEAK_PATTERN='([^']*)'[[:blank:]]*\$"
    LP_VALUE=""; LP_EXPORT=""; LP_ERROR=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        [[ "$line" =~ ^[[:blank:]]*(#.*)?$ ]] && continue
        if [[ ! "$line" =~ $re ]]; then
            LP_ERROR="line $n is not a blank line, a full-line comment or one LEAK_PATTERN='...' with nothing after its closing quote (a term cannot hold an apostrophe)"
            return 1
        fi
        if (( at != 0 )); then
            LP_ERROR="it sets LEAK_PATTERN more than once (lines $at and $n): only the last would count, and the terms before it would be dropped"
            return 1
        fi
        at=$n; LP_EXPORT="${BASH_REMATCH[1]}"; LP_VALUE="${BASH_REMATCH[2]}"
    done < "$1"
    return 0
}

read_leak_pattern_selftest() {
    local LP_VALUE LP_EXPORT LP_ERROR t
    # Must refuse: an apostrophe in a term (one; one in each of two terms; two in one term), a second
    # assignment, anything after the closing quote, an assignment not at the start of its line.
    for t in "LEAK_PATTERN='zqa|zq'b'" "LEAK_PATTERN='zqa|zq'w|zqcmd'z'" "LEAK_PATTERN='zqa|zq'ab'cterm'" \
             "LEAK_PATTERN='zqa'"$'\n'"LEAK_PATTERN='zqb'" "LEAK_PATTERN='zqa'  # a note" "  LEAK_PATTERN='zqa'"; do
        read_leak_pattern <(printf '%s\n' "$t") && return 1
    done
    # Must pass, with the exact value: each documented shape, among comments and blank lines; and a file
    # that sets nothing, which reads as an empty value (the caller refuses that, not the reader).
    read_leak_pattern <(printf '%s\n' "# a note" "" "LEAK_PATTERN='zqa|zqb'" "	# a tabbed note") \
        && [[ "$LP_VALUE" == "zqa|zqb" && -z "$LP_EXPORT" ]] || return 1
    read_leak_pattern <(printf '%s\n' "export LEAK_PATTERN='zqa|zqb' 	") \
        && [[ "$LP_VALUE" == "zqa|zqb" && "$LP_EXPORT" == "export " ]] || return 1
    read_leak_pattern <(printf '%s\n' "# sets nothing") && [[ -z "$LP_VALUE" ]] || return 1
    return 0
}

kit_list_file() {
    local top id home
    KL_ID=""; KL_FILE=""; KL_SHOW=""; LP_ERROR=""
    if ! top=$(git rev-parse --show-toplevel 2>/dev/null) || [[ -z "$top" ]]; then
        LP_ERROR="this repository has no work tree, so no kit.list-id names its list"; return 1
    fi
    if [[ ! -f "$top/kit.list-id" ]]; then
        LP_ERROR="this project has no kit.list-id, the tracked file whose id names its list"; return 1
    fi
    id=$(cat "$top/kit.list-id" 2>/dev/null) || id=""
    if [[ ! "$id" =~ ^[0-9a-f]{32}$ ]]; then
        LP_ERROR="kit.list-id isn't one line of 32 lowercase hex digits, so it names no list"; return 1
    fi
    if ! home=$(kit_list_home) || [[ "$home" != /* ]]; then
        LP_ERROR="the home folder can't be read from the user database (python3 reads it)"; return 1
    fi
    KL_ID=$id; KL_FILE="${home%/}/.config/morrowcairn/lists/$id"; KL_SHOW="~/.config/morrowcairn/lists/$id"
    return 0
}

kit_list_home() {
    command -v python3 >/dev/null 2>&1 || return 1
    python3 -I - <<'PY'
import os, pwd, sys
try:
    home = pwd.getpwuid(os.getuid()).pw_dir
except KeyError:
    sys.exit(1)
if not home.startswith("/") or "\n" in home:
    sys.exit(1)
print(home)
PY
}

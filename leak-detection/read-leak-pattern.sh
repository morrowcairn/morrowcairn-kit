# read-leak-pattern.sh — the kit's one reader of .git/leak-pattern. Sourced, never run: pre-push sources it
# from the folder it sits in and bin/kit-pin from the install it checks, and neither holds a reader of its
# own (hooks test LP0). Sourcing it defines two functions and nothing else: no output, no variable, no exit (RF1).
# A caller runs the selftest before it reads a list, and refuses if the file is missing, does not load,
# lacks either function, or fails the selftest.
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

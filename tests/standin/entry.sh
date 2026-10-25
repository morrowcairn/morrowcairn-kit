#!/usr/bin/env bash
#
# entry.sh — inside a stand-in container, as root: set up one org-like condition, then run the kit's git-level suites
# as a user without sudo, one log a suite in /out. tests/standin/run.sh starts it; nothing here runs on the host.
#
#   entry.sh CONDITION       no-sudo | user-gitleaks | it-hookspath | global-hookspath | old-git
#
# Read-only mounts, from the runner: /opt/kit-src (a one-commit snapshot of the kit), /opt/gitleaks (the binary),
# /opt/it-hook (the IT hook fixture). Writable: /out. The container has no network.
#   no-sudo           the user has no sudo and isn't root; gitleaks is where an admin put it (/usr/local/bin)
#   user-gitleaks     the same user, with gitleaks only in their own ~/.local/bin, as a user without admin installs it
#   it-hookspath      user-gitleaks, plus core.hooksPath set at the system level to a root-owned folder, as IT might
#   global-hookspath  user-gitleaks, plus core.hooksPath set in the user's own global config
#   old-git           user-gitleaks, on the older image (its git below the 2.31 that pre-push's merge scan needs)
# Under the two hooks-path conditions it also runs smoke_test once more under the user's own git config, not the empty
# global file the suites use, so kit-pin to, a commit and a push meet the org's hooks path as a user's would; that run
# passes only if the org's hook ran in its project for both the commit and the push (§288's gap; §294).
set -u
cond=${1:?a condition}; T=tester; H=/home/tester
case "$cond" in no-sudo|user-gitleaks|it-hookspath|global-hookspath|old-git) ;; *) echo "unknown condition: $cond" >&2; exit 2 ;; esac

install -d -o "$T" -g "$T" "$H/.local/bin" "$H/logs"
cp -a /opt/kit-src "$H/kit" && chown -R "$T:$T" "$H/kit" || exit 2
# A test identity for the user's own commits (the suites set their own where they need one); nothing else global.
runuser -u "$T" -- env HOME="$H" git config --global user.name standin-tester
runuser -u "$T" -- env HOME="$H" git config --global user.email standin-tester@invalid.local

if [[ "$cond" == no-sudo ]]; then install -m 0755 /opt/gitleaks /usr/local/bin/gitleaks
else install -o "$T" -g "$T" -m 0755 /opt/gitleaks "$H/.local/bin/gitleaks"; fi
if [[ "$cond" == it-hookspath ]]; then
    install -d -m 0755 /etc/it-hooks
    for h in pre-commit pre-push; do install -m 0755 /opt/it-hook "/etc/it-hooks/$h"; done
    git config --system core.hooksPath /etc/it-hooks
fi
if [[ "$cond" == global-hookspath ]]; then
    install -d -o "$T" -g "$T" "$H/my-hooks"
    for h in pre-commit pre-push; do install -o "$T" -g "$T" -m 0755 /opt/it-hook "$H/my-hooks/$h"; done
    runuser -u "$T" -- env HOME="$H" git config --global core.hooksPath "$H/my-hooks"
fi

{
    echo "condition: $cond"
    echo "system: $(. /etc/os-release && echo "$PRETTY_NAME")"
    echo "git: $(git --version)"
    echo "python3: $(python3 --version 2>&1)"
    echo "bash: $(bash --version | head -n 1)"
    echo "user: $(runuser -u "$T" -- id)"
    echo "sudo: $(command -v sudo || echo none)"
    echo "gitleaks: $(runuser -u "$T" -- env PATH="$H/.local/bin:/usr/local/bin:/usr/bin:/bin" sh -c 'command -v gitleaks && gitleaks version' | tr '\n' ' ')"
    echo "core.hooksPath, system: $(git config --system --get core.hooksPath || echo unset)"
    echo "core.hooksPath, the user's global: $(runuser -u "$T" -- env HOME="$H" git config --global --get core.hooksPath || echo unset)"
} > /out/facts.txt 2>&1

rc=0
for s in hooks_test install_test smoke_test; do
    runuser -u "$T" -- env -i HOME="$H" USER="$T" LOGNAME="$T" LANG=C.UTF-8 \
        PATH="$H/.local/bin:/usr/local/bin:/usr/bin:/bin" \
        nice -n 19 bash -c 'cd "$HOME/kit" && bash "tests/$1.sh"' _ "$s" > "$H/logs/$s.log" 2>&1
    st=$?; echo "$s exit $st" >> /out/exits.txt; (( st == 0 )) || rc=1
done
if [[ "$cond" == it-hookspath || "$cond" == global-hookspath ]]; then
    install -d -o "$T" -g "$T" "$H/own"
    runuser -u "$T" -- env -i HOME="$H" USER="$T" LOGNAME="$T" LANG=C.UTF-8 TMPDIR="$H/own" SMOKE_OWN_GLOBAL=1 \
        PATH="$H/.local/bin:/usr/local/bin:/usr/bin:/bin" \
        nice -n 19 bash -c 'cd "$HOME/kit" && bash tests/smoke_test.sh' > "$H/logs/smoke_own_config.log" 2>&1
    st=$?; ran="smoke_own_config: smoke exit $st; the org's hooks ran in smoke's project:"
    for h in pre-commit pre-push; do
        n=$(grep -c -E "^it-hook: $h ran in $H/own/kit-smoke\.[^/]+/project\$" /tmp/it-hook.log 2>/dev/null) || n=0
        ran="$ran $h $n"; (( n > 0 )) || st=1
    done
    echo "$ran" >> "$H/logs/smoke_own_config.log"
    echo "smoke_own_config exit $st" >> /out/exits.txt; (( st == 0 )) || rc=1
fi
[[ -f /tmp/it-hook.log ]] && cp /tmp/it-hook.log /out/it-hook.log
cp "$H"/logs/*.log /out/
chown -R "${HOST_UID:-0}" /out
exit "$rc"

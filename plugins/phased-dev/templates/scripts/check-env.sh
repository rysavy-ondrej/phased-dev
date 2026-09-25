#!/usr/bin/env bash
# Check that this machine can run the project: the operating system, the git and
# GitHub tooling, the tools the phased-dev scripts need, and the project's own
# toolchain (TOOLS in scripts/method.conf). Reports only -- never installs. For
# each missing piece it prints the install command for the package manager it
# found, so the git-setup and dev-env skills can ask the owner before running it.
#
#   scripts/check-env.sh            everything
#   scripts/check-env.sh git        git, gh, identity, sign-in, remote only
#   scripts/check-env.sh method     the method's own script requirements only
#   scripts/check-env.sh project    the project toolchain (TOOLS) only
#
# Exit 0 = nothing missing. 1 = something missing or incompatible. 2 = cannot run.
#
# Deliberately written for bash 3.2 and POSIX tools, so that it runs -- and can
# say what is missing -- on a stock macOS before anything has been installed.
set -u
here=$(cd -- "$(dirname -- "$0")" && pwd)
root=$(cd -- "$here/.." && pwd)
what=${1:-all}

fail=0; warn=0
ok()   { printf 'ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '      install: %s\n' "$2"; }
note() { warn=$((warn + 1)); printf 'WARN  %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; }
have() { command -v "$1" >/dev/null 2>&1; }
# version_ge <have> <need>: true when have >= need (dotted numbers)
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$2" ]; }
first_version() { grep -oE '[0-9]+(\.[0-9]+)+' | head -1; }

# Everything below reads versions with these; without them its answers would be wrong.
for t in grep awk sed sort head uname; do
    command -v "$t" >/dev/null 2>&1 || { echo "check-env: basic tool '$t' is missing -- cannot check this machine reliably" >&2; exit 2; }
done

# --- the platform ------------------------------------------------------------
os=unknown; distro=; arch=$(uname -m 2>/dev/null)
case "$(uname -s 2>/dev/null)" in
    Linux)  os=linux
            [ -r /etc/os-release ] && distro=$(. /etc/os-release && echo "${PRETTY_NAME:-$NAME}")
            grep -qi microsoft /proc/version 2>/dev/null && distro="$distro (WSL)" ;;
    Darwin) os=macos; distro="macOS $(sw_vers -productVersion 2>/dev/null)" ;;
    MINGW*|MSYS*|CYGWIN*) os=windows; distro="Windows ($(uname -s))" ;;
esac
pm=
for p in apt-get dnf yum pacman zypper apk brew winget choco scoop; do have "$p" && { pm=$p; break; }; done
if [ "$(id -u 2>/dev/null)" = 0 ]; then sudo=; elif have sudo; then sudo="sudo "; else sudo="(no sudo) "; fi

# install_cmd <tool> -> the command for this package manager, or empty
install_cmd() {
    local t=$1 pkg=
    case "$pm:$t" in
        brew:gh) pkg=gh ;;          *:gh) pkg=gh ;;
        brew:gnu-time) pkg=gnu-time ;; *:gnu-time) pkg=time ;;
        brew:bash) pkg=bash ;;
        brew:findutils) pkg=findutils ;; *:findutils) pkg=findutils ;;
        brew:coreutils) pkg=coreutils ;; *:coreutils) pkg=coreutils ;;
        *:node) case "$pm" in apt-get|dnf|yum|zypper) pkg=nodejs ;; *) pkg=node ;; esac ;;
        *) pkg=$t ;;
    esac
    case "$pm" in
        apt-get) echo "${sudo}apt-get install -y $pkg" ;;
        dnf|yum) echo "${sudo}$pm install -y $pkg" ;;
        pacman)  [ "$pkg" = gh ] && pkg=github-cli; echo "${sudo}pacman -S --noconfirm $pkg" ;;
        zypper)  echo "${sudo}zypper install -y $pkg" ;;
        apk)     echo "${sudo}apk add $pkg" ;;
        brew)    echo "brew install $pkg" ;;
        winget)  [ "$pkg" = gh ] && echo "winget install --id GitHub.cli" || echo "winget install $pkg" ;;
        choco)   echo "choco install -y $pkg" ;;
        scoop)   echo "scoop install $pkg" ;;
        *)       echo "" ;;
    esac
}

echo "platform: ${distro:-$os} · $arch · package manager: ${pm:-none found}"
case "$os" in
    windows) bad "native Windows shell: the phased-dev scripts need a POSIX environment" "use WSL2 (wsl --install) and work inside it" ;;
    unknown) note "unrecognised operating system '$(uname -s 2>/dev/null)' -- results below may be incomplete" ;;
esac
[ -z "$pm" ] && note "no package manager found -- install commands cannot be suggested"
echo

# --- git and GitHub ----------------------------------------------------------
check_git() {
    echo "[git and GitHub]"
    if have git; then
        v=$(git --version | first_version)
        if version_ge "$v" 2.28; then ok "git $v"; else bad "git $v is older than 2.28 (needed for init.defaultBranch)" "$(install_cmd git)"; fi
        n=$(git config user.name 2>/dev/null); e=$(git config user.email 2>/dev/null)
        if [ -n "$n" ] && [ -n "$e" ]; then ok "git identity: $n <$e>"
        else bad "git identity not set -- commits would fail or carry a wrong author" "git config --global user.name \"Your Name\" && git config --global user.email you@example.com"; fi
    else
        bad "git is not installed" "$(install_cmd git)"
    fi

    if have gh; then
        ok "gh $(gh --version 2>/dev/null | first_version)"
        if gh auth status >/dev/null 2>&1; then
            ok "gh is signed in ($(gh api user --jq .login 2>/dev/null || echo 'account unknown'))"
        else
            bad "gh is not signed in to GitHub" "gh auth login   (interactive -- the owner runs it)"
        fi
    else
        bad "gh (GitHub CLI) is not installed -- the method pushes to and reads CI from GitHub" "$(install_cmd gh)"
        [ "$pm" = apt-get ] && printf '      %s\n' "(older Debian/Ubuntu: add GitHub's apt repository first -- https://github.com/cli/cli/blob/trunk/docs/install_linux.md)"
    fi

    if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
        url=$(git -C "$root" remote get-url origin 2>/dev/null || true)
        branch=$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null || true)
        [ "$branch" = main ] && ok "on branch main" || note "current branch is '${branch:-detached}', the method works on main"
        case "$url" in
            "") note "no 'origin' remote -- phases cannot be pushed yet" "gh repo create <owner>/<name> --private --source . --remote origin   (ask the owner first)" ;;
            *github.com*)
                ok "origin is GitHub: $url"
                if have gh && gh auth status >/dev/null 2>&1; then
                    gh repo view "$url" --json name >/dev/null 2>&1 && ok "the signed-in account can see the repository" \
                        || bad "the signed-in gh account cannot see $url" "check the account (gh auth status) or the repository's access"
                fi ;;
            *) note "origin is not GitHub ($url) -- gh-based steps (repo, CI status) will not work" ;;
        esac
    else
        note "not a git repository yet" "git init -b main   (ask the owner first)"
    fi
    echo
}

# --- what the phased-dev scripts need ----------------------------------------
check_method() {
    echo "[method scripts]"
    # bash >= 4.3: mapfile and negative array indices (task-audit.sh)
    b=$(bash -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"' 2>/dev/null)
    if [ -n "$b" ] && version_ge "$b" 4.3; then ok "bash $b"
    else bad "bash ${b:-missing} -- the scripts need 4.3 or newer" "$(install_cmd bash)$([ "$os" = macos ] && echo '   (then make sure the new bash comes first in PATH)')"; fi

    for t in awk sed grep sort comm git; do have "$t" || bad "$t is missing" "$(install_cmd "$t")"; done

    # GNU find (-printf) for data-inventory.sh
    if find . -maxdepth 0 -printf '' >/dev/null 2>&1; then ok "find supports -printf (GNU)"
    else bad "find is not GNU find (-printf missing) -- data-inventory.sh needs it" "$(install_cmd findutils)$([ "$os" = macos ] && echo '   (put $(brew --prefix)/opt/findutils/libexec/gnubin first in PATH)')"; fi

    have numfmt && ok "numfmt" || bad "numfmt missing (GNU coreutils) -- data-inventory.sh sizes" "$(install_cmd coreutils)"
    have sha256sum && ok "sha256sum" || bad "sha256sum missing (GNU coreutils) -- measure.sh output hashes" "$(install_cmd coreutils)"
    have file && ok "file" || note "file missing -- data-inventory.sh skips detected types" "$(install_cmd file)"

    gt=
    for c in /usr/bin/time gtime; do
        if have "$c" && "$c" --version 2>&1 | grep -qi 'GNU'; then gt=$c; break; fi
    done
    [ -n "$gt" ] && ok "GNU time ($gt)" || bad "GNU time missing -- measure.sh needs it for peak memory" "$(install_cmd gnu-time)"

    have node && ok "node $(node --version 2>/dev/null | first_version) (caveman's hooks)" \
        || note "node missing -- the caveman plugin's hooks will not run" "$(install_cmd node)"
    echo
}

# --- the project's own toolchain ---------------------------------------------
check_project() {
    echo "[project toolchain]"
    TOOLS=()
    [ -r "$root/scripts/method.conf" ] && . "$root/scripts/method.conf" 2>/dev/null
    if [ ${#TOOLS[@]} -eq 0 ]; then
        note "no TOOLS declared in scripts/method.conf -- fill it from docs/SPEC.md §3 (dev-env skill)"
        echo; return
    fi
    for entry in "${TOOLS[@]}"; do
        # name|command that prints a version|minimum version|what it is for|install hint (optional)
        IFS='|' read -r name vcmd min purpose hint <<EOF
$entry
EOF
        bin=${vcmd%% *}
        if ! have "$bin"; then
            bad "$name missing -- $purpose" "${hint:-$(install_cmd "$bin")}"
            continue
        fi
        v=$(sh -c "$vcmd" 2>&1 | first_version)
        if [ -z "$min" ]; then ok "$name ${v:-(version unknown)}"
        elif [ -n "$v" ] && version_ge "$v" "$min"; then ok "$name $v (>= $min)"
        else bad "$name ${v:-(version unknown)} -- need >= $min for $purpose" "${hint:-$(install_cmd "$bin")}"; fi
    done
    echo
}

case "$what" in
    all)     check_git; check_method; check_project ;;
    git)     check_git ;;
    method)  check_method ;;
    project) check_project ;;
    *) echo "usage: scripts/check-env.sh [all|git|method|project]" >&2; exit 2 ;;
esac

echo "environment: $fail missing or incompatible, $warn warning(s)"
[ "$fail" -eq 0 ]

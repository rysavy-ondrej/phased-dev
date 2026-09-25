#!/usr/bin/env bash
#
# devbox-lxd.sh — manage the devbox LXD development environments.
#
# Run this ON the LXD host (prepared by setup.sh in this directory).
#
#   devbox-lxd.sh init                 # prepare LXD (storage pool + bridge)
#   devbox-lxd.sh install              # build dev-base and snapshot it as 'clean'
#   devbox-lxd.sh new    <name> [opts] # clone a project instance (SSH access by default)
#   devbox-lxd.sh auth   <name>        # log an instance in to GitHub
#   devbox-lxd.sh show   <name>        # how to connect to an existing instance
#   devbox-lxd.sh remove <name>        # delete a project instance
#   devbox-lxd.sh list                 # show instances
#
# Nothing here is tied to a particular machine. The connection hints it prints (host
# address, SSH user, which key to use) are worked out from the running system; see
# host_addr, host_ssh and ssh_key_hint. To pin them, set DEVBOX_HOST / DEVBOX_SSH_KEY
# in the environment or in ~/.config/devbox-lxd.conf.
#
set -euo pipefail

BASE=dev-base
SNAPSHOT=clean
IMAGE=ubuntu:26.04

# Defaults for `new`; override with --cpu / --memory / --ssh-port.
DEF_CPU=4
DEF_MEM=4GiB

# Remote SSH access (for VS Code Remote-SSH, scp, rsync) is ON by default; --no-ssh
# opts out. Ports are auto-allocated from this base upward, one per instance.
SSH_PORT_BASE=2201
SSH_PORT_MAX=2299

# Optional overrides for the connection hints. Normally left empty and detected.
#   DEVBOX_HOST     how your workstation reaches this host: an ssh alias, host name,
#                   IP, or user@host (default: <you>@<the address you connected to>)
#   DEVBOX_SSH_KEY  private key path ON YOUR WORKSTATION for the ~/.ssh/config block
#                   (default: guessed from the key you logged in here with)
# The environment wins over the config file, so a one-off `DEVBOX_HOST=x cmd` works.
DEVBOX_CONF=${DEVBOX_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/devbox-lxd.conf}
env_host=${DEVBOX_HOST:-}; env_key=${DEVBOX_SSH_KEY:-}
# shellcheck disable=SC1090
[[ -r $DEVBOX_CONF ]] && . "$DEVBOX_CONF"
DEVBOX_HOST=${env_host:-${DEVBOX_HOST:-}}
DEVBOX_SSH_KEY=${env_key:-${DEVBOX_SSH_KEY:-}}
unset env_host env_key

# Set by --git-name / --git-email; see resolve_git_identity.
OPT_GIT_NAME=""; OPT_GIT_EMAIL=""

readonly RED=$'\033[31m' GRN=$'\033[32m' YEL=$'\033[33m' BLD=$'\033[1m' RST=$'\033[0m'

log()  { printf '%s==>%s %s\n' "$GRN$BLD" "$RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YEL" "$RST" "$*" >&2; }
die()  { printf '%s[error]%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }

# ---------------------------------------------------------------- host facts

# This script as it should be typed on the host, with $HOME shown as '~' so the hints
# also work inside ssh commands ('~' then expands on the host, not the workstation).
self_path() {
    local p; p=$(readlink -f "$0" 2>/dev/null || echo "$0")
    # shellcheck disable=SC2088  # a literal '~' is the point
    [[ $p == "$HOME"/* ]] && p="~/${p#"$HOME"/}"
    printf '%s\n' "$p"
}
SELF=$(self_path)

# The address your workstation uses to reach this host. Best source: the server side
# of the SSH connection you are on right now, i.e. the address you actually dialled.
# Otherwise the source address of the default route, then the first `hostname -I`.
host_addr() {
    local a=""
    [[ -n ${SSH_CONNECTION:-} ]] && a=$(awk '{print $3}' <<<"$SSH_CONNECTION")
    [[ -z $a ]] && a=$(ip -4 route get 1.1.1.1 2>/dev/null \
                        | awk '{for (i = 1; i < NF; i++) if ($i == "src") {print $(i+1); exit}}')
    [[ -z $a ]] && a=$(hostname -I 2>/dev/null | awk '{print $1}')
    printf '%s\n' "${a:-$(hostname -f 2>/dev/null || hostname)}"
}

# What to put after `ssh` on the workstation to reach this host.
host_ssh() {
    if [[ -n $DEVBOX_HOST ]]; then printf '%s\n' "$DEVBOX_HOST"
    else printf '%s@%s\n' "$(id -un)" "$(host_addr)"
    fi
}

# HostName for the generated ~/.ssh/config block: DEVBOX_HOST minus any user@, but
# only if it is a real name or address. An ssh alias from your workstation's
# ~/.ssh/config does not resolve as a HostName, so fall back to the detected address.
host_name() {
    local h=${DEVBOX_HOST#*@}
    if [[ -n $h ]] && getent hosts "$h" >/dev/null 2>&1; then printf '%s\n' "$h"
    else host_addr
    fi
}

# Fingerprint ("ECDSA SHA256:...") of the key that authenticated the current SSH
# session, from sshd's "Accepted publickey" log line for this exact client ip:port.
# Readable by members of 'adm' (the default admin on Ubuntu). Empty if unknown.
login_key_fp() {
    [[ -n ${SSH_CONNECTION:-} ]] || return 0
    local cip cport pat
    read -r cip cport _ <<<"$SSH_CONNECTION"
    pat="Accepted publickey for $(id -un) from $cip port $cport "
    {
        journalctl -q --no-pager -o cat -t sshd -t sshd-session 2>/dev/null
        cat /var/log/auth.log 2>/dev/null
    } | grep -F "$pat" | tail -1 | sed -n 's/.* ssh2: \([A-Z0-9-]*\) \(SHA256:[^ ]*\).*/\1 \2/p'
}

# Conventional private-key file name for a key type as ssh-keygen -l prints it. The
# '~' stays literal: the path is for the workstation's ~/.ssh/config.
# shellcheck disable=SC2088
default_key_file() {
    case ${1^^} in
        ED25519-SK*) echo '~/.ssh/id_ed25519_sk' ;;
        ECDSA-SK*)   echo '~/.ssh/id_ecdsa_sk' ;;
        ED25519*)    echo '~/.ssh/id_ed25519' ;;
        ECDSA*)      echo '~/.ssh/id_ecdsa' ;;
        RSA*)        echo '~/.ssh/id_rsa' ;;
        *)           echo "" ;;
    esac
}

# The IdentityFile line (plus explanatory comment lines) for the ~/.ssh/config block.
# $1 = an authorized_keys file whose keys the instance accepts (may be empty/missing).
#
# The server cannot know what your private key FILE is called, only which public key
# you use. So: DEVBOX_SSH_KEY if set; else the key you logged in here with, provided
# the instance accepts it; else the only key in authorized_keys. That key's type gives
# the conventional file name, and its fingerprint is printed so you can find the real
# file if yours is named otherwise.
ssh_key_hint() {
    local ak=${1:-} fp="" type="" file="" fps=""
    if [[ -n $DEVBOX_SSH_KEY ]]; then
        printf '  IdentityFile %s\n' "$DEVBOX_SSH_KEY"
        return 0
    fi

    # ssh-keygen -l prints "<bits> SHA256:... <comment> (TYPE)" per key.
    [[ -s $ak ]] && fps=$(ssh-keygen -lf "$ak" 2>/dev/null || true)

    fp=$(login_key_fp)
    if [[ -n $fp && -n $fps ]] && ! grep -qF " ${fp#* } " <<<"$fps"; then
        fp=""    # you logged in with a key this instance does not accept
    fi
    if [[ -z $fp && $(grep -c . <<<"$fps") -eq 1 ]]; then
        fp="$(sed -n 's/.*(\([^)]*\))$/\1/p' <<<"$fps") $(awk '{print $2}' <<<"$fps")"
    fi

    if [[ -z $fp ]]; then
        cat <<EOF
  # IdentityFile ~/.ssh/<your key>   (any key in the instance's
  #   /root/.ssh/authorized_keys works; ssh tries ~/.ssh/id_* by default)
EOF
        return 0
    fi

    type=${fp%% *}; fp=${fp#* }
    file=$(default_key_file "$type")
    cat <<EOF
  # the $type key $fp; if your file has another name, find it with:
  #   for k in ~/.ssh/*.pub; do ssh-keygen -lf "\$k"; done | grep '$fp'
  IdentityFile ${file:-~/.ssh/<your $type key>}
EOF
}

need_lxc() {
    command -v lxc >/dev/null 2>&1 || die "lxc not found. Install LXD:
    sudo snap install lxd --channel=5.21/stable
    sudo usermod -aG lxd \$USER   # then log out and back in"
    # Membership in the 'lxd' group is enough; sudo is not (and may need a password).
    lxc list >/dev/null 2>&1 || die "cannot reach the LXD daemon.
    Are you in the 'lxd' group? Run 'id' to check, then log out and back in.
    If LXD was never initialized, run: $0 init"
}

instance_exists() { lxc info "$1" >/dev/null 2>&1; }

# Ask the API, not `lxc info`: its snapshot table renders as "| clean | ... |", so
# line-oriented greps against it silently never match.
snapshot_exists() {
    lxc query "/1.0/instances/$1/snapshots" 2>/dev/null \
        | grep -q "\"/1.0/instances/$1/snapshots/$2\""
}

wait_for_ip() {
    local name=$1 i ip
    for ((i = 0; i < 60; i++)); do
        ip=$(lxc list "$name" -c4 --format csv 2>/dev/null || true)
        [[ -n $ip ]] && { echo "${ip%% *}"; return 0; }
        sleep 2
    done
    warn "$name did not get an IPv4 address within 120s"
    return 1
}

# Run a command inside an instance as a LOGIN shell.
# This matters: the toolchain PATH lives in /etc/profile.d/devtools.sh, which only a
# login shell reads. With `bash -c`, uv/cargo/pwsh are invisible.
in_ct() { lxc exec "$1" -- bash -lc "$2"; }

# apt inside a container. NEEDRESTART_SUSPEND=1 is essential: without it, needrestart
# restarts ssh/systemd-networkd and the teardown propagates out, dropping your SSH
# session to the host mid-upgrade.
apt_ct() {
    lxc exec "$1" -- env DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 \
        bash -lc "$2"
}

# ---------------------------------------------------------------- init

cmd_init() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --git-name)  OPT_GIT_NAME=$2;  shift 2 ;;
            --git-email) OPT_GIT_EMAIL=$2; shift 2 ;;
            *)           die "unknown option: $1" ;;
        esac
    done

    command -v lxc >/dev/null 2>&1 || die "lxc not found. Install LXD first:
    sudo snap install lxd --channel=5.21/stable
    sudo usermod -aG lxd \$USER   # then log out and back in"

    if lxc storage list --format csv 2>/dev/null | grep -q .; then
        log "LXD already initialized:"
        lxc storage list
        lxc network list
        cmd_init_identity
        return 0
    fi

    log "Initializing LXD (lxd init --minimal)"
    # No sudo: the lxd group grants access to the daemon socket, and sudo may
    # prompt for a password.
    lxd init --minimal

    log "Storage pools:"; lxc storage list
    log "Networks:";      lxc network list

    cat <<'EOF'

Note: --minimal creates a 'dir' storage pool, which has no copy-on-write. Each
`new` is therefore a full filesystem copy (~6 GB, ~40 s measured). That is fine
for a handful of projects; for many, use a btrfs/zfs pool instead:

    lxc storage create fast btrfs size=60GiB
    lxc profile device set default root pool=fast
EOF

    cmd_init_identity
}

# Log this HOST in to GitHub and record a git identity on it. Doing this once here
# means every later `new` inherits both without asking.
cmd_init_identity() {
    echo

    if ! command -v gh >/dev/null 2>&1; then
        warn "gh is not installed on this host; skipping GitHub setup"
    elif gh auth status >/dev/null 2>&1; then
        log "This host is already logged in to GitHub: $(gh api user --jq .login 2>/dev/null || echo '?')"
    elif [[ -n ${GH_TOKEN:-${GITHUB_TOKEN:-}} ]]; then
        log "Logging this host in to GitHub with the token from the environment"
        printf '%s\n' "${GH_TOKEN:-$GITHUB_TOKEN}" | gh auth login --with-token \
            || warn "token rejected by GitHub"
    elif [[ -t 0 && -t 1 ]]; then
        log "Logging this host in to GitHub (this is asked once; instances inherit it)"
        gh auth login --hostname github.com --git-protocol https \
            || warn "gh auth login did not complete"
    else
        warn "this host is not logged in to GitHub, and there is no terminal to log in with.
    Re-run from a terminal so gh can prompt:
      ssh -t $(host_ssh) '$SELF init'
    or:
      GH_TOKEN=ghp_xxx $SELF init"
    fi

    echo
    if resolve_git_identity; then
        persist_git_identity_on_host
    else
        warn "no git identity found and no terminal to ask on.
    Set it so project containers can commit:
      ssh -t $(host_ssh) '$SELF init'
    or:
      $SELF init --git-name 'Your Name' --git-email you@example.com"
    fi
}

# ---------------------------------------------------------------- install

cmd_install() {
    need_lxc

    if instance_exists "$BASE"; then
        if snapshot_exists "$BASE" "$SNAPSHOT"; then
            die "$BASE already has snapshot '$SNAPSHOT'.
    To rebuild the toolchain, update $BASE and take a NEW snapshot
    (e.g. clean-$(date +%Y-%m)) rather than mutating '$SNAPSHOT'."
        fi
        log "$BASE exists; continuing (this script is idempotent)"
        [[ $(lxc list "$BASE" -c s --format csv) == RUNNING ]] || lxc start "$BASE"
    else
        log "Launching $BASE from $IMAGE"
        lxc launch "$IMAGE" "$BASE"
    fi

    log "Waiting for network"
    wait_for_ip "$BASE" >/dev/null || die "$BASE has no network; cannot install"

    # 2a — base apt packages. Verified set, including cmake/pip/venv/jq which the
    # first run missed.
    log "Installing base packages (apt)"
    apt_ct "$BASE" '
        apt-get update -qq
        apt-get upgrade -y -qq
        apt-get install -y -qq build-essential cmake git curl wget ca-certificates \
                               gnupg unzip jq pkg-config libssl-dev \
                               python3-pip python3-venv gh'

    # 2b — uv, Rust, Node. Ubuntu 26.04 already ships Python 3.14, so no Python install.
    log "Installing uv (Python tooling)"
    in_ct "$BASE" 'command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh'

    log "Installing Rust"
    in_ct "$BASE" 'command -v cargo >/dev/null || \
        curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path'

    log "Installing Node.js LTS (NodeSource)"
    apt_ct "$BASE" '
        command -v node >/dev/null || {
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            apt-get install -y -qq nodejs
        }'

    # PATH must be set in TWO places, and both are needed:
    #   /etc/profile.d  -> login shells   (lxc exec ... bash -lc, interactive ssh)
    #   /etc/environment -> non-login     (ssh host 'cmd', scp, VS Code Remote-SSH)
    # With only profile.d, `ssh -p 2201 root@<host> 'pwsh --version'` fails with
    # "command not found" even though pwsh is installed.
    log "Writing PATH to /etc/profile.d/devtools.sh and /etc/environment"
    lxc exec "$BASE" -- bash -c \
        'printf "export PATH=\$HOME/.local/bin:\$HOME/.cargo/bin:\$HOME/.dotnet/tools:\$PATH\n" \
             > /etc/profile.d/devtools.sh
         chmod +x /etc/profile.d/devtools.sh
         printf "PATH=\"/root/.local/bin:/root/.cargo/bin:/root/.dotnet/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin\"\n" \
             > /etc/environment'

    # 2c — .NET from the STOCK Ubuntu archive. No Microsoft feed: dotnet-sdk-10.0 is in
    # resolute/main. The ubuntu:26.04 image already ships packages-microsoft-prod, but
    # neither dotnet nor powershell comes from it.
    log "Installing .NET SDK 10 (Ubuntu archive)"
    apt_ct "$BASE" 'apt-get install -y -qq dotnet-sdk-10.0'

    # PowerShell is in NEITHER the Ubuntu archive NOR the Microsoft 'resolute' feed.
    # It installs as a .NET global tool. (The host uses a snap; snaps do not run inside
    # an unprivileged container, so that approach does not transfer.)
    log "Installing PowerShell (dotnet global tool)"
    in_ct "$BASE" 'command -v pwsh >/dev/null || dotnet tool install --global PowerShell'

    # Bake the git identity into the image when the host already knows it, so clones start
    # with a working commit identity. Never prompts here — `init` and `new` do that.
    if resolve_git_identity noprompt; then
        log "Setting git identity in $BASE: $GIT_NAME <$GIT_EMAIL>"
        lxc exec "$BASE" -- bash -lc \
            "git config --global user.name '$GIT_NAME'; git config --global user.email '$GIT_EMAIL'"
    else
        warn "no git identity known yet — run '$0 init' to record one"
    fi

    # 2d — Claude Code is the only AI agent used in these environments.
    log "Installing Claude Code"
    in_ct "$BASE" 'command -v claude >/dev/null || npm install -g @anthropic-ai/claude-code'

    cmd_verify "$BASE"

    log "Cleaning apt cache before snapshotting"
    [[ $(lxc list "$BASE" -c s --format csv) == RUNNING ]] || lxc start "$BASE"
    lxc exec "$BASE" -- bash -c 'apt-get clean' || true

    log "Stopping $BASE and taking the golden '$SNAPSHOT' snapshot"
    lxc stop "$BASE"
    lxc snapshot "$BASE" "$SNAPSHOT"

    lxc info "$BASE" | sed -n '/Snapshots:/,$p'
    log "Done. $BASE is the golden image; keep it stopped. Clone it with: $0 new <name>"
}

# ---------------------------------------------------------------- verify

cmd_verify() {
    need_lxc
    local target=${1:-$BASE}
    instance_exists "$target" || die "no such instance: $target"

    # dev-base is normally stopped (it is the golden image). Start it if needed, but
    # put it back the way we found it so `verify` has no side effects.
    local was_stopped=0
    if [[ $(lxc list "$target" -c s --format csv) != RUNNING ]]; then
        was_stopped=1
        lxc start "$target"
        wait_for_ip "$target" >/dev/null || true
    fi
    restore_state() { [[ $was_stopped -eq 1 ]] && lxc stop "$target" 2>/dev/null || true; }

    log "Toolchain in $target"
    local missing
    missing=$(lxc exec "$target" -- bash -lc '
        miss=""
        for c in gcc g++ make cmake git curl wget python3 pip3 uv node npm \
                 cargo rustc dotnet pwsh claude jq gh; do
            if command -v "$c" >/dev/null 2>&1; then
                printf "  %-8s %s\n" "$c" "$("$c" --version 2>&1 | head -1 | cut -c1-45)"
            else
                printf "  %-8s MISSING\n" "$c"; miss="$miss $c"
            fi
        done
        [ -n "$miss" ] && echo "MISSING:$miss"
        true')
    echo "$missing" | grep -v '^MISSING:'
    if echo "$missing" | grep -q '^MISSING:'; then
        warn "missing tools:$(echo "$missing" | sed -n 's/^MISSING://p')"
        restore_state
        return 1
    fi
    log "All tools present"

    # Catch the PATH trap: a tool can be visible to a login shell but not to
    # `ssh host 'cmd'` / VS Code Remote-SSH. Those go through PAM, which reads
    # /etc/environment — NOT /etc/profile.d. (`lxc exec ... bash -c` reads neither, so
    # probing with it would be misleading; check the file itself.)
    if ! lxc exec "$target" -- grep -q '\.dotnet/tools' /etc/environment 2>/dev/null; then
        warn "/etc/environment in $target lacks the toolchain PATH.
    Direct SSH ('ssh -p <port> root@<host> pwsh --version') will fail with
    'command not found' even though the tools are installed."
    fi
    restore_state
}

# ---------------------------------------------------------------- git identity

# A container that clones a repo needs user.name/user.email or the first commit fails
# with "Please tell me who you are". Resolve it once, from the first source that has it:
#
#   1. --git-name / --git-email flags
#   2. GIT_AUTHOR_NAME / GIT_AUTHOR_EMAIL in the environment
#   3. this host's own `git config --global`         <- what `init` populates
#   4. `gh api user` (.name/.email) once gh is authenticated
#   5. an interactive prompt
#
# Sets the globals GIT_NAME and GIT_EMAIL. Returns 1 if either is still unknown.
GIT_NAME=""; GIT_EMAIL=""

resolve_git_identity() {
    local want_prompt=${1:-prompt}
    GIT_NAME=${OPT_GIT_NAME:-${GIT_AUTHOR_NAME:-}}
    GIT_EMAIL=${OPT_GIT_EMAIL:-${GIT_AUTHOR_EMAIL:-}}

    [[ -z $GIT_NAME  ]] && GIT_NAME=$(git config --global user.name  2>/dev/null || true)
    [[ -z $GIT_EMAIL ]] && GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)

    # gh knows both, and by this point gh is usually logged in anyway.
    if [[ -z $GIT_NAME || -z $GIT_EMAIL ]] && command -v gh >/dev/null 2>&1; then
        local n e
        n=$(gh api user --jq .name  2>/dev/null || true)
        e=$(gh api user --jq .email 2>/dev/null || true)
        [[ -z $GIT_NAME  && -n $n && $n != null ]] && GIT_NAME=$n
        [[ -z $GIT_EMAIL && -n $e && $e != null ]] && GIT_EMAIL=$e
    fi

    if [[ $want_prompt == prompt && -t 0 && -t 1 ]]; then
        [[ -z $GIT_NAME  ]] && { printf 'git user.name : '  >&2; read -r GIT_NAME  </dev/tty; }
        [[ -z $GIT_EMAIL ]] && { printf 'git user.email: ' >&2; read -r GIT_EMAIL </dev/tty; }
    fi

    [[ -n $GIT_NAME && -n $GIT_EMAIL ]]
}

# Remember it on this host so every later `new` picks it up without asking again.
persist_git_identity_on_host() {
    [[ -n $GIT_NAME && -n $GIT_EMAIL ]] || return 1
    git config --global user.name  "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    log "Recorded on this host: $GIT_NAME <$GIT_EMAIL>"
}

apply_git_identity() {
    local name=$1
    resolve_git_identity || {
        warn "git user.name/user.email are unknown, so $name has no commit identity.
    Commits there will fail until you set one:
      $SELF init    # records it on this host for all future instances
      lxc exec $name -- bash -lc 'git config --global user.name \"...\"'"
        return 1
    }
    log "Setting git identity in $name: $GIT_NAME <$GIT_EMAIL>"
    lxc exec "$name" -- bash -lc \
        "git config --global user.name '$GIT_NAME'; git config --global user.email '$GIT_EMAIL'"
}

# ---------------------------------------------------------------- ssh ports

# Ports already claimed by an existing instance's sshproxy device.
used_ssh_ports() {
    local i p
    for i in $(lxc list --format csv -c n 2>/dev/null); do
        p=$(lxc config device get "$i" sshproxy listen 2>/dev/null || true)
        [[ -n $p ]] && printf '%s\n' "${p##*:}"
    done
    true
}

port_in_use() {
    local port=$1
    used_ssh_ports | grep -qx "$port" && return 0
    # Also avoid anything already listening on the host, sshproxy or not.
    ss -ltnH 2>/dev/null | awk '{print $4}' | sed 's/.*://' | grep -qx "$port"
}

next_free_ssh_port() {
    local p
    for ((p = SSH_PORT_BASE; p <= SSH_PORT_MAX; p++)); do
        port_in_use "$p" || { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------- github

# Normalize any of these to an https clone URL, so a token/credential-helper login
# works regardless of which form the user pasted:
#   https://github.com/owner/repo(.git) | git@github.com:owner/repo.git | owner/repo
normalize_repo() {
    local r=$1
    case $r in
        git@github.com:*)      r="https://github.com/${r#git@github.com:}" ;;
        ssh://git@github.com/*) r="https://github.com/${r#ssh://git@github.com/}" ;;
        https://github.com/*)  : ;;
        http://github.com/*)   r="https://github.com/${r#http://github.com/}" ;;
        */*)                   [[ $r == *" "* ]] && return 1; r="https://github.com/$r" ;;
        *)                     return 1 ;;
    esac
    r=${r%.git}; r=${r%/}
    # owner/repo must both be present
    [[ $(tr -dc '/' <<<"${r#https://github.com/}" | wc -c) -eq 1 ]] || return 1
    printf '%s.git\n' "$r"
}

repo_dir_name() { local r=${1%.git}; printf '%s\n' "${r##*/}"; }

gh_authed() { lxc exec "$1" -- bash -lc 'gh auth status >/dev/null 2>&1'; }

# Authenticate gh INSIDE the container, then wire git to use it. Private repos need
# this before any clone will succeed.
#
# Three routes, in order:
#   1. GH_TOKEN / GITHUB_TOKEN in the caller's environment -> non-interactive
#   2. an interactive terminal                             -> gh's device-code flow
#   3. neither                                             -> print instructions, give up
# Is this HOST itself logged in to gh? If so its token can be handed to the
# container, which is the usual case: you run `gh auth login` once on the host.
host_gh_token() {
    command -v gh >/dev/null 2>&1 || return 1
    gh auth token 2>/dev/null | grep -E '^gh[a-z]_' || return 1
}

gh_login() {
    local name=$1 token=${GH_TOKEN:-${GITHUB_TOKEN:-}} src="the environment"

    # Fall back to the host's own gh login before asking the user to do anything.
    if [[ -z $token ]] && token=$(host_gh_token); then
        src="this host's gh login"
    fi

    if gh_authed "$name"; then
        log "$name is already authenticated to GitHub"
    elif [[ -n $token ]]; then
        log "Authenticating $name with a token from $src"
        # Token travels on stdin, never in argv (argv is visible in `ps`).
        printf '%s\n' "$token" \
            | lxc exec "$name" -- bash -lc 'gh auth login --with-token' \
            || { warn "token from $src was rejected by GitHub"; return 1; }
    elif [[ -t 0 && -t 1 ]]; then
        log "Authenticating $name to GitHub — follow the prompts (device-code flow)"
        # -t gives the container a pty so gh can render its interactive prompts.
        lxc exec -t "$name" -- bash -lc \
            'gh auth login --hostname github.com --git-protocol https' \
            || { warn "gh auth login did not complete"; return 1; }
    else
        warn "$name is not authenticated to GitHub and there is no terminal to log in with."
        return 1
    fi

    # Make plain `git` (clone, fetch, push) reuse gh's credentials.
    lxc exec "$name" -- bash -lc 'gh auth setup-git' || true
    return 0
}

# Can we authenticate at all in this invocation? Checked BEFORE creating an instance so
# a doomed `new --repo` fails in a second instead of after a 40-second clone.
gh_auth_possible() {
    [[ -n ${GH_TOKEN:-${GITHUB_TOKEN:-}} ]] && return 0
    host_gh_token >/dev/null && return 0     # the host itself is logged in
    [[ -t 0 && -t 1 ]]                       # or we can prompt
}

gh_auth_help() {
    cat >&2 <<EOF
GitHub authentication is required before a repository can be cloned.
Do one of these:

  # 1. log this host in once; every later instance reuses it
  gh auth login

  # 2. non-interactive, with a personal access token
  GH_TOKEN=ghp_xxx $SELF $*

  # 3. interactive: run from a terminal (allocates a TTY for gh's device-code flow)
  ssh -t $(host_ssh) '$SELF $*'

  # 4. authenticate an existing instance, then clone into it
  $SELF auth <name>
EOF
}

cmd_auth() {
    need_lxc
    local name=${1:-}
    [[ -n $name ]] || die "usage: $0 auth <name>"
    [[ $name == project-* || $name == experimental-* ]] || name="project-$name"
    instance_exists "$name" || die "no such instance: $name"
    [[ $(lxc list "$name" -c s --format csv) == RUNNING ]] || lxc start "$name"
    if ! gh_auth_possible; then
        gh_auth_help "auth ${name#project-}"
        die "no way to authenticate to GitHub in this invocation (no GH_TOKEN, no TTY)"
    fi
    gh_login "$name" || die "GitHub authentication failed for $name"
    lxc exec "$name" -- bash -lc 'gh auth status'
}

# Clone into /root (the root of the container user's home).
clone_repo() {
    local name=$1 url=$2 dir; dir=$(repo_dir_name "$url")

    if lxc exec "$name" -- test -e "/root/$dir"; then
        warn "/root/$dir already exists in $name — skipping clone"
        return 0
    fi

    log "Cloning $url into $name:/root/$dir"
    # GIT_TERMINAL_PROMPT=0 matters: without it a private repo without credentials
    # blocks forever on a username prompt instead of failing.
    if lxc exec "$name" -- bash -lc \
        "cd /root && GIT_TERMINAL_PROMPT=0 git clone --recurse-submodules '$url' '$dir'"; then
        log "Cloned to /root/$dir"
        return 0
    fi

    warn "clone of $url into $name failed.
    If the repository is private, check that the authenticated account can read it:
      lxc exec $name -- bash -lc 'gh auth status'
    Then retry:
      lxc exec $name -- bash -lc 'cd /root && git clone $url'"
    return 1
}

# ---------------------------------------------------------------- connect info

# The connection instructions, printed both when an instance is created and by `show`.
# Kept in one place so the two cannot drift apart.
print_connect_info() {
    local name=$1 ip=$2 cpu=$3 mem=$4 ssh_port=$5 repo_dir=$6 headline=${7:-}
    local ak=${8:-}    # authorized_keys the instance accepts, for the IdentityFile hint
    local host_ssh alias
    host_ssh=$(host_ssh)
    alias=${name#project-}; alias=${alias#experimental-}

    cat <<EOF

${GRN}${BLD}$name $headline${RST}   (container IP ${ip:-<not running>}, limits ${cpu:-?} vCPU / ${mem:-?})${repo_dir:+
Repository at /root/$repo_dir}

Connect from your workstation:

  # Option A — no setup needed. Note the quoting: an unquoted ';' would run on the host.
  ssh -t $host_ssh "lxc exec $name -- bash -lc 'hostname; dotnet --version'"

  # interactive shell
  ssh -t $host_ssh lxc exec $name -- bash -l
EOF

    if [[ -n $ssh_port ]]; then
        cat <<EOF

  # Files: scp/rsync work directly
  scp ./local.txt $alias:/root/local.txt

${BLD}Add this to ~/.ssh/config on your workstation:${RST}

Host $alias
  HostName $(host_name)
  Port $ssh_port
  User root
$(ssh_key_hint "$ak")

Then:  ssh $alias
VS Code: F1 -> "Remote-SSH: Connect to Host..." -> $alias${repo_dir:+
         then File > Open Folder > /root/$repo_dir}
EOF
    else
        cat <<EOF

  # No SSH port on this instance, so no scp; move files with LXD instead:
  lxc file push ./local.txt $name/root/local.txt
  lxc file pull $name/root/result.txt ./result.txt

  To add SSH access (for scp / VS Code Remote-SSH), recreate the instance
  without --no-ssh.
EOF
    fi
    echo
}

# ---------------------------------------------------------------- show

cmd_show() {
    need_lxc
    local name=${1:-}
    [[ -n $name ]] || die "usage: $0 show <name>"
    [[ $name == project-* || $name == experimental-* || $name == "$BASE" ]] \
        || name="project-$name"
    instance_exists "$name" || die "no such instance: $name
    Known instances:
$(lxc list --format csv -c n 2>/dev/null | sed 's/^/      /')"

    # Initialize every one: `set -u` makes a declared-but-unassigned local fatal when
    # read, which it is for repo_dir whenever the instance is not running.
    local state="" ip="" cpu="" mem="" ssh_port="" repo_dir=""
    state=$(lxc list "$name" -c s --format csv)
    ip=$(lxc list "$name" -c4 --format csv 2>/dev/null); ip=${ip%% *}
    cpu=$(lxc config get "$name" limits.cpu 2>/dev/null || true)
    mem=$(lxc config get "$name" limits.memory 2>/dev/null || true)
    ssh_port=$(lxc config device get "$name" sshproxy listen 2>/dev/null || true)
    ssh_port=${ssh_port##*:}

    # Report the first git checkout in /root, if the instance is running to be asked.
    if [[ $state == RUNNING ]]; then
        repo_dir=$(lxc exec "$name" -- bash -c \
            'for d in /root/*/.git; do [ -e "$d" ] && basename "$(dirname "$d")" && break; done' \
            2>/dev/null || true)
    fi

    # The keys the instance actually accepts, for the IdentityFile hint.
    local ak=""
    if [[ $state == RUNNING && -n $ssh_port ]]; then
        ak=$(mktemp)
        # shellcheck disable=SC2064
        trap "rm -f '$ak'" RETURN
        lxc exec "$name" -- cat /root/.ssh/authorized_keys >"$ak" 2>/dev/null || true
    fi

    if [[ $state != RUNNING ]]; then
        warn "$name is $state — start it with: lxc start $name"
    fi
    print_connect_info "$name" "$ip" "$cpu" "$mem" "$ssh_port" "$repo_dir" "($state)" "$ak"
}

# ---------------------------------------------------------------- new

cmd_new() {
    need_lxc
    local name="" cpu=$DEF_CPU mem=$DEF_MEM ssh_port="" repo="" no_ssh=0

    while [[ $# -gt 0 ]]; do
        case $1 in
            --cpu)      cpu=$2;      shift 2 ;;
            --memory)   mem=$2;      shift 2 ;;
            --ssh-port) ssh_port=$2; shift 2 ;;
            --no-ssh)   no_ssh=1;    shift ;;
            --repo)     repo=$2;     shift 2 ;;
            --git-name)  OPT_GIT_NAME=$2;  shift 2 ;;
            --git-email) OPT_GIT_EMAIL=$2; shift 2 ;;
            -*)         die "unknown option: $1" ;;
            *)          [[ -z $name ]] || die "unexpected argument: $1"; name=$1; shift ;;
        esac
    done
    [[ -n $name ]] || die \
        "usage: $0 new <name> [--cpu N] [--memory 4GiB] [--ssh-port N|--no-ssh] [--repo URL]"

    # Validate the repo URL before doing 40 seconds of copying.
    if [[ -n $repo ]]; then
        local normalized
        # Keep the original in $repo for the error message; only overwrite on success.
        normalized=$(normalize_repo "$repo") || die "not a GitHub repository: $repo
    Accepted forms:
      https://github.com/owner/repo
      git@github.com:owner/repo.git
      owner/repo"
        repo=$normalized

        # Cloning REQUIRES gh authentication. If this invocation has no way to
        # authenticate, say so now rather than after a 40-second clone.
        if ! gh_auth_possible; then
            gh_auth_help "new $name --repo $repo"
            die "no way to authenticate to GitHub in this invocation (no GH_TOKEN, no TTY)"
        fi
    fi

    # Keep the project- convention unless the caller already used a prefix.
    [[ $name == project-* || $name == experimental-* ]] || name="project-$name"

    instance_exists "$name" && die "$name already exists. Remove it first: $0 remove $name"
    instance_exists "$BASE" || die "$BASE does not exist. Build it first: $0 install"
    snapshot_exists "$BASE" "$SNAPSHOT" \
        || die "$BASE has no '$SNAPSHOT' snapshot. Run: $0 install"

    # Remote SSH access is the default — it is what VS Code Remote-SSH, scp and rsync
    # need. Auto-allocate a free port unless one was named or --no-ssh was given.
    if [[ $no_ssh -eq 1 ]]; then
        ssh_port=""
    elif [[ -z $ssh_port ]]; then
        ssh_port=$(next_free_ssh_port) \
            || die "no free SSH port in ${SSH_PORT_BASE}-${SSH_PORT_MAX}; pass --ssh-port or --no-ssh"
    fi

    if [[ -n $ssh_port ]]; then
        local clash
        clash=$(lxc list --format csv -c n 2>/dev/null | while read -r i; do
                    lxc config device get "$i" sshproxy listen 2>/dev/null \
                        | grep -q ":$ssh_port\$" && echo "$i"
                done || true)
        [[ -z $clash ]] || die "port $ssh_port is already used by: $clash"
    fi

    # Clone the SNAPSHOT, never dev-base itself.
    log "Cloning $BASE/$SNAPSHOT -> $name (full copy on a dir pool; ~40 s, ~6 GB)"
    lxc copy "$BASE/$SNAPSHOT" "$name"

    log "Applying limits: cpu=$cpu memory=$mem"
    lxc config set "$name" limits.cpu "$cpu"
    lxc config set "$name" limits.memory "$mem"

    log "Starting $name"
    lxc start "$name"
    local ip; ip=$(wait_for_ip "$name" || echo "?")

    if [[ -n $ssh_port ]]; then
        log "Enabling direct SSH on port $ssh_port"
        apt_ct "$name" '
            apt-get update -qq
            apt-get install -y -qq openssh-server
            mkdir -p /root/.ssh && chmod 700 /root/.ssh
            systemctl enable --now ssh'

        # Reuse the host operator's own authorized_keys so the clone is reachable
        # with the same key that got you onto the host.
        if [[ -s "$HOME/.ssh/authorized_keys" ]]; then
            lxc file push "$HOME/.ssh/authorized_keys" "$name/root/.ssh/authorized_keys"
            lxc exec "$name" -- chmod 600 /root/.ssh/authorized_keys
        else
            warn "no ~/.ssh/authorized_keys on this host — push your PUBLIC key yourself:
    ssh-keygen -y -f ~/.ssh/<key> > /tmp/mykey.pub    # on your workstation
    lxc file push /tmp/mykey.pub $name/root/.ssh/authorized_keys"
        fi

        lxc config device add "$name" sshproxy proxy \
            "listen=tcp:0.0.0.0:$ssh_port" connect=tcp:127.0.0.1:22
    fi

    # Give the container a commit identity before anything is cloned into it.
    apply_git_identity "$name" || true

    local repo_dir=""
    if [[ -n $repo ]]; then
        repo_dir=$(repo_dir_name "$repo")
        # Authentication is mandatory before cloning, public repo or not: a silent
        # fall-through to an unauthenticated clone just fails later, and confusingly.
        if ! gh_login "$name"; then
            gh_auth_help "auth ${name#project-}"
            die "$name was created but is NOT authenticated to GitHub, so $repo was not cloned.
    The instance is intact — authenticate and clone into it with:
      $0 auth ${name#project-}
      lxc exec $name -- bash -lc 'cd /root && git clone $repo'
    Or discard it:  $0 remove ${name#project-} --force"
        fi
        clone_repo "$name" "$repo" \
            || die "$name was created but $repo could not be cloned (see above)."
    fi

    print_connect_info "$name" "$ip" "$cpu" "$mem" "$ssh_port" "$repo_dir" "is ready" \
        "$HOME/.ssh/authorized_keys"
}

# ---------------------------------------------------------------- remove

cmd_remove() {
    need_lxc
    local name="" force=0
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force) force=1; shift ;;
            -*)         die "unknown option: $1" ;;
            *)          [[ -z $name ]] || die "unexpected argument: $1"; name=$1; shift ;;
        esac
    done
    [[ -n $name ]] || die "usage: $0 remove <name> [--force]"

    # Guard the golden image BEFORE prefixing — otherwise 'remove dev-base' becomes
    # 'project-dev-base' and this check never fires.
    [[ $name == "$BASE" ]] && die "refusing to delete $BASE — it is the golden image
    that every project instance is cloned from, and deleting it destroys the
    '$SNAPSHOT' snapshot too. If you really mean to rebuild it, do it by hand:
    lxc delete -f $BASE"

    [[ $name == project-* || $name == experimental-* ]] || name="project-$name"

    instance_exists "$name" || die "no such instance: $name"

    if [[ $force -eq 0 ]]; then
        printf '%s' "Delete $name and all its data? This cannot be undone. [y/N] "
        read -r reply </dev/tty
        [[ $reply == [yY] ]] || { log "Aborted"; return 0; }
    fi

    log "Deleting $name"
    lxc delete -f "$name"
    log "Deleted $name"
}

# ---------------------------------------------------------------- list / usage

cmd_list() {
    need_lxc
    lxc list
    local n
    for n in $(lxc list --format csv -c n 2>/dev/null); do
        local p; p=$(lxc config device get "$n" sshproxy listen 2>/dev/null || true)
        [[ -n $p ]] && printf '  %-24s direct SSH on %s\n' "$n" "${p##*:}"
    done
    true
}

usage() {
    cat <<EOF
${BLD}devbox-lxd.sh${RST} — manage devbox LXD development environments.
Run on the LXD host. Settings: DEVBOX_HOST, DEVBOX_SSH_KEY (env or $DEVBOX_CONF).

  ${BLD}init${RST}                     Prepare LXD (storage pool + lxdbr0), log this host in to
                           GitHub ('gh auth login'), and record a git identity on
                           the host so every later instance inherits both. Asks for
                           anything it cannot work out; needs a terminal to ask, so
                           run it as: ssh -t $(host_ssh) '$SELF init'
      [--git-name NAME]    supply the identity instead of being asked
      [--git-email ADDR]   (also read from GIT_AUTHOR_NAME/GIT_AUTHOR_EMAIL, from
                           the host's own git config, or from 'gh api user')
                           Safe to re-run.

  ${BLD}install${RST}                  Build '$BASE' and snapshot it as '$SNAPSHOT'.
                           Installs the shared toolchain: build-essential, cmake,
                           git, gh, Python 3.14 + uv, Node LTS, Rust, .NET 10,
                           PowerShell, Claude Code. Idempotent; refuses to run if
                           the '$SNAPSHOT' snapshot already exists.

  ${BLD}new <name>${RST}               Clone a project instance from $BASE/$SNAPSHOT.
                           Remote SSH access is enabled BY DEFAULT (sshd + an LXD proxy
                           device on an auto-allocated port), so VS Code Remote-SSH,
                           scp and rsync work. Prints a ready-to-paste ~/.ssh/config
                           block when it finishes.
      [--cpu N]            vCPU limit           (default $DEF_CPU)
      [--memory SIZE]      memory limit         (default $DEF_MEM)
      [--ssh-port PORT]    pin the SSH port (default: first free from $SSH_PORT_BASE)
      [--no-ssh]           do NOT expose SSH (Option A / 'lxc exec' access only)
      [--git-name NAME]    commit identity for the container; normally inherited
      [--git-email ADDR]   from the host (see 'init') and not needed here
      [--repo URL]         GitHub repo to clone into /root inside the container.
                           Accepts https://github.com/owner/repo, git@github.com:owner/repo.git
                           or owner/repo. REQUIRES GitHub authentication, taken from the
                           first of: GH_TOKEN, this host's own 'gh auth login'   ,
                           or gh's interactive device-code flow. Errors if none apply.
                           'name' is prefixed with 'project-' unless it already
                           starts with 'project-' or 'experimental-'.

  ${BLD}auth <name>${RST}              Log an existing instance in to GitHub ('gh auth login'
                           + 'gh auth setup-git'). Uses GH_TOKEN if set, otherwise
                           the interactive device-code flow.

  ${BLD}remove <name>${RST}            Delete a project instance. Prompts unless --force.
      [-f|--force]         Refuses to delete '$BASE'.

  ${BLD}show <name>${RST}              Print how to connect to an existing instance — the same
                           instructions (including the ~/.ssh/config block) that 'new'
                           prints when it creates one.

  ${BLD}verify [name]${RST}            Check the toolchain in an instance (default $BASE).
  ${BLD}list${RST}                     Show instances and any direct-SSH ports.

Examples:
  ssh -t $(host_ssh) '$SELF init'   # interactive: gh login + identity
  $0 init --git-name 'Your Name' --git-email you@example.com
  $0 install
  $0 new myapp                                            # SSH on by default
  $0 new myapp --cpu 4 --memory 4GiB --ssh-port 2210
  $0 new scratch --no-ssh
  $0 new myapp --repo https://github.com/owner/myapp
  GH_TOKEN=ghp_xxx $0 new other --repo owner/other        # private, non-interactive
  $0 auth myapp
  $0 show myapp
  $0 remove myapp
EOF
}

main() {
    local cmd=${1:-}; shift || true
    case $cmd in
        init)    cmd_init "$@" ;;
        install) cmd_install "$@" ;;
        new)     cmd_new "$@" ;;
        remove)  cmd_remove "$@" ;;
        auth)    cmd_auth "$@" ;;
        show)    cmd_show "$@" ;;
        verify)  cmd_verify "$@" ;;
        list)    cmd_list "$@" ;;
        ""|-h|--help|help) usage ;;
        *)       die "unknown command: $cmd (try: $0 --help)" ;;
    esac
}

main "$@"

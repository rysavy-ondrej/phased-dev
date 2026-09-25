#!/usr/bin/env bash
#
# setup.sh — turn a fresh Ubuntu 24.x / 26.x machine into a devbox host.
#
# Installs and prepares everything devbox-lxd.sh needs, plus the tools you want on
# the host itself:
#
#   - LXD (snap, 5.21 LTS), initialized with a storage pool and the lxdbr0 bridge,
#     and the invoking user added to the 'lxd' group
#   - Node.js LTS (NodeSource) with a per-user npm prefix, so 'npm i -g' needs no sudo
#   - uv (Astral), for Python and Python-based tools
#   - Claude Code (native installer), runnable on the host; the sandboxes get their
#     own copy when devbox-lxd.sh builds the dev-base image
#   - git, gh, curl, jq and friends
#   - devbox-lxd.sh itself, installed to ~/.local/bin
#   - the dev-base golden image (devbox-lxd.sh install), unless --no-base
#
# Run it as your normal user (it uses sudo where it must). Directly from GitHub:
#
#   curl -fsSL https://raw.githubusercontent.com/rysavy-ondrej/phased-dev/main/deploy/ubuntu/setup.sh | bash
#   curl -fsSL .../setup.sh | bash -s -- --no-base          # pass options like this
#
# or download first, which keeps the terminal free for the interactive prompts
# (sudo password, 'gh auth login', git identity):
#
#   curl -fsSLO https://raw.githubusercontent.com/rysavy-ondrej/phased-dev/main/deploy/ubuntu/setup.sh
#   bash setup.sh
#
# Safe to re-run: every step checks before it changes anything.
#
# Everything lives in functions and `main "$@"` is the last line. That matters for
# `curl | bash`: bash reads the script from stdin as it goes, so a command that reads
# stdin mid-script would otherwise swallow the rest of the script.

set -euo pipefail

REPO=${DEVBOX_REPO:-rysavy-ondrej/phased-dev}
REF=${DEVBOX_REF:-main}
LXD_CHANNEL=5.21/stable
NODE_MIN_MAJOR=20

# Options (see usage).
OPT_BASE=1
OPT_STORAGE=btrfs
OPT_STORAGE_SIZE=""          # GiB; empty = computed from free disk space
OPT_FORCE=0
OPT_GIT_NAME=""; OPT_GIT_EMAIL=""

readonly RED=$'\033[31m' GRN=$'\033[32m' YEL=$'\033[33m' BLD=$'\033[1m' RST=$'\033[0m'

log()  { printf '%s==>%s %s\n' "$GRN$BLD" "$RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YEL" "$RST" "$*" >&2; }
die()  { printf '%s[error]%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
${BLD}setup.sh${RST} — prepare an Ubuntu 24.x/26.x machine as a devbox LXD host.

Usage: bash setup.sh [options]
       curl -fsSL <url>/setup.sh | bash -s -- [options]

  --no-base              do not build the dev-base image now (run
                         'devbox-lxd.sh install' later; it takes ~10 minutes)
  --storage DRIVER       LXD storage driver for a NEW pool: btrfs (default,
                         copy-on-write: 'new' is instant), zfs, or dir (full copy
                         per instance). Ignored if LXD is already initialized.
  --storage-size GiB     size of the loop-backed btrfs/zfs pool (default: half of
                         the free space under /var/snap, at least 20)
  --git-name NAME        git identity recorded on the host and inherited by every
  --git-email ADDR       sandbox (otherwise taken from git config / gh, or asked)
  --force                run on an Ubuntu release other than 24.x/26.x
  -h, --help             this text

Environment: DEVBOX_REPO (default $REPO), DEVBOX_REF (default $REF) choose where
devbox-lxd.sh is downloaded from; GH_TOKEN logs gh in without a prompt.
EOF
}

# ---------------------------------------------------------------- helpers

# The user who will own the tools and run devbox-lxd.sh. Under `sudo bash setup.sh`
# that is the caller, not root.
TARGET_USER=""; TARGET_HOME=""

resolve_target_user() {
    if [[ $EUID -eq 0 && -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
        TARGET_USER=$SUDO_USER
    else
        TARGET_USER=$(id -un)
    fi
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    [[ -n $TARGET_HOME ]] || die "cannot find the home directory of $TARGET_USER"
}

# Root-level command. Plain when already root, sudo otherwise.
as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Run a shell snippet as TARGET_USER, with ~/.local/bin on PATH so tools installed a
# moment ago are found without a new login.
as_user() {
    local snippet="export PATH=\"\$HOME/.local/bin:\$PATH\"; $1"
    if [[ $(id -un) == "$TARGET_USER" ]]; then
        bash -c "$snippet"
    else
        sudo -H -u "$TARGET_USER" bash -c "$snippet"
    fi
}

# Run a shell snippet as TARGET_USER *with the lxd group active*. Right after
# `usermod -aG lxd` the current session does not have the group yet; `sg` starts a
# process that does (sudo -u does too, since it re-reads the group database).
as_lxd_user() {
    local snippet="export PATH=\"\$HOME/.local/bin:\$PATH\"; $1"
    if [[ $(id -un) != "$TARGET_USER" ]]; then
        sudo -H -u "$TARGET_USER" bash -c "$snippet"
    elif id -nG | tr ' ' '\n' | grep -qx lxd || [[ $EUID -eq 0 ]]; then
        bash -c "$snippet"
    else
        sg lxd -c "bash -c $(printf '%q' "$snippet")"
    fi
}

# Can we talk to the user? Under `curl | bash` stdin is the script, so interactive
# steps read from /dev/tty instead — when there is one.
have_tty() { { : </dev/tty; } 2>/dev/null; }

apt_install() {
    as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 \
        apt-get install -y -qq "$@" </dev/null
}

# ---------------------------------------------------------------- checks

check_os() {
    [[ -r /etc/os-release ]] || die "cannot read /etc/os-release; is this Ubuntu?"
    # shellcheck disable=SC1091
    local id version
    id=$(. /etc/os-release && echo "${ID:-}")
    version=$(. /etc/os-release && echo "${VERSION_ID:-}")

    if [[ $id != ubuntu ]]; then
        [[ $OPT_FORCE -eq 1 ]] || die "this is '$id', not Ubuntu. Use --force to try anyway."
        warn "not Ubuntu ($id); continuing because of --force"
    elif [[ ${version%%.*} != 24 && ${version%%.*} != 26 ]]; then
        [[ $OPT_FORCE -eq 1 ]] || die "Ubuntu $version is not supported (24.x or 26.x). Use --force to try anyway."
        warn "Ubuntu $version is untested; continuing because of --force"
    fi
    log "Ubuntu $version on $(uname -m), setting up for user '$TARGET_USER'"

    if [[ $EUID -ne 0 ]]; then
        command -v sudo >/dev/null || die "sudo is required when not running as root"
        # Ask for the password once, up front, instead of in the middle of a step.
        if ! sudo -n true 2>/dev/null; then
            have_tty || die "sudo needs a password and there is no terminal to ask on"
            sudo -v </dev/tty || die "sudo authentication failed"
        fi
    fi
}

# ---------------------------------------------------------------- packages

install_base_packages() {
    log "Installing base packages (apt)"
    as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq </dev/null
    apt_install ca-certificates curl wget git gnupg jq unzip build-essential \
                snapd gh openssh-client
}

node_major() {
    local v; v=$(node --version 2>/dev/null || true)
    v=${v#v}; printf '%s\n' "${v%%.*}"
}

install_node() {
    local major; major=$(node_major)
    if [[ -n $major && $major -ge $NODE_MIN_MAJOR ]]; then
        log "Node.js $(node --version) already installed"
    else
        [[ -n $major ]] && warn "Node.js v$major is too old (need >= $NODE_MIN_MAJOR); upgrading"
        log "Installing Node.js LTS (NodeSource)"
        curl -fsSL https://deb.nodesource.com/setup_lts.x -o /tmp/nodesource_setup.sh
        as_root bash /tmp/nodesource_setup.sh </dev/null >/dev/null
        rm -f /tmp/nodesource_setup.sh
        apt_install nodejs
        log "Node.js $(node --version), npm $(npm --version)"
    fi

    # A per-user global prefix: 'npm install -g <tool>' then needs no sudo and lands
    # in ~/.local/bin next to uv and claude. Left alone if the user already chose one.
    local prefix
    prefix=$(as_user 'npm config get prefix' 2>/dev/null || true)
    if [[ $prefix == /usr || $prefix == /usr/local || -z $prefix ]]; then
        as_user 'mkdir -p "$HOME/.local" && npm config set prefix "$HOME/.local"'
        log "npm global prefix set to $TARGET_HOME/.local (no sudo for 'npm install -g')"
    fi
}

install_uv() {
    if as_user 'command -v uv' >/dev/null 2>&1; then
        log "uv already installed: $(as_user 'uv --version')"
        return 0
    fi
    log "Installing uv (Astral)"
    as_user 'curl -LsSf https://astral.sh/uv/install.sh | sh' </dev/null
    log "$(as_user 'uv --version')"
}

install_claude() {
    if as_user 'command -v claude' >/dev/null 2>&1; then
        log "Claude Code already installed: $(as_user 'claude --version' 2>/dev/null || echo '?')"
        return 0
    fi
    log "Installing Claude Code (native installer)"
    as_user 'curl -fsSL https://claude.ai/install.sh | bash' </dev/null
    as_user 'command -v claude' >/dev/null 2>&1 \
        || die "Claude Code did not install; see the output above"
    log "Claude Code $(as_user 'claude --version' 2>/dev/null || echo '?')"
}

# Ubuntu's ~/.profile adds ~/.local/bin to PATH only if it existed at login, and not
# every shell is a login shell. Make it unconditional for the target user.
ensure_local_bin_on_path() {
    local rc="$TARGET_HOME/.bashrc" marker='# devbox: ~/.local/bin on PATH'
    as_user 'mkdir -p "$HOME/.local/bin"'
    if [[ -f $rc ]] && grep -qF "$marker" "$rc"; then return 0; fi
    as_user 'cat >> "$HOME/.bashrc"' <<EOF

$marker
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$HOME/.local/bin:\$PATH" ;; esac
EOF
    log "Added ~/.local/bin to PATH in $rc"
}

# ---------------------------------------------------------------- lxd

# Note: on Ubuntu, /usr/sbin/lxc may be the 'lxd-installer' shim, which exists before
# LXD is installed. `command -v lxc` proves nothing; ask snap.
lxd_snap_installed() { snap list lxd >/dev/null 2>&1; }

install_lxd() {
    as_root systemctl enable --now snapd.socket >/dev/null 2>&1 || true
    as_root snap wait system seed.loaded >/dev/null 2>&1 || true

    if lxd_snap_installed; then
        log "LXD snap already installed: $(snap list lxd | awk 'NR==2 {print $2" ("$4")"}')"
    else
        log "Installing LXD (snap, $LXD_CHANNEL)"
        as_root snap install lxd --channel="$LXD_CHANNEL"
    fi
    as_root lxd waitready --timeout=120 || die "the LXD daemon did not come up"

    if [[ $TARGET_USER != root ]] && ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx lxd; then
        log "Adding $TARGET_USER to the 'lxd' group"
        as_root usermod -aG lxd "$TARGET_USER"
        LXD_GROUP_ADDED=1
    fi
}
LXD_GROUP_ADDED=0

default_pool_size() {
    local free_gib
    free_gib=$(df -BG --output=avail /var/snap 2>/dev/null | tail -1 | tr -dc '0-9')
    [[ -n $free_gib ]] || { echo 30; return; }
    local size=$((free_gib / 2))
    ((size < 20)) && size=20
    echo "$size"
}

init_lxd() {
    if [[ -n $(as_root lxc storage list --format csv 2>/dev/null) ]]; then
        log "LXD already initialized:"
        as_root lxc storage list --format compact
        as_root lxc network list --format compact
        return 0
    fi

    case $OPT_STORAGE in
        btrfs|zfs)
            local size=${OPT_STORAGE_SIZE:-$(default_pool_size)}
            log "Initializing LXD: $OPT_STORAGE pool (${size}GiB loop file) + lxdbr0"
            as_root lxd init --auto --storage-backend="$OPT_STORAGE" \
                --storage-create-loop="$size"
            ;;
        dir)
            log "Initializing LXD: dir pool + lxdbr0"
            as_root lxd init --auto --storage-backend=dir
            ;;
        *) die "unknown storage driver: $OPT_STORAGE (btrfs, zfs or dir)" ;;
    esac
    as_root lxc storage list --format compact
    as_root lxc network list --format compact
}

# Two common reasons containers get an IP but no internet.
check_firewall() {
    if command -v ufw >/dev/null && as_root ufw status 2>/dev/null | grep -q 'Status: active'; then
        log "ufw is active; allowing lxdbr0 traffic (DHCP, DNS, forwarding)"
        as_root ufw allow in on lxdbr0 >/dev/null
        as_root ufw route allow in on lxdbr0 >/dev/null
        as_root ufw route allow out on lxdbr0 >/dev/null
    fi
    if ip link show docker0 >/dev/null 2>&1; then
        warn "Docker is installed. It sets the iptables FORWARD policy to DROP, which
    cuts LXD containers off the network. If sandboxes have no internet, run:
      sudo iptables -I DOCKER-USER -i lxdbr0 -j ACCEPT
      sudo iptables -I DOCKER-USER -o lxdbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    (and persist them, e.g. with iptables-persistent)."
    fi
}

# ---------------------------------------------------------------- devbox-lxd.sh

DEVBOX="" # path of the installed devbox-lxd.sh

install_devbox_script() {
    local dest="$TARGET_HOME/.local/bin/devbox-lxd.sh" src="" here=""
    # When run from a checkout, use the devbox-lxd.sh next to this file. Under
    # `curl | bash` there is no such file and it is downloaded instead.
    if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
        here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
        [[ -f $here/devbox-lxd.sh ]] && src=$here/devbox-lxd.sh
    fi

    local tmp; tmp=$(mktemp)
    if [[ -n $src ]]; then
        log "Installing devbox-lxd.sh from $src"
        cp "$src" "$tmp"
    else
        local url="https://raw.githubusercontent.com/$REPO/$REF/deploy/ubuntu/devbox-lxd.sh"
        log "Downloading devbox-lxd.sh from $url"
        curl -fsSL "$url" -o "$tmp" || { rm -f "$tmp"; die "download failed: $url"; }
    fi
    head -1 "$tmp" | grep -q '^#!.*bash' || { rm -f "$tmp"; die "devbox-lxd.sh does not look like a bash script"; }

    as_user 'mkdir -p "$HOME/.local/bin"'
    as_root install -m 0755 -o "$TARGET_USER" -g "$(id -gn "$TARGET_USER")" "$tmp" "$dest"
    rm -f "$tmp"
    DEVBOX=$dest
    log "devbox-lxd.sh installed at $dest"
}

# gh login + git identity on the host, which every sandbox inherits. Interactive when
# a terminal is available; skipped (with a warning from devbox-lxd.sh) otherwise.
devbox_init() {
    local args=(init)
    [[ -n $OPT_GIT_NAME  ]] && args+=(--git-name "$OPT_GIT_NAME")
    [[ -n $OPT_GIT_EMAIL ]] && args+=(--git-email "$OPT_GIT_EMAIL")
    local cmd; cmd=$(printf '%q ' "$DEVBOX" "${args[@]}")

    log "Running devbox-lxd.sh init (GitHub login and git identity for the sandboxes)"
    if have_tty; then
        as_lxd_user "$cmd" </dev/tty || warn "devbox-lxd.sh init reported a problem; re-run it later"
    else
        as_lxd_user "$cmd" </dev/null || warn "devbox-lxd.sh init reported a problem; re-run it later"
    fi
}

devbox_base() {
    if [[ $OPT_BASE -eq 0 ]]; then
        log "Skipping the dev-base image (--no-base). Build it later with: devbox-lxd.sh install"
        return 0
    fi
    if as_root lxc query /1.0/instances/dev-base/snapshots 2>/dev/null \
            | grep -q '"/1.0/instances/dev-base/snapshots/clean"'; then
        log "dev-base/clean already exists; not rebuilding"
        return 0
    fi
    log "Building the dev-base golden image (devbox-lxd.sh install; ~10 minutes)"
    as_lxd_user "$(printf '%q' "$DEVBOX") install" </dev/null
}

# ---------------------------------------------------------------- summary

summary() {
    local claude_v node_v uv_v
    claude_v=$(as_user 'claude --version' 2>/dev/null || echo missing)
    node_v=$(node --version 2>/dev/null || echo missing)
    uv_v=$(as_user 'uv --version' 2>/dev/null || echo missing)

    cat <<EOF

${GRN}${BLD}devbox host is ready.${RST}

  LXD      $(snap list lxd 2>/dev/null | awk 'NR==2 {print $2" ("$4")"}')
  node     $node_v   (npm i -g installs to ~/.local)
  uv       $uv_v
  claude   $claude_v
  devbox   $DEVBOX

EOF
    if [[ $LXD_GROUP_ADDED -eq 1 ]]; then
        cat <<EOF
${YEL}${BLD}Log out and back in${RST} (or run 'newgrp lxd') so your shell picks up the
'lxd' group; until then 'lxc' and 'devbox-lxd.sh' cannot reach the daemon.

EOF
    fi
    cat <<EOF
Next:
  claude                                        # log in to Claude Code on the host
  devbox-lxd.sh new myproject                   # create a sandbox (SSH on by default)
  devbox-lxd.sh new myproject --repo owner/repo # ...and clone a repository into it
  devbox-lxd.sh list
EOF
    [[ $OPT_BASE -eq 0 ]] && echo "  devbox-lxd.sh install                         # build dev-base first (skipped now)"
    echo
    echo "Inside a sandbox, Claude Code is preinstalled: devbox-lxd.sh show myproject"
}

# ---------------------------------------------------------------- main

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-base)      OPT_BASE=0; shift ;;
            --storage)      OPT_STORAGE=${2:?--storage needs a value}; shift 2 ;;
            --storage-size) OPT_STORAGE_SIZE=${2:?--storage-size needs a value}; shift 2 ;;
            --git-name)     OPT_GIT_NAME=${2:?--git-name needs a value}; shift 2 ;;
            --git-email)    OPT_GIT_EMAIL=${2:?--git-email needs a value}; shift 2 ;;
            --force)        OPT_FORCE=1; shift ;;
            -h|--help)      usage; exit 0 ;;
            *)              die "unknown option: $1 (try --help)" ;;
        esac
    done
    [[ -z $OPT_STORAGE_SIZE || $OPT_STORAGE_SIZE =~ ^[0-9]+$ ]] \
        || die "--storage-size takes a number of GiB, e.g. 60"

    resolve_target_user
    check_os

    install_base_packages
    install_node
    install_uv
    install_claude
    ensure_local_bin_on_path

    install_lxd
    init_lxd
    check_firewall

    install_devbox_script
    devbox_init
    devbox_base

    summary
}

main "$@"

# devbox — a machine for agent-assisted development

A **devbox** is one Linux machine that hosts many isolated development
**sandboxes**, one per project. It can be a workstation, a server under a desk, a
VM or a cloud instance. Each sandbox is an [LXD](https://canonical.com/lxd)
system container: a complete Ubuntu with its own filesystem, network address,
toolchain and repository checkout. The sandboxes share one kernel, so they start
in seconds and cost little more than the processes they run.

This directory holds two scripts:

| Script | Runs | Does |
| --- | --- | --- |
| [`ubuntu/setup.sh`](ubuntu/setup.sh) | once, on a new host | installs LXD, Node.js, uv, Claude Code and gh; installs `devbox-lxd.sh`; builds the sandbox image |
| [`ubuntu/devbox-lxd.sh`](ubuntu/devbox-lxd.sh) | whenever you need a sandbox | creates, shows, authenticates, lists and removes sandboxes |

## Why sandboxes for agent work

A coding agent such as Claude Code works best when it can act on its own: install
packages, run builds and tests, and work through long unattended phases (see
[phased-dev](../README.md)). Doing that on your own laptop means trusting it with
everything on the laptop. A sandbox changes that:

- **Contained blast radius.** The agent sees only the sandbox: one repository,
  one toolchain, root inside the container but not on the host. That lets you
  give it broader permissions than you would on your own machine.
- **One project, one environment.** Each project gets the tools and versions its
  spec asks for, and projects cannot break each other's setup.
- **Parallel and long-running.** Several agents can work on several projects at
  the same time. The work runs on the devbox, so it continues when your laptop
  sleeps or disconnects.
- **Cheap to throw away and to checkpoint.** A new sandbox is a clone of a
  prepared image. A snapshot before a risky phase takes a second, and so does
  going back to it.

```
  your workstation                        devbox host (Ubuntu 24.x / 26.x)
 ┌──────────────────┐   ssh / VS Code    ┌─────────────────────────────────────────┐
 │ terminal         │ ─────────────────▶ │ LXD · claude · gh · node · uv           │
 │ VS Code          │                    │                                         │
 │ Remote-SSH       │  ssh -p 2201 ────▶ │  ┌─ dev-base (golden image, stopped)    │
 └──────────────────┘  ssh -p 2202 ────▶ │  │    └─ snapshot "clean"               │
                                         │  ├─ project-app1   /root/app1   :2201   │
                                         │  └─ project-app2   /root/app2   :2202   │
                                         └─────────────────────────────────────────┘
```

## 1. Set up the host

You need Ubuntu 24.x or 26.x, a user with `sudo`, internet access, and about
20 GB of free disk space: the image is about 6 GB, plus room for the sandboxes.
Run as your normal user, not as root:

```bash
curl -fsSL https://raw.githubusercontent.com/rysavy-ondrej/phased-dev/main/deploy/ubuntu/setup.sh | bash
```

To keep the terminal free for the interactive steps, download it first and then
run it:

```bash
curl -fsSLO https://raw.githubusercontent.com/rysavy-ondrej/phased-dev/main/deploy/ubuntu/setup.sh
```

```bash
bash setup.sh
```

The interactive steps are the sudo password, `gh auth login`, and your git name
and email if they are not already known.

What it does, each step skipped if already done (so it is safe to re-run):

1. **Base packages:** git, gh, curl, jq, build-essential, snapd.
2. **Node.js LTS** (NodeSource). npm's global prefix is set to `~/.local`, so
   `npm install -g <tool>` works without sudo.
3. **uv**, for Python and Python-based tools (`uv tool install <tool>`).
4. **Claude Code**, installed to `~/.local/bin`, so you can run `claude` on the
   host.
5. **LXD** (snap, 5.21 LTS), with a storage pool and the `lxdbr0` network. Adds
   you to the `lxd` group. If ufw is active, it opens ufw for `lxdbr0`.
6. **`devbox-lxd.sh`**, installed to `~/.local/bin`. Then runs
   `devbox-lxd.sh init`: logs this host in to GitHub and records your git
   identity, which every sandbox inherits.
7. **The `dev-base` image** (`devbox-lxd.sh install`, about 10 minutes). It
   contains build-essential, cmake, git, gh, Python + uv, Node.js LTS, Rust,
   .NET 10, PowerShell and Claude Code, and is saved as the snapshot `clean`.

| Option | Effect |
| --- | --- |
| `--no-base` | skip step 7; run `devbox-lxd.sh install` later |
| `--storage btrfs\|zfs\|dir` | driver for a **new** LXD pool. The default, `btrfs`, is copy-on-write, so a new sandbox is instant. `dir` copies the full ~6 GB for each sandbox |
| `--storage-size N` | size of the btrfs/zfs pool in GiB (default: half of the free disk space, at least 20) |
| `--git-name NAME --git-email ADDR` | the git identity, instead of being asked |
| `--force` | run on an Ubuntu release other than 24.x/26.x |

Pass options through the pipe with `bash -s --`, for example
`curl -fsSL …/setup.sh | bash -s -- --no-base`. When it finishes, log out and
back in (or run `newgrp lxd`) so your shell picks up the `lxd` group.

## 2. Create and use sandboxes

All commands run on the devbox host. Names get a `project-` prefix unless they
already start with `project-` or `experimental-`.

```bash
devbox-lxd.sh new myapp --repo owner/myapp       # sandbox + clone into /root/myapp
devbox-lxd.sh new scratch --no-ssh               # no SSH port; reach it with lxc exec
devbox-lxd.sh new big --cpu 8 --memory 16GiB     # limits (default 4 vCPU / 4GiB)
devbox-lxd.sh show myapp                         # how to connect, again
devbox-lxd.sh list                               # sandboxes and their SSH ports
devbox-lxd.sh auth myapp                         # log a sandbox in to GitHub
devbox-lxd.sh verify myapp                       # check its toolchain
devbox-lxd.sh remove myapp                       # delete it (asks first)
```

`new` and `show` print exactly how to connect from your workstation:

- **Through the host, no setup needed:**
  `ssh -t you@devbox lxc exec project-myapp -- bash -l`
- **Directly, by SSH.** Every sandbox gets its own port (2201, 2202, …). `new`
  prints a block to paste into `~/.ssh/config` on your workstation. After that,
  `ssh myapp`, `scp` and `rsync` work, and so does VS Code:
  *Remote-SSH: Connect to Host… → myapp*, then open `/root/myapp`.

The sandbox accepts the same SSH keys as the host: the host's
`~/.ssh/authorized_keys` is copied into it.

### Settings

The connection hints are worked out from the running system:

- **The host address:** the address you are connected to by SSH, or else the
  host's main IP address.
- **The key in the `IdentityFile` hint:** the key you logged in with, shown with
  its fingerprint.

To set them yourself, set these in the environment or in
`~/.config/devbox-lxd.conf`:

```bash
DEVBOX_HOST=devbox               # an ssh alias, host name or user@host
DEVBOX_SSH_KEY=~/.ssh/work_key   # private key path on your workstation
```

## 3. Agent-assisted projects in a sandbox

A typical project with [phased-dev](../README.md) — see [HOWTO.md](../HOWTO.md)
for the method itself:

```bash
# on the host
devbox-lxd.sh new myapp --repo owner/myapp
ssh myapp                                   # or VS Code Remote-SSH
```

```bash
# inside the sandbox
tmux new -s agent                           # keeps the session alive when you disconnect
cd /root/myapp
claude                                      # first time: log in (once per sandbox)
```

Then, inside Claude Code, install the plugin once per sandbox:

```
/plugin marketplace add JuliusBrussee/caveman
/plugin marketplace add rysavy-ondrej/phased-dev
/plugin install phased-dev@phased-dev
```

Then run `/phased-dev:start`. Later, run `/phased-dev:dev-env` to install the
project's own toolchain into the sandbox, where it cannot disturb other
projects.

Habits that pay off:

- **Detach, don't quit.** Press `Ctrl-b d` to leave tmux with the agent still
  working. `tmux attach -t agent` gets you back, from any machine.
- **Snapshot before a risky phase**, on the host:
  `lxc snapshot project-myapp before-phase3`. If the phase goes wrong, run
  `lxc restore project-myapp before-phase3`. Git records the code, but the
  snapshot also covers installed tools, databases and data files.
- **Keep the golden image golden.** Don't work in `dev-base`. To refresh the
  toolchain, update it and take a *new* snapshot (for example `clean-2026-10`);
  don't change `clean`.
- **One repository per sandbox.** The agent's context and its permissions both
  stay scoped to that project.

## Security notes

- **GitHub credentials.** A sandbox logs in to GitHub with the host's token (or
  `GH_TOKEN`), so the agent in it can do anything that token allows. For
  anything sensitive, give each sandbox its own fine-grained token, limited to
  its repository: `GH_TOKEN=github_pat_… devbox-lxd.sh new myapp --repo owner/myapp`.
- **Claude Code login** is per sandbox and stays inside it. `remove` deletes the
  login along with the sandbox.
- **SSH ports** (2201–2299) listen on all of the host's interfaces and allow
  `root` login with key authentication only. On a host with a public address,
  restrict these ports to your own network with a firewall.
- **Containers, not VMs.** An LXD container is a strong boundary for keeping
  mistakes contained. It does not isolate as strongly as a virtual machine.
  Don't run code you would not trust on the host kernel.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `cannot reach the LXD daemon` | log out and back in, or run `newgrp lxd`, after `setup.sh` |
| a sandbox has an IP address but no internet, and Docker is installed | Docker's firewall rules block LXD traffic; `setup.sh` prints the `iptables` rules that fix it |
| `devbox-lxd.sh new` is slow and uses a lot of disk space | the pool is `dir`. Create a btrfs pool and make it the default: `lxc storage create fast btrfs size=60GiB`, then `lxc profile device set default root pool=fast`, then `lxc move dev-base --storage fast` |
| `--repo` fails for a private repository | run `devbox-lxd.sh auth <name>`, or use `GH_TOKEN=… devbox-lxd.sh new …` |
| `ssh myapp` asks for a password or is refused | check the `IdentityFile` in `~/.ssh/config` against the fingerprint `show` prints, or set `DEVBOX_SSH_KEY` |
| a tool is missing in a sandbox | `devbox-lxd.sh verify <name>`; inside the sandbox, `/phased-dev:dev-env` |

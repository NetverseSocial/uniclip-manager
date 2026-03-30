# uniclip-manager

A wrapper around [uniclip](https://github.com/quackduck/uniclip) that automates setting up shared clipboard sync between your Mac and remote machines over SSH.

Supports **macOS VMs** (Parallels), **Linux desktop VMs**, **Windows VMs**, and **Docker containers**.

## What it does

1. Starts a `uniclip` server on the local Mac (if not already running)
2. Detects the remote environment (macOS VM, Linux desktop, Windows VM, Docker container)
3. Resolves the correct host address reachable from the remote
4. Launches `uniclip` client on the remote using the appropriate method
5. Verifies the connection is active

After running, clipboard content is synced bidirectionally between your Mac and the remote machine.

## Prerequisites

**Local (Mac):**
- `uniclip` installed (`brew install quackduck/tap/uniclip`)
- SSH access to the remote machine

**Remote (macOS VM):**
- `uniclip` installed (`brew install quackduck/tap/uniclip`)
- `tmux` installed (`brew install tmux`)

**Remote (Linux desktop VM):**
- `uniclip` installed (via [Homebrew on Linux](https://brew.sh/) or [binary release](https://github.com/quackduck/uniclip/releases))
- `systemd` user session (standard on Ubuntu/Fedora/etc.)
- Must be logged into the GUI desktop as the same user the script SSHes in as

**Remote (Windows VM):**
- `uniclip` installed (build from source with `go install` for native ARM64, or download from [releases](https://github.com/quackduck/uniclip/releases))
- OpenSSH Server enabled
- Must be logged into the desktop as the same user the script SSHes in as

**Remote (Docker container):**
- `uniclip` binary, `tmux`, `xclip`, and `xvfb` packages installed
- See the included `Dockerfile` for a working example

## Usage

```bash
# Parallels macOS VM
uniclipx agent@macos-sandbox

# Linux desktop VM
uniclipx agent@ubuntu-sandbox

# Windows VM
uniclipx agent@windows-sandbox

# Docker container (custom SSH port)
uniclipx -p 2222 root@localhost
```

### Stopping the remote client

```bash
uniclip-kill-remote agent@ubuntu-sandbox
```

## How it works

### Network detection

| Remote type | Host address | How detected |
|---|---|---|
| Parallels VM | `bridge100` interface IP (e.g. `10.211.55.2`) | Default for VMs |
| Docker container | `host.docker.internal` | `/.dockerenv` file exists |
| Other | LAN IP via `en0`/`en1` | Fallback |

### Clipboard access by platform

| Platform | Method | Why |
|---|---|---|
| macOS VM | `tmux` session | tmux preserves macOS pasteboard access; `nohup &` and `screen -dm` do not |
| Linux desktop VM | `systemd-run --user` | Inherits the GUI session's clipboard context (Wayland/X11); SSH+tmux cannot access desktop clipboard |
| Windows VM | `schtasks` (scheduled task) | Runs uniclip in the interactive desktop session; SSH session clipboard is isolated from the desktop |
| Linux headless (Docker) | `Xvfb` + `xclip` in `tmux` | No desktop to integrate with; virtual X display provides clipboard for xclip |

### Important notes

- **Linux desktop VMs**: You must be logged into the GUI desktop as the same user the script SSHes in as. If no desktop session is detected, the script falls back to Xvfb (headless mode).
- **macOS hostname**: The script uses `scutil --get LocalHostName` (not `hostname -s`) to get the correct Bonjour name, then resolves to the Parallels bridge IP for reliability.
- **SSH PATH**: Non-interactive SSH shells on macOS don't include `/opt/homebrew/bin`. The script uses `bash -l` and searches common install paths as fallback.

## Docker test container

Build and run the included Dockerfile for testing with a headless Linux container:

```bash
docker build -t uniclip-test .
docker run -d --name uniclip-ubuntu -p 2222:22 uniclip-test

# Copy SSH key into container
docker exec uniclip-ubuntu mkdir -p /root/.ssh
cat ~/.ssh/id_ed25519.pub | docker exec -i uniclip-ubuntu tee /root/.ssh/authorized_keys

# Connect
uniclipx -p 2222 root@localhost
```

## Files

| File | Description |
|---|---|
| `uniclipx` | Main script — sets up clipboard sync to a remote machine |
| `uniclip-kill-remote` | Kills uniclip on a remote machine |
| `Dockerfile` | Ubuntu 24.04 container with SSH, uniclip, tmux, xclip, xvfb |

## Credits

This project is a management wrapper around [uniclip](https://github.com/quackduck/uniclip) by [Ishan Goel (quackduck)](https://github.com/quackduck). All clipboard sync functionality is provided by uniclip — this tool automates its deployment and configuration across remote machines.

## Troubleshooting

**"uniclip not found" on remote** — Non-interactive SSH shells don't load your full PATH. The script searches common locations (`/opt/homebrew/bin`, `/usr/local/bin`, `/home/linuxbrew/.linuxbrew/bin`), but if uniclip is installed elsewhere, it won't be found. Fix: ensure uniclip is in one of those paths or add it to your shell profile.

**Clipboard not syncing on Linux desktop** — You must be logged into the GUI desktop as the same user the script SSHes in as. If you SSH as `agent` but the desktop is logged in as `john`, clipboard access will fail silently.

**Clipboard not syncing on Windows** — Same as Linux: you must be logged into the Windows desktop as the SSH user. The script uses Windows scheduled tasks to run uniclip in the desktop session context.

**"An error occurred wile getting the local clipboard" appears in clipboard** — This is uniclip's error message being synced as clipboard content. It means the remote uniclip can't access the clipboard (wrong display, wrong session, or missing tools). Kill uniclip on both sides and re-run.

**Windows Parallels Tools** — Do not remove Parallels Tools on Windows VMs. Unlike Linux/macOS, the virtual NIC driver is part of the tools — removing them breaks networking. Instead, disable auto-update from the host:

```bash
prlctl set "VM Name" --tools-autoupdate off
```

**uniclip port changes on restart** — uniclip picks a random port each time. The `-p` flag does not work as of v2.3.6. The script auto-detects the port, so just re-run `uniclipx` after restarting the local server.

**No ARM64 Windows binary available** — The uniclip releases don't include a Windows ARM64 build. On ARM64 Windows VMs, build from source with Go for a native binary:

```bash
go install github.com/quackduck/uniclip@latest
# Or clone and build:
git clone https://github.com/quackduck/uniclip.git
cd uniclip && go build -o uniclip.exe .
```

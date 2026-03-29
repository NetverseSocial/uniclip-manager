# uniclipx

A wrapper around [uniclip](https://github.com/quackduck/uniclip) that automates setting up shared clipboard sync between your Mac and remote machines over SSH.

Supports **macOS VMs** (Parallels), **Linux desktop VMs**, and **Docker containers**.

## What it does

1. Starts a `uniclip` server on the local Mac (if not already running)
2. Detects the remote environment (macOS VM, Linux desktop, Docker container)
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

**Remote (Docker container):**
- `uniclip` binary, `tmux`, `xclip`, and `xvfb` packages installed
- See the included `Dockerfile` for a working example

## Usage

```bash
# Parallels macOS VM
uniclipx agent@macos-sandbox

# Linux desktop VM
uniclipx agent@ubuntu-sandbox

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

## Gotchas

- **macOS pasteboard**: `nohup &` and `screen -dm` detach uniclip from the login session, breaking `pbcopy`/`pbpaste`. Use `tmux` instead.
- **Wayland clipboard**: SSH sessions can't access the desktop clipboard even with `DISPLAY`/`WAYLAND_DISPLAY` set — the compositor blocks unauthorized access. `systemd-run --user` is the workaround.
- **Headless Linux**: Containers and headless VMs need `xvfb` to provide a virtual X display for `xclip`.
- **uniclip port**: uniclip picks a random port each time — the `-p` flag does not work as of v2.3.6. The script auto-detects the port.

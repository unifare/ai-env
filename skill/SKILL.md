---
name: ai-env
description: Use when managing AI API keys with ai-env.
version: 1.0.0
license: MIT
---

## When to Use

Trigger this skill when a task involves setting, reading, listing, or removing AI API keys
(OpenAI, Anthropic, Gemini, etc.) on this machine, installing/reinstalling ai-env, or
patching the installer in `/root/ai-env-fix` into the `/root/ai-env` repo.

# ai-env (AI API Key Manager)

CLI to manage AI API keys across Linux/macOS/Windows. Stores keys in a secure
config file, applies them to the current shell immediately, and auto-loads in new terminals.

## Where the code lives
- Canonical repo (this machine): `/root/ai-env` (git, origin `github.com/unifare/ai-env`)
- Latest/fixed installer lives at `/root/ai-env-fix/install.sh` — NEWER than the committed one.
  It adds `curl` prerequisite + `_FETCH_SOURCE_FILE()` so the bare
  `curl -fsSL .../install.sh | bash` one-click path auto-downloads `ai-env`, `init.sh`, `config`.
  When a fix lands in `ai-env-fix`, COPY it into the repo and commit+push.

## Install (Linux/macOS)
```bash
cd /root/ai-env
./install.sh            # or: ./manage.sh install
```
Installs binary to `~/.local/bin/ai-env` (or `/usr/local/bin` if writable),
config to `~/.config/ai-env/`, and sources `init.sh` into your shell rc.

## Core commands
```bash
ai-env set <KEY> <VALUE>     # set an API key (applies immediately in current shell)
ai-env get <KEY>             # print a key value (masked)
ai-env list                  # list all keys (masked); alias ls
ai-env remove <KEY>          # delete a key; aliases rm/delete/unset
ai-env reload                # reload all keys
ai-env export > backup.env   # dump all keys for backup
ai-env doctor               # diagnostics: dir, PATH, shell integration, keys file
ai-env version              # show version; aliases -v/--version
ai-env help                 # help; aliases -h/--help
```

## Management script (menu + args)
```bash
./manage.sh              # interactive numbered menu
./manage.sh install      # ./manage.sh uninstall | set | get | list | remove | doctor
```

## Storage
- Keys file: `~/.config/ai-env/keys` (chmod 600)
- Uninstall auto-backs up keys to `~/.ai-env-keys.backup`
- Version: v1.0.0

## Pitfalls
- Do NOT pipe a real key value through chat/logs — `list`/`get` already mask values.
- `ai-env set` affects the current shell only; new terminals load via `init.sh`.
- Keys file is plaintext; keep perms 600 and avoid committing it.

# Claude Code Hooks & Rules

## 注意
LLMにこのREADMEを作らせたので、全然間違っていることを言っている可能性があります。

## 概要

A collection of opinionated hooks and best‑practice rules for **Claude Code**.
The initial release ships with **`stop_hook.py`**, a plug‑and‑play Stop‑Event hook that:

* Echoes Claude’s last assistant message back to it
* Appends **「これであってる？」** to prompt clarification
* Fires a macOS notification with the echoed text
* Unblocks the Stop event once, using `stop_hook_active` to avoid infinite loops

---

## Table of Contents

1. [Demo](#demo)
2. [Requirements](#requirements)
3. [Quick Start](#quick-start)
4. [Configuration](#configuration)
5. [How It Works](#how-it-works)
6. [Customising the Hook](#customising-the-hook)
7. [Project Roadmap](#project-roadmap)
8. [Contributing](#contributing)
9. [License](#license)

---

## Demo

```bash
$ claude --debug
> …Claude answers…
# Notification ✨ pops up (macOS)
> assistant: <previous answer>

これであってる？
```

---

## Requirements

| Component   | Version                                                                           |
| ----------- | --------------------------------------------------------------------------------- |
| Python      | 3.8 +                                                                             |
| Claude Code | v0.33 +                                                                           |
| OS          | macOS (for notifications)<br/>Linux/Windows run fine—notification call is skipped |

---

## Quick Start

```bash
git clone https://github.com/1ulce/.claude.git
cd .claude/hooks
chmod +x stop_hook.py
```

1. Open **Claude Code → Settings → Hooks**
2. Add the snippet below to `settings.json` (or use the UI):

```jsonc
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",          // run on every Stop
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/hooks/stop_hook.py"
          }
        ]
      }
    ]
  }
}
```

3. Start a session – the hook fires automatically whenever Claude reaches a Stop Event.

---

## Configuration

| Flag / Section           | Purpose                           |
| ------------------------ | --------------------------------- |
| `stop_hook_active` check | Prevents infinite trigger loops   |
| `osascript` call         | Sends a notification (macOS only) |
| `assistant_last` parsing | Extracts latest assistant reply   |

Feel free to **fork & tweak** for your workflow.

---

## How It Works

1. Claude signals a `Stop` decision.
2. The hook reads the conversation transcript (JSONL).
3. The latest assistant chunk is extracted & echoed.
4. A macOS notification is displayed via AppleScript.
5. The hook prints

   ```json
   {"decision":"block","reason":"<echoed>\n\nこれであってる？"}
   ```

   which Claude treats as the next user turn.
6. On the subsequent Stop, `stop_hook_active` is already `true`; the script exits silently, letting the conversation end normally.

---

## Customising the Hook

* **Disable notifications** – set `NOTIFY=false` env var or comment out the `send_notification` call.
* **Change the suffix** – edit `SUFFIX = "\n\nこれであってる？"`.
* **Different platforms** – swap the `osascript` block for `notify-send` (Linux) or `PowerShell` (Windows).

---

## Project Roadmap

* 🔧 Pre‑prompt rules & context validators
* 🪝 Additional hook templates (MessageRewriter, Guardrails, Metrics)
* 🧩 Schema‑driven plugin loader
* ✅ GitHub Actions CI (flake8, mypy, unit tests)

Contributions welcome—see below!

---

## Contributing

1. Fork the repo & create your branch: `git checkout -b feature/my-awesome-hook`
2. Commit with **conventional commits** style.
3. Run `pre-commit run --all-files` (config coming soon).
4. Open a PR; describe **what & why** clearly.
5. Be nice ❤️ – we review fast!

---

## License

Released under the **MIT License** – see [`LICENSE`](LICENSE) for details.

---

### Acknowledgements

* ChatGPT & Claude community for inspiration
* Original discussion: \[link to chat or issue]

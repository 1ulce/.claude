#!/usr/bin/env python3
import json, pathlib, os, sys, subprocess, shlex, platform

def send_notification(msg: str, title: str = "Claude Code") -> None:
    """macOS の通知センターにメッセージを飛ばす"""
    if platform.system() != "Darwin":
        return                      # mac じゃなければ何もしない
    # AppleScript コマンドを組み立て
    script = f'display notification "{msg}" with title "{title}"'
    subprocess.run(["osascript", "-e", script], check=False)

# ──★ 0. 受信 JSON
data = json.load(sys.stdin)

# ──★ 1. 無限ループ防止
if data.get("stop_hook_active"):
    sys.exit(0)

# ──★ 2. transcript から最新 assistant 発話を取得
t_path = pathlib.Path(os.path.expanduser(data["transcript_path"]))
assistant_last = ""
with t_path.open() as f:
    for raw in reversed(list(f)):
        raw = raw.strip()
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if entry.get("type") != "assistant":
            continue
        content = entry.get("message", {}).get("content", "")
        if isinstance(content, str):
            assistant_last = content
        elif isinstance(content, list):
            assistant_last = "".join(
                part.get("text", "") for part in content if part.get("type") == "text"
            )
        break

# ──★ 3. 次ターン入力を生成
next_input = f"{assistant_last}\n\nこれであってる？"

# ──★ 4. 通知を飛ばす！（要 macOS）
send_notification(assistant_last)

# ──★ 5. Stop をブロックして質問返し
print(json.dumps({
    "decision": "block",
    "reason": next_input
}))

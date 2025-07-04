#!/bin/bash
  # stop_hook.sh

  # JSONデータを読み取り
  INPUT=$(cat)
  TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

  # 最新のassistantメッセージを取得
  LATEST_MESSAGE=$(tac "$TRANSCRIPT_PATH" | jq -r 'select(.type == "assistant") | .message.content[0].text' )

  # 通知を送信
  if [ -n "$LATEST_MESSAGE" ]; then
      # ダブルクォートをエスケープ
      ESCAPED_MESSAGE=$(echo "$LATEST_MESSAGE" | sed 's/"/\\"/g')
      osascript -e "display notification \"$ESCAPED_MESSAGE\" with title \"Claude Code\""
  else
      osascript -e "display notification \"No message?\" with title \"Claude Code\""
  fi

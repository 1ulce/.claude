# 概要
ClaudeCodeを使うためにsubmoduleにDocumentをまとめため、hookでsubmoduleを意識しないで扱えるようにした。
docsと.claudeがそれぞれsubmoduleになっているはずです。

# 使い方
(0, `git config --unset core.hooksPath`)
1, `git config core.hooksPath .claude/hooks`
2, `chmod +x .claude/hooks/project/*`
3, `chmod +x .claude/hooks/personal/*`

# 注意点
他のhookを設定している人は、personalフォルダにpre-commit.shとして入れてください

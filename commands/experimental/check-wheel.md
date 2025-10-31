# /check-wheel — 追加コードの「既存の車輪」再利用チェック（PR/ブランチ対応）

> 新規追加コードの“意図”に合致する既存実装が **このリポジトリ内** に無いか自動探索します。
> PR があれば **インラインコメント**、PR が無いブランチは **既存PR自動検出** or **ドラフトPR作成（任意）**、なければ **サマリー報告** でフォールバック。
> コアロジック: `.claude/docs/check-wheel-core.md`

---

## 使い方

```
/check-wheel <target> [--base <baseBranch>] [--create-draft-pr] [--summary-only]
```

- `<target>` は以下のどちらか  
  - **PR URL**: `https://github.com/owner/repo/pull/123`
  - **ブランチ名**（省略可）: 省略時はカレントブランチ（`git rev-parse --abbrev-ref HEAD`）
- `--base`: 既定は `origin/main`（`git merge-base` で共通祖先を取ります）
- `--create-draft-pr`: ブランチに対応PRが無ければ **ドラフトPRを自動生成** してインライン化
- `--summary-only`: 常にサマリーレポートに出力（PR/コメントを一切作らない）

---

## 判定フロー（擬似コード）

ultrathink
1. **入力解釈**
   - `if target matches /github\.com\/.+\/pull\/\d+/` → `mode = "PR"`
   - `else` → `mode = "BRANCH"`, `head = target || current-branch`

2. **差分取得**
   - `mode == PR`:
     - `mcp__github__get_pull_request_diff`（無ければ `gh pr diff --patch --unified=0 <PR>`）
   - `mode == BRANCH`:
     - `base = --base || origin/main`
     - `mb = $(git merge-base base head)`
     - `git diff --patch --unified=0 $mb..$head`（追加行のみ抽出）

3. **PR 特定（ブランチモード）**
   - `gh pr list --head <head> --state all --json number` で既存PR有無チェック
   - あれば `mode = "PR"` に昇格し、その PR にコメント
   - なければ:
     - `--create-draft-pr` が **ある** → `gh pr create --draft --base <base> --head <head> ...` → そのPRで続行
     - **無い** → **サマリーレポート**にフォールバック（`.claude/debug/check-wheel-report-<head>.md` へ）

4. **チャンク化 & 既存探索**
   - 追加ハンクを言語別にチャンク化 → **意図シグネチャ** 抽出  
   - `.claude/docs/check-wheel-core.md` の軽量/構造フェーズで候補抽出

5. **出力**
   - **PRモード**:  
     1) `mcp__github__create_pending_pull_request_review`  
     2) チャンクごとに `mcp__github__add_comment_to_pending_review`（`path`, `line`, `side`, `body`）  
     3) `mcp__github__submit_pending_pull_request_review`（`event: "COMMENT"`）
   - **サマリーモード**:  
     - `.claude/debug/check-wheel-report-<head or pr#>.md` を生成/更新  
     - 必要なら `gh issue create --title "check-wheel report"` でリンクを残す

---

## 実行ステップ（指示）

1. **ターゲットの正規化**（PR URL or ブランチ）
2. **差分を取得し、`+` 行のあるハンクだけ** を集める
3. **チャンク化**（Ruby/Next/React ルールに従う）
4. **意図シグネチャ抽出**（命名・入出力・呼び出し先・語彙・テスト）
5. **探索（軽量→構造）**  
   - `git grep` / `rg`  
   - ディレクトリ規約 & テスト逆引き & インターフェース一致
6. **コメント生成**  
   - テンプレに沿って 1〜3件の候補＋最小パッチ案
7. **出力**  
   - PR なら MCP で **インラインコメント**  
   - それ以外は **サマリーMD**（差分ファイル別に見出しを作る）

---

## インラインコメントのテンプレ

```
[check-wheel] 似た意図の既存実装があります

候補:
1) {path}:{line_or_symbol} — {why_similar}
   - 共通化案: {how_to_factor}（影響: {files_impacted}）
   - 最小パッチ:
     - 既存に {small_extension}
     - このPR側は {replacement_step}

補足:
- 同一の {data_source/api/table} を扱っており、入出力が {match_degree} 一致
- {test_path} に類似テストあり: 「{describe/it}」
```

---

## フォールバックと注意点
- **PRが無いブランチ**でインラインを求める場合は、`--create-draft-pr` を付けると最短。
- 生成物/ロック/ベンダー/画像/スナップショット/マイグレーションは解析対象外。
- コメント数上限（例: 1ファイルあたり 10）は超過時にサマリに集約。

---

## 小ネタ（発見性UPのチーム整備）
- この部分はTODOなので現状は無視してください
- ルート `CODEMAP.md`（再利用ポイントの索引）
- `docs/synonyms.md`（同義語辞書）
- テスト見出しに業務語彙（逆引きの精度が跳ね上がる）

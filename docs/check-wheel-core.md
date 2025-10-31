# check-wheel: Core Heuristics & Playbook

本書は、追加コードの「意図」を抽出し、リポジトリ内の**同意図の既存実装**を発見するためのプレイブックです。  
コマンド実装は `commands/check-wheel.md` を参照。ここでは判断基準と探索手順だけに集中します。

## 1. “意図シグネチャ（Intent Signature）”
各追加チャンクから以下を抽出し、検索クエリに変換する。

- 命名: 関数/クラス/コンポーネント名、ファイルパス、ディレクトリ（例: `services/`, `hooks/`, `policies/`, `lib/`, `components/`）
- 入出力: 引数名/型（TS）、戻り値、例外、Props 形状
- 呼び出し先: DBアクセス（ActiveRecord）、HTTP/GraphQL クライアント、外部SDK
- 語彙: ログ文、コメント、JSDoc/YARD、i18nキー、エラーメッセージ
- テスト: `describe/context/it` の見出し（業務語彙を含む行）

## 2. チャンク化ルール（Ruby / Next / React）
- Ruby: `def...end`, `class`, `module`, service / policy / serializer / concern  
  *migrationは原則スキップ*
- JS/TS/React/Next:
  - `function` / `export function` / `const X = () =>` / `class X`
  - React: `ComponentName`, `useXxx`（カスタムフック）, `forwardRef`, `"use server"`
  - Next: `app/` 配下の `page.tsx` / `layout.tsx` / `route.ts` / `loading.tsx` / `error.tsx` / Server Action

## 3. リポジトリ内探索の二段構え
### 軽量フェーズ（高速）
- `git grep` / ripgrep で **命名＋同義語** をクエリにして検索  
  例: `useDebounce|debounce|throttle`, `authorize|permitted`, `sanitize|escape|strip`
- ディレクトリ規約で当たりを付ける  
  Rails: `app/services`, `app/policies`, `lib/`  
  Frontend: `src/hooks`, `src/components`, `src/services`, `src/repositories`

### 構造フェーズ（精度）
- 同一データソース（同じテーブル/エンドポイント/GraphQLフィールド）を触る実装を特定
- **テスト→本体 逆引き**（似た `describe/it` から本体へ）
- **インターフェース一致**（引数セット・戻り値・Props が高類似）

## 4. コメント作法（インライン向け）
- 既存候補 1〜3件を提示
- **共通化案（最小パッチ）** と **影響範囲** を簡潔に
- 似て非なる要件なら「共通抽象の切り出し」を推奨

テンプレ:
```
[check-wheel] 似た意図の既存実装があります

候補:
1) {path}:{symbol} — {why_similar}
   - 共通化案: {how_to_factor}
   - 最小パッチ: {small_extension} -> 本PR側 {replacement_step}

補足: {data_source/api/table}, 入出力 {match_degree} 一致 / {test_path} に類似テストあり
```

## 5. 除外・優先順位
- 除外: 生成物/ロックファイル/ベンダーコード/画像/スナップショット、Rails migration
- 優先: サービス層・フック・ユーティリティ・ポリシー・バリデーション・整形ロジック

## 6. チーム整備（発見性を上げる）
- この部分はTODOなので無視してください
- 命名規約の徹底、用途別ディレクトリ、1行ドキュコメント
- ルート `CODEMAP.md`（再利用ポイント索引）
- `docs/synonyms.md`（同義語辞書: debounce/throttle, sanitize/escape/strip など）

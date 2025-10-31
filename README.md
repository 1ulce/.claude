# Claude Code Configuration

開発プロジェクトのClaude Code拡張設定と開発支援ツールキットです。Kiro-style Spec-Driven Developmentを実装し、効率的な開発ワークフローを提供します。

## 📁 ディレクトリ構成

```
.claude/
├── commands/               # Claude Codeスラッシュコマンド
│   ├── kiro/              # Kiro SDD関連コマンド
│   ├── careful-bugfix.md  # 慎重なバグ修正プロセス
│   ├── pr-review.md       # プルリクレビュー支援
│   └── task-plan.md       # タスク計画テンプレート
├── hooks/                  # Git hooks設定
│   ├── personal/          # 個人用フック
│   ├── project/           # プロジェクト共通フック
│   └── pre-commit         # コミット前処理
├── docs/                   # 開発文書テンプレート
└── settings.local.json    # Claude Code権限設定

../docs/.kiro/              # Kiro仕様書駆動開発システム (プロジェクトルート/docs/.kiro/)
├── steering/               # プロジェクトステアリング文書
│   ├── product.md         # プロダクト概要
│   ├── structure.md       # プロジェクト構造
│   └── tech.md            # 技術スタック
└── specs/                  # 機能仕様書（自動生成）
```

## 🎯 主要機能

### 1. Kiro Spec-Driven Development (SDD)
仕様書駆動開発による体系的な開発プロセス

**利用可能なコマンド：**
- `/kiro:steering-init` - プロジェクトステアリング文書初期化
- `/kiro:spec-init [feature]` - 新機能仕様書作成
- `/kiro:spec-requirements [feature]` - 要件定義生成
- `/kiro:spec-design [feature]` - 技術設計書作成
- `/kiro:spec-tasks [feature]` - 実装タスク分解
- `/kiro:spec-status [feature]` - 進捗確認

**3フェーズ承認ワークフロー：**
1. 要件定義 → 人間承認 → `spec.json`で承認記録
2. 技術設計 → 人間承認 → `spec.json`で承認記録
3. 実装タスク → 人間承認 → `spec.json`で承認記録

### 2. 開発支援コマンド
- **慎重バグ修正**: `/careful-bugfix` - 段階的バグ修正プロセス
- **PRレビュー**: `/pr-review` - プルリクエスト品質チェック
- **タスク計画**: `/task-plan` - 構造化タスク分解

### 3. Git Hooks自動化
- **Pre-commit**: コミット前品質チェック
- **Submodule管理**: 自動同期とアップデート
- **個人・プロジェクト設定分離**

## 🚀 セットアップ

### Git Hooks有効化
```bash
# 既存のhooks設定リセット（必要に応じて）
git config --unset core.hooksPath

# .claude/hooksを有効化
git config core.hooksPath .claude/hooks

# 実行権限付与
chmod +x .claude/hooks/project/*
chmod +x .claude/hooks/personal/*
```

### Claude Code設定確認
設定は`settings.local.json`で管理されています。必要な権限が適切に設定されていることを確認してください。

## 🔧 使い方

### 新機能開発の標準ワークフロー

1. **ステアリング確認** （推奨）
   ```
   /kiro:steering-init
   ```

2. **仕様書駆動開発**
   ```
   /kiro:spec-init user-profile-enhancement
   /kiro:spec-requirements user-profile-enhancement
   # → 人間承認後
   /kiro:spec-design user-profile-enhancement  
   # → 人間承認後
   /kiro:spec-tasks user-profile-enhancement
   # → 人間承認後、実装開始
   ```

3. **進捗確認**
   ```
   /kiro:spec-status user-profile-enhancement
   ```

### バグ修正ワークフロー
```
/careful-bugfix
# → 段階的調査・修正・検証プロセス
```

## 📋 開発ルール

### 必須プロセス
1. **3フェーズ承認**: 要件→設計→タスク→実装の順守
2. **手動承認**: 各フェーズで人間レビュー必須
3. **仕様準拠**: `/kiro:spec-status`での整合性確認
4. **ステアリング更新**: 重要変更後の文書更新

### 推奨プロセス
- 主要機能開発前のステアリング文書確認
- コミット前のPRレビューチェック
- タスク完了時の進捗更新

## 🔄 自動化機能

このツールキットは以下を自動化します：
- tasks.mdのタスク進捗追跡
- 仕様準拠チェック
- ステアリングドリフト検出
- コンテキスト保持とコンパクション

## 📚 参考資料

- **プロジェクト仕様**: `../CLAUDE.md`
- **ステアリング文書**: `../docs/.kiro/steering/`
- **アクティブ仕様**: `../docs/.kiro/specs/`
- **コマンド詳細**: `commands/`ディレクトリ

---

*Development Toolkit powered by Claude Code + Kiro SDD*

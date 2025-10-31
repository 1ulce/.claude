# Kiro Task Add Command

既存のKiro仕様に新しい要件やタスクを追加するコマンド

## Arguments Analysis

`$ARGUMENTS` 引数の形式:
- `feature-name "新しい要件やタスクの説明"`
- 例: `item-rich-text-editor "画像リサイズ機能の追加"`

## Command Flow

### 1. Spec Location & Status Check

対象仕様の存在確認と状態チェック:
- `docs/.kiro/specs/$FEATURE_NAME/` フォルダの存在確認
- `spec.json` ファイルの現在の状態を確認
- 既存の requirements.md, design.md, tasks.md ファイルの存在確認

### 2. Requirements Analysis & Update

新しい要件を既存の requirements.md に追加する処理:

#### 分析項目:
- 新要件が既存要件と重複していないか
- 既存の機能要件との整合性チェック  
- システム要件との関連性確認
- 優先度と影響範囲の評価

#### 更新処理:
1. `docs/.kiro/specs/$FEATURE_NAME/requirements.md` を読み込み
2. `.claude/commands/kiro/spec-requirements.md` のテンプレートを使用
3. 新要件を適切な位置に挿入:
   - 新要件番号の割り当て
   - 機能分類ごとの配置
   - User Story形式の記述
   - Acceptance Criteriaの追加
4. 既存内容との整合性確認
5. `spec.json` の `updated_at` を更新

### 3. Design Analysis & Update

設計への影響を分析し design.md を更新する処理:

#### 分析項目:
- アーキテクチャへの影響確認
- 新要件による設計変更の必要性
- データモデルへの影響
- API設計への影響確認
- セキュリティ設計への影響評価

#### 更新処理:
1. `docs/.kiro/specs/$FEATURE_NAME/design.md` を読み込み
2. `.claude/commands/kiro/spec-design.md` のテンプレートを使用
3. 設計更新:
   - アーキテクチャ図の更新
   - データモデルの修正
   - データフローの更新
   - セキュリティ要件の追加
4. 整合性確認と検証
5. `spec.json` で design approved を false にリセット

### 4. Tasks Analysis & Update

実装タスクを分析し tasks.md を更新する処理:

#### 分析項目:
- 新要件の実装に必要なタスク
- 既存タスクとの依存関係確認
- 開発工数の見積もり
- テスト・品質保証タスクの追加

#### 更新処理:
1. `docs/.kiro/specs/$FEATURE_NAME/tasks.md` を読み込み
2. `.claude/commands/kiro/spec-tasks.md` のテンプレートを使用
3. タスク追加:
   - 新要件の実装タスクに分解
   - 既存タスクとの順序付け
   - 既存のフェーズ構造
   - テスト項目の追加
4. 全体タスク数とTotal tasksの更新
5. `spec.json` で tasks approved を false にリセット

### 5. Metadata Update

`spec.json` メタデータを更新:
```json
{
  "updated_at": "current_timestamp",
  "phase": "updated_phase",
  "approvals": {
    "requirements": {
      "approved": updated_if_changed
    },
    "design": {
      "approved": false_if_updated  
    },
    "tasks": {
      "approved": false_if_updated
    }
  },
  "ready_for_implementation": false_if_any_changes
}
```

### 6. Change Summary

更新内容の概要レポート:
- 追加された要件の数
- 追加された設計変更点
- 追加されたタスクの総数

## Return to Development Workflow

`docs/.kiro/specs/$FEATURE_NAME/tasks.md` に対して、
最終的に `.claude/commands/kiro/dev-workflow.md` に処理を戻す:

### If Requirements Updated:
- Phase: `requirements-updated` 
- Next: Requirements review and approval needed

### If Design Updated:
- Phase: `design-updated`
- Next: Design review and approval needed

### If Tasks Updated:
- Phase: `tasks-updated`
- Next: Tasks review and approval needed

### If Multiple Updates:
- Phase: `multiple-updates`
- Next: Sequential review starting from requirements

## Error Handling

### Spec Not Found:
```
Error: Feature '$FEATURE_NAME' not found.
Available features: [list existing features]
Use `/kiro:spec-init` to create a new feature specification.
```

### Invalid Arguments:
```
Error: Invalid arguments format.
Usage: /kiro:task-add feature-name "description of new requirement/task"
Example: /kiro:task-add item-rich-text-editor "Add image resize functionality"
```

### Conflicting Changes:
- Check for uncommitted changes in spec files
- Warn if manual edits might be overwritten
- Provide backup recommendations

## Implementation Notes

### Context Analysis Required:
- Read all existing spec documents to understand current state
- Analyze dependencies between requirements/design/tasks
- Ensure consistency across all documents

### Language Consistency:
- Use same language as existing spec documents (check spec.json)
- Maintain consistent terminology and naming conventions
- Follow established documentation patterns

### Version Control:
- Consider creating backup of original files
- Log all changes made for rollback capability
- Update timestamps accurately

## Example Usage

```bash
# Add new requirement to existing feature
/kiro:task-add item-rich-text-editor "画像のリサイズと圧縮機能をアップロード画像に追加"

# Add new task to existing specification  
/kiro:task-add user-authentication "OAuth2のGoogleとGitHub連携を実装"

# Add security requirement
/kiro:task-add payment-processing "PCI DSS準拠の検証と監査ログ追加"
```

## Expected Output

```
新要件を分析中: "画像のリサイズと圧縮機能を追加"
対象機能: item-rich-text-editor

仕様を更新しています...
✓ Requirements更新完了: 要件7 - 画像処理機能を追加
✓ Design更新完了: 画像処理モジュールのアーキテクチャを追加
✓ Tasks更新完了: フェーズ5に3つの新しいタスクを追加

変更概要:
- Requirements: 1つの新要件を追加
- Design: 画像処理アーキテクチャを追加
- Tasks: 3つの新タスクを追加 (5.4, 5.5, 5.6)

次のステップ:
1. 更新されたrequirements.mdを確認
2. 設計変更を承認 (design approval reset)  
3. タスク変更を承認 (tasks approval reset)
4. 全承認後に実装準備完了

開発ワークフローに戻ります: /kiro:dev-workflow
```
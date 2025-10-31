# Kiro Bug Fix Command

spec-implの途中で発見したバグを即座に修正し、実装フローに戻るためのコマンド

## Arguments Analysis

`$ARGUMENTS` 引数の形式:
- `feature-name "バグの詳細説明"`
- 例: `item-tags "タグ削除時に関連アイテムが正しく更新されない"`

## Command Flow

### 1. Current Spec Status Check

対象仕様の現在の状態確認:
- `docs/.kiro/specs/$FEATURE_NAME/` フォルダの存在確認
- `spec.json` ファイルの現在の実装状態確認
- 現在がimplementation phaseかどうかの確認
- 進行中のタスクの特定

### 2. Bug Analysis & Categorization

バグの詳細分析と分類:

#### バグ分類:
- **Critical**: サービス停止・データ破損の恐れ
- **High**: 主要機能の障害
- **Medium**: 一部機能の問題
- **Low**: UI/UX改善レベル

#### 影響範囲分析:
- 既存機能への影響確認
- データ整合性への影響
- ユーザー体験への影響
- セキュリティリスクの評価

### 3. Bug Fix Task Creation

緊急修正タスクをtasks.mdに追加:

#### タスク挿入処理:
1. `docs/.kiro/specs/$FEATURE_NAME/tasks.md` を読み込み
2. 現在の進行中タスクの直後に緊急タスクを挿入
3. 緊急タスクの形式:
   ```markdown
   ## 🚨 緊急修正 - Phase [現在のフェーズ].[次番号]

   **バグ修正**: [バグの説明]

   **Priority**: URGENT - [Critical/High/Medium/Low]
   **Status**: in-progress
   **Type**: bug-fix

   ### 修正内容:
   - [ ] バグの原因調査と特定
   - [ ] 修正コードの実装
   - [ ] 修正のテスト実行
   - [ ] リグレッションテスト
   - [ ] 修正完了確認

   ### 影響範囲:
   - [影響を受ける機能リスト]

   ### 検証項目:
   - [ ] 修正対象の動作確認
   - [ ] 関連機能の動作確認
   - [ ] エッジケースの確認
   ```

#### メタデータ更新:
- Total tasksカウントを更新
- 緊急タスクフラグを追加
- 中断されたタスクの記録

### 4. Bug Fix Implementation

緊急修正の実行:

#### 実装ステップ:
1. **原因調査**:
   - エラーログの確認
   - コードレビューによる問題箇所特定
   - 再現条件の確認

2. **修正実装**:
   - 最小限の変更での修正
   - 既存機能への影響最小化
   - コーディング規約の遵守

3. **即座検証**:
   - 修正箇所の動作確認
   - 関連機能のリグレッションテスト
   - エッジケースの確認

4. **ドキュメント更新**:
   - バグと修正内容の記録
   - 今後の予防策の記載

### 5. Spec Metadata Update

`spec.json` にバグ修正履歴を記録:
```json
{
  "updated_at": "current_timestamp",
  "phase": "implementation",
  "bug_fixes": [
    {
      "timestamp": "current_timestamp",
      "description": "バグの説明",
      "priority": "Critical/High/Medium/Low",
      "status": "fixed",
      "tasks_added": ["緊急修正タスクのID"]
    }
  ],
  "implementation_interrupted": {
    "interrupted_at": "timestamp",
    "reason": "bug_fix",
    "resumed_at": null
  }
}
```

### 6. Return to Implementation Flow

バグ修正完了後、元の実装フローに復帰:

#### 復帰処理:
1. 緊急タスクのステータスを"completed"に更新
2. 中断されたタスクの再開
3. `spec.json` の `implementation_interrupted.resumed_at` を更新
4. 実装継続のガイダンス表示

#### 継続ガイダンス:
```
バグ修正完了！実装フローを再開します。

次のステップ:
- 中断されたタスク: [タスク名]
- 進捗: [完了数]/[総数] タスク
- 推定残り時間: [時間]

実装を継続しますか？ /kiro:spec-impl [feature-name]
```

## Error Handling

### Spec Not Found:
```
Error: Feature '$FEATURE_NAME' not found.
Available features: [list existing features]
Use `/kiro:spec-init` to create a new feature specification.
```

### Not in Implementation Phase:
```
Error: Feature '$FEATURE_NAME' is not in implementation phase.
Current phase: [current_phase]
Bug fixes can only be applied during implementation.
```

### Invalid Arguments:
```
Error: Invalid arguments format.
Usage: /kiro:bug-fix feature-name "detailed bug description"
Example: /kiro:bug-fix item-tags "タグ削除時にアイテムが正しく更新されない"
```

### No Active Tasks:
```
Error: No active implementation tasks found for '$FEATURE_NAME'.
Start implementation first: /kiro:spec-impl $FEATURE_NAME
```

## Implementation Notes

### Emergency Priority:
- 緊急修正は他のタスクより優先
- 最小限の変更で最大の効果を目指す
- 副作用の発生を最小化

### Context Preservation:
- 中断されたタスクの状態を保持
- 実装の流れを記録
- 再開時のスムーズな復帰

### Documentation:
- バグ修正の履歴を残す
- 類似バグの予防策を記録
- チーム共有のための情報整理

## Example Usage

```bash
# クリティカルなバグの修正
/kiro:bug-fix item-tags "タグ削除時にitem_item_tagsが残ってしまい整合性エラーが発生"

# UIバグの修正
/kiro:bug-fix user-profile "プロフィール画像アップロード後にプレビューが表示されない"

# データ整合性の問題修正
/kiro:bug-fix order-payment "決済完了後に注文ステータスが更新されないケースがある"
```

## Expected Output

```
🚨 緊急バグ修正を開始します
対象機能: item-tags
バグ内容: "タグ削除時にitem_item_tagsが残ってしまい整合性エラーが発生"

バグ分析中...
✓ 分類: High Priority - データ整合性問題
✓ 影響範囲: タグ削除機能、アイテム表示機能
✓ 緊急修正タスクを追加: Phase 3.4

修正を実装中...
✓ 原因特定: Tag削除時のdependent: :destroy設定漏れ
✓ 修正実装: ItemTagモデルにdependent: :destroy追加
✓ テスト実行: 削除機能とアイテム表示機能を確認
✓ リグレッションテスト: 関連機能すべて正常

🎉 バグ修正完了！

修正概要:
- 修正箇所: app/models/item/tag.rb:7
- 変更内容: has_many :item_tags, dependent: :destroy追加
- テスト結果: すべて正常動作確認

実装フローに戻ります...
次のタスク: Phase 3.2 - フロントエンド絞り込みUI実装
進捗: 8/15 タスク完了

実装を継続しますか？ /kiro:spec-impl item-tags
```
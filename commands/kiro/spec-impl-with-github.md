---
description: Execute spec tasks using TDD methodology
allowed-tools: Bash, Read, Write, Edit, MultiEdit, Grep, Glob, LS, WebFetch, WebSearch
argument-hint: <feature-name> <task-number> [--commit]
---

# Execute Spec Tasks with TDD

Execute implementation task **$2** for feature **$1** using Kent Beck's Test-Driven Development methodology.

## Instructions

### Pre-Execution Validation

**Required Arguments**:
1. Feature name: `$1` (required)
2. Task number: `$2` (required, e.g., 1.1, 1.2, 2.1)
3. Commit flag: `$3` (optional, `--commit`)

**Validation Steps**:
1. ✅ Check task number is provided (stop if missing with error message)
2. ✅ Check branch name is `dev/NUM` format (stop if not)
3. ✅ Fetch GitHub sub-issues and map task numbers to issue numbers
4. ✅ Validate required spec files exist for feature `$1`

---

#### Step 1: Task Number Validation

```bash
if [ -z "$2" ]; then
  echo "❌ Error: Task number is required (e.g., 1.1, 1.2, 2.1)"
  echo "Usage: /kiro:spec-impl-with-github <feature-name> <task-number> [--commit]"
  exit 1
fi
```

---

#### Step 2: Branch Name Validation

**Branch Format Requirement**: `dev/NUM` (e.g., `dev/151`, `dev/177`)

```bash
CURRENT_BRANCH=$(git branch --show-current)
if [[ ! "$CURRENT_BRANCH" =~ ^dev/[0-9]+$ ]]; then
  echo "❌ Error: Current branch must be in format 'dev/NUM' (e.g., dev/151)"
  echo "Current branch: $CURRENT_BRANCH"
  exit 1
fi

PARENT_ISSUE_NUM=$(echo "$CURRENT_BRANCH" | grep -oE '[0-9]+$')
echo "✅ Branch validated: $CURRENT_BRANCH (Parent issue: #$PARENT_ISSUE_NUM)"
```

---

#### Step 3: GitHub Sub-Issue Mapping

**Fetch sub-issues from GitHub and map task number to issue number**:

```bash
OWNER="tent-inc"
REPO="kaeuru"
TASK_NUM="$2"

echo "Fetching sub-issues from GitHub..."
sub_issues=$(gh api graphql -f query='query { repository(owner: "'"$OWNER"'", name: "'"$REPO"'") { issue(number: '"$PARENT_ISSUE_NUM"') { subIssues(first: 100) { nodes { id number title } } } } }')

# Extract issue number for specified task
SUB_ISSUE_NUM=$(echo "$sub_issues" | jq -r \
  --arg task "$TASK_NUM" \
  '.data.repository.issue.subIssues.nodes[] | select(.title | startswith($task + " ")) | .number')

if [ -z "$SUB_ISSUE_NUM" ]; then
  echo "❌ Error: Task $TASK_NUM not found in GitHub sub-issues for parent #$PARENT_ISSUE_NUM"
  echo "Available tasks:"
  echo "$sub_issues" | jq -r '.data.repository.issue.subIssues.nodes[] | "  - \(.title | split(" ")[0])"' | sort -V
  exit 1
fi

echo "✅ Task mapping: $TASK_NUM → Sub-issue #$SUB_ISSUE_NUM"
```

**Variables Set**:
- `PARENT_ISSUE_NUM`: Parent issue number (from branch name)
- `TASK_NUM`: Task number (from $2)
- `SUB_ISSUE_NUM`: Sub-issue number (from GitHub API)

---

#### Step 4: Spec Files Validation

Validate required files exist for feature **$1**:
- Requirements: `docs/.kiro/specs/$1/requirements.md`
- Design: `docs/.kiro/specs/$1/design.md`
- Tasks: `docs/.kiro/specs/$1/tasks.md`
- Metadata: `docs/.kiro/specs/$1/spec.json`

```bash
SPEC_DIR="docs/.kiro/specs/$1"
if [ ! -f "$SPEC_DIR/requirements.md" ] || \
   [ ! -f "$SPEC_DIR/design.md" ] || \
   [ ! -f "$SPEC_DIR/tasks.md" ] || \
   [ ! -f "$SPEC_DIR/spec.json" ]; then
  echo "❌ Error: Required spec files not found for feature $1"
  echo "Missing files in: $SPEC_DIR"
  exit 1
fi

echo "✅ Spec files validated"
```

---

### Context Loading

**Core Steering:**
- Structure: @docs/.kiro/steering/structure.md
- Tech Stack: @docs/.kiro/steering/tech.md
- Product: @docs/.kiro/steering/product.md

**Custom Steering:**
- Additional `*.md` files in `docs/.kiro/steering/` (excluding structure.md, tech.md, product.md)

**Spec Documents for $1:**
- Metadata: @docs/.kiro/specs/$1/spec.json
- Requirements: @docs/.kiro/specs/$1/requirements.md
- Design: @docs/.kiro/specs/$1/design.md
- Tasks: @docs/.kiro/specs/$1/tasks.md

---

### Task Execution

**Execution Parameters**:
1. **Feature**: `$1`
2. **Task number**: `$2` (REQUIRED, single task only)
3. **Parent issue**: `#$PARENT_ISSUE_NUM` (from branch name)
4. **Sub-issue**: `#$SUB_ISSUE_NUM` (from GitHub API)
5. **Commit mode**: Check if `$3` contains `--commit` flag

**Process**:
1. Load all context (steering + spec documents)
2. Extract task details from `tasks.md` for task `$2`
3. Execute the specified task using TDD methodology
4. **STOP after completing this single task** (do NOT proceed to next tasks)

---

### TDD Implementation

For the specified task **$2**:

#### 1. RED: Write Failing Tests First
- Identify test requirements from task details
- Write comprehensive tests that fail initially
- Cover all acceptance criteria

#### 2. GREEN: Write Minimal Code to Pass Tests
- Implement only what's needed to pass tests
- Follow design specifications from `design.md`
- Reference requirements from `requirements.md`

#### 3. REFACTOR: Clean Up and Improve Code Structure
- Improve code readability
- Remove duplication
- Apply design patterns from `structure.md`
- Ensure consistency with tech stack (`tech.md`)

#### 4. VERIFY: Comprehensive Validation
- ✅ All tests pass
- ✅ No regressions in existing tests
- ✅ Code quality standards maintained
- ✅ Test coverage meets requirements

#### 5. COMMIT (only if `--commit` flag provided)

**Commit Message Format**:
```
#<sub-issue-num> <type>: <summary-ja>
```

**Commit Type Guidelines**:
- `feat`: 新機能追加
- `fix`: バグ修正
- `chore`: 雑務（設定変更、依存関係更新など）
- `docs`: ドキュメント更新
- `test`: テスト追加・修正
- `refactor`: リファクタリング

**Examples**:
```bash
# Task 1.1: マイグレーション実行
#258 feat: マイグレーション実行

# Task 1.2: モデル拡張
#259 feat: モデル拡張実装

# Task 1.3: バリデーション実装
#260 feat: バリデーション実装

# Task 2.1: GraphQL型拡張
#261 feat: GraphQL型拡張

# Task 3.1: モデルテスト
#262 test: モデルテスト実装

# Task 4.1: 管理画面フォーム
#264 feat: 管理画面フォーム追加
```

**Commit Execution**:
```bash
if [[ "$3" == *"--commit"* ]]; then
  git add .

  # Generate commit message (example for feat type)
  COMMIT_TYPE="feat"  # Determine from task context
  COMMIT_SUMMARY="タスク内容の要約"  # Extract from task description

  git commit -m "#$SUB_ISSUE_NUM $COMMIT_TYPE: $COMMIT_SUMMARY"

  echo "✅ Committed: #$SUB_ISSUE_NUM $COMMIT_TYPE: $COMMIT_SUMMARY"
fi
```

#### 6. MARK COMPLETE: Update tasks.md

**Update checkbox from `- [ ]` to `- [x]`**:
```bash
# Update tasks.md to mark task as completed
sed -i '' "s/^- \[ \] $TASK_NUM /- [x] $TASK_NUM /" "docs/.kiro/specs/$1/tasks.md"
echo "✅ Task $TASK_NUM marked as complete in tasks.md"
```

---

## Implementation Notes

### Commit Message Priority

**⚠️ IMPORTANT**: This command's commit message format **overrides** `CLAUDE.md` specifications:

**This Command (PRIORITY)**:
```
#<sub-issue-num> <type>: <summary-ja>
例: #258 feat: マイグレーション実行
```

**CLAUDE.md (IGNORED for this command)**:
```
#<parent-issue-num> <type>: <summary>
例: #151 feat: 機能追加の説明
```

### Execution Flow

```
1. Validate arguments
   ├─ Task number required?
   ├─ Branch name valid? (dev/NUM)
   └─ Sub-issue exists?

2. Load context
   ├─ Steering documents
   └─ Spec documents

3. Execute TDD cycle (single task)
   ├─ RED: Write tests
   ├─ GREEN: Implement
   ├─ REFACTOR: Clean up
   └─ VERIFY: All tests pass

4. Commit (if --commit flag)
   └─ Format: #<sub-issue> <type>: <summary-ja>

5. Mark complete in tasks.md
   └─ Update checkbox: [ ] → [x]

6. STOP (do NOT proceed to next tasks)
```

### Single Task Execution

**This command executes ONLY the specified task and stops**:
- ✅ Execute task `$2`
- ✅ Commit if `--commit` flag provided
- ✅ Mark task as complete in `tasks.md`
- ❌ Do NOT automatically proceed to next task
- ❌ Do NOT execute multiple tasks in sequence

**To execute multiple tasks**: Run the command multiple times with different task numbers:
```bash
/kiro:spec-impl-with-github 2025-10-10-vendor-store-introduction 1.1 --commit
/kiro:spec-impl-with-github 2025-10-10-vendor-store-introduction 1.2 --commit
/kiro:spec-impl-with-github 2025-10-10-vendor-store-introduction 1.3 --commit
```

### Error Handling

**Common Errors**:
1. Missing task number → Stop with usage message
2. Invalid branch name → Stop with format message
3. Task not found in GitHub → Stop with available tasks list
4. Spec files missing → Stop with missing files list
5. Tests fail → Stop before commit
6. Validation errors → Stop and report issues

### TDD Methodology

**Follow Kent Beck's TDD strictly**:
- Always write tests before implementation
- Write the simplest code to pass tests
- Refactor only after tests pass
- Keep test cycles short and focused
- One assertion per test when possible
- Test behavior, not implementation

### Task Tracking

**tasks.md checkbox states**:
- `- [ ]`: Task not started
- `- [x]`: Task completed

**Update after successful execution** (regardless of commit mode):
```markdown
# Before
- [ ] 1.1 ストア紹介データを保存するためのマイグレーション実行

# After
- [x] 1.1 ストア紹介データを保存するためのマイグレーション実行
```

---

## Usage Examples

### Example 1: Execute task without commit

```bash
/kiro:spec-impl-with-github 2025-10-10-vendor-store-introduction 1.1
```

**Result**:
- ✅ Task 1.1 executed
- ✅ tests.md updated
- ❌ No commit

### Example 2: Execute task with commit

```bash
/kiro:spec-impl-with-github 2025-10-10-vendor-store-introduction 1.1 --commit
```

**Result**:
- ✅ Task 1.1 executed
- ✅ tasks.md updated
- ✅ Committed as `#258 feat: マイグレーション実行`

### Example 3: Execute multiple tasks sequentially

```bash
# Task 1.1
/kiro:spec-impl-with-github 2025-10-10-vendor-store-introduction 1.1 --commit

# Task 1.2
/kiro:spec-impl-with-github 2025-10-10-vendor-store-introduction 1.2 --commit

# Task 1.3
/kiro:spec-impl-with-github 2025-10-10-vendor-store-introduction 1.3 --commit
```

**Result**:
- ✅ Each task executed separately
- ✅ Each task committed separately
- ✅ All tasks marked in tasks.md

---

## Design Philosophy

**Token Efficiency**: Use `gh api graphql` for GitHub API calls (98% token reduction vs MCP tools)

**Single Task Focus**: Execute one task at a time for better control and atomic commits

**TDD Strict Adherence**: Follow Kent Beck's methodology for high-quality, well-tested code

**GitHub Integration**: Automatic sub-issue mapping ensures commit messages reference correct issue numbers

---

**think deeply**

---
description: Create GitHub sub-issues from Kiro tasks.md (gh command only, GraphQL optimized)
allowed-tools: Read, Bash, TodoWrite
argument-hint: <feature-name>
---

# GitHub Sub-Issue Creation from Kiro Tasks

Generate GitHub sub-issues for feature **$1** from `tasks.md`.

## Execution Summary (Read This First!)

**4-Step Process**:

| Step | Phase | Command | API Used |
|------|-------|---------|----------|
| 1 | Prerequisites | `git branch`, `git remote`, Read spec/tasks | - |
| 2 | Discovery | `gh api graphql` | `query { subIssues { ... } }` |
| 3 | Creation | `gh issue create` + `gh api graphql` | `mutation { addSubIssue(...) }` |
| 4 | **Reordering** | **`gh api graphql`** | **`mutation { reprioritizeSubIssue(...) }`** |

**Return Types**:
- `addSubIssue` → `{ subIssue { id number title } }`
- **`reprioritizeSubIssue`** → **`{ issue { number } }`** (returns parent issue!)

---

## Task: Create and Synchronize GitHub Sub-Issues

### 🚨 MANDATORY CONSTRAINTS 🚨

**ALLOWED TOOLS ONLY** (frontmatter: `allowed-tools: Read, Bash, TodoWrite`):
- ✅ **Read**: For reading spec.json, tasks.md
- ✅ **Bash**: For executing `gh api graphql` commands
- ✅ **TodoWrite**: For progress tracking

**ABSOLUTELY PROHIBITED**:
- ❌ **ALL MCP tools** (`mcp__github__*` functions)
- ❌ **NO exceptions** - use ONLY gh commands via Bash

**Why This Matters**:
- MCP tools: ~47,000 tokens per execution
- gh commands: ~1,000 tokens (**98% token reduction**)
- Direct GraphQL API control without abstraction overhead

**If You Attempt to Use MCP Tools**: STOP immediately and use gh commands instead.

---

### Design Philosophy

**Token Efficiency First**: This command uses **pure gh commands** instead of MCP tools to achieve 98% token reduction (~1,000 tokens vs ~47,000 tokens).

**Implementation Strategy**:
- Use GraphQL API directly via `gh api graphql`
- Parse responses with `jq` for data extraction
- Never guess API names - refer to schema definitions below

### 1. Prerequisites & Context Gathering

**Prerequisites Check**:
- Verify `docs/.kiro/specs/$1/spec.json` exists
- Verify `docs/.kiro/specs/$1/tasks.md` exists
- If missing: Stop with error message directing user to `/kiro:spec-init` or `/kiro:spec-tasks`

**Context Extraction**:
```bash
# Extract parent issue number from git branch
git branch --show-current  # e.g., dev/177 → #177

# Extract owner/repo from git remote
git remote get-url origin  # e.g., git@github.com:tent-inc/kaeuru.git → tent-inc/kaeuru
```

**Metadata Loading**:
- Read `spec.json` for feature metadata and approval status
- Read `tasks.md` for complete task list (completed and incomplete)

### 2. Task Analysis & Extraction

**Task Structure Understanding**:

```markdown
- [ ] 1. Major Task (section heading, NOT an issue)
- [x] 1.1 Sub-task (this becomes an issue) ✅
  - Detail description
  - Additional context
  - _Requirements: Requirement X.Y_
- [ ] 1.2 Sub-task (this also becomes an issue)
  - Detail description
  - _Requirements: Requirement X.Y_
```

**Extraction Rules**:
- **Target**: Only sub-tasks with format `N.M` (e.g., 1.1, 2.3, 7.2)
- **Scope**: Both completed `[x]` and incomplete `[ ]` tasks
- **Content**: Title (task number + description) + body (all detail bullets + requirements line)
- **Grouping**: Group by major task number for progress tracking

**Task Mapping**:
- Create title → task mapping for duplicate detection
- Preserve completion status (`[x]` vs `[ ]`) for progress display

### 3. Sub-Issue Synchronization Strategy

**🚨 CRITICAL: GitHub GraphQL API Reference 🚨**

| Phase | Operation | Mutation/Query Name | ✅ Correct | ❌ Wrong |
|-------|-----------|---------------------|-----------|----------|
| Discovery | Fetch sub-issues | `query { subIssues { ... } }` | `subIssues` | `trackedIssues` |
| Creation | Link new issue | `mutation { addSubIssue(...) }` | `addSubIssue` | `linkSubIssue` |
| **Reordering** | **Move sub-issue** | **`mutation { reprioritizeSubIssue(...) }`** | **`reprioritizeSubIssue`** | **`moveSubIssue`** |

**⚠️ Common Mistakes to Avoid**:
- ❌ `moveSubIssue` does NOT exist in GitHub GraphQL API
- ❌ `trackedIssues` returns empty results (use `subIssues` instead)
- ✅ **Always use `reprioritizeSubIssue` for reordering sub-issues**

---

#### A. Discovery Phase: Fetch Existing Sub-Issues

**🚨 CRITICAL: GraphQL Multi-line Query Syntax**

Multi-line queries with variables FAIL due to bash escaping. Use **single-line queries only**.

**Method 1: Single-line query (RECOMMENDED)**:

```bash
# ✅ Works perfectly - no escaping issues
gh api graphql -f query='query { repository(owner: "'"$OWNER"'", name: "'"$REPO"'") { issue(number: '"$ISSUE_NUMBER"') { id subIssues(first: 100) { nodes { id number title } pageInfo { hasNextPage endCursor } } } } }'
```

**Method 2: Hardcoded values (for one-off execution)**:

```bash
# ✅ Simple but not reusable
gh api graphql -f query='query { repository(owner: "tent-inc", name: "kaeuru") { issue(number: 177) { id subIssues(first: 100) { nodes { id number title } pageInfo { hasNextPage endCursor } } } } }'
```

**Response Structure**:
```json
{
  "data": {
    "repository": {
      "issue": {
        "id": "I_kwDOOLLb587NwUOI",
        "subIssues": {
          "nodes": [
            {"id": "I_kwDO...", "number": 190, "title": "1.1 Task..."}
          ],
          "pageInfo": {"hasNextPage": false}
        }
      }
    }
  }
}
```

**Pagination Handling** (when >100 sub-issues):
- Check `pageInfo.hasNextPage`
- If true, fetch next page with `after: $endCursor`
- Repeat until all pages retrieved

**Duplicate Detection**:
- Build title → id map from existing sub-issues
- Compare with tasks.md titles to identify missing issues

#### B. Creation Phase (Only When Missing Issues Found)

**For Each Missing Task**:

```bash
# Step 1: Create issue
issue_url=$(gh issue create \
  --repo "$OWNER/$REPO" \
  --title "2.1 Add discount rate field to item edit form" \
  --body "- Detail description
- Additional context
- _Requirements: Requirement 1.1_")

# Step 2: Extract issue number from URL
issue_number=$(echo "$issue_url" | grep -oE '[0-9]+$')

# Step 3: Convert issue number to GraphQL node ID (REST API - RECOMMENDED)
issue_id=$(gh api repos/$OWNER/$REPO/issues/$issue_number | jq -r '.node_id')

# Alternative: GraphQL (if you prefer consistency with other queries)
# issue_id=$(gh api graphql -f query='query { repository(owner: "'"$OWNER"'", name: "'"$REPO"'") { issue(number: '"$issue_number"') { id } } }' | jq -r '.data.repository.issue.id')

# Step 4: Link to parent issue
gh api graphql -f query='mutation { addSubIssue(input: {issueId: "'"$PARENT_ISSUE_ID"'", subIssueId: "'"$issue_id"'"}) { subIssue { id number title } } }'
```

**Variable Expansion Explanation**:
- `"'"$PARENT_ISSUE_ID"'"` = Close single quote → Open double quote → Variable → Close double quote → Open single quote
- Bash expands variables inside double quotes while preserving GraphQL syntax

**Progress Tracking**:
- Use TodoWrite to track creation progress per major task group
- Example: "Create sub-issues for Task 1 (1.1-1.3)"
- Mark completed after creating all sub-issues in group

#### C. Reordering Phase (When Order Mismatch Detected)

**🚨 CRITICAL SECTION 🚨**: This is the most error-prone part. **Follow exactly**.

**⚠️ MANDATORY API**: Use **`reprioritizeSubIssue`** mutation (NOT `moveSubIssue`!)

**Reordering Algorithm**:

1. **Collect All Sub-Issues**: Merge existing + newly created
2. **Sort by Task Number**: 1.1, 1.2, 1.3, 2.1, 2.2, ..., 7.2
3. **Sequential Placement**: Place each issue after the previous one using `reprioritizeSubIssue`

**Single Issue Reordering Command** (use this for each repositioning):

```bash
# Move #241 (4.2) after #230 (4.1)
PARENT_ID="I_kwDO...PARENT_ID"
SUB_ISSUE_241_ID="I_kwDO...SUB_ISSUE_241_ID"
SUB_ISSUE_230_ID="I_kwDO...SUB_ISSUE_230_ID"

gh api graphql -f query='mutation { reprioritizeSubIssue(input: {issueId: "'"$PARENT_ID"'", subIssueId: "'"$SUB_ISSUE_241_ID"'", afterId: "'"$SUB_ISSUE_230_ID"'"}) { issue { number } } }'
```

**Variable Expansion Pattern**:
```bash
# Pattern: '"'  $VAR  "'"
# Explanation: Close single quote → Open double quote → Variable → Close double quote → Open single quote
# Example: 'query { field: "'"$MY_VAR"'" }'
```

**Key Parameters**:
- `issueId`: Parent issue's GraphQL node ID (from Discovery Phase)
- `subIssueId`: Sub-issue to move (GraphQL node ID)
- `afterId`: Sub-issue to place after (GraphQL node ID, optional for first position)

**Return Type**: `issue { number }` returns the **parent issue**, not the sub-issue

---

**Complete Implementation Script** (for batch reordering):

```bash
#!/bin/bash
set -e

# Variables (replace with actual values)
PARENT_ID="I_kwDOOLLb587NwUOI"  # From Discovery Phase
OWNER="tent-inc"
REPO="kaeuru"
ISSUE_NUMBER=177

# Step 1: Re-fetch sub-issues to get current state
echo "Fetching sub-issues..."
sub_issues=$(gh api graphql -f query='query { repository(owner: "'"$OWNER"'", name: "'"$REPO"'") { issue(number: '"$ISSUE_NUMBER"') { subIssues(first: 100) { nodes { id number title } } } } }')

# Step 2: Build ordered list of task numbers (from tasks.md)
declare -a task_numbers=("1.1" "1.2" "1.3" "2.1" "2.2" "3.1" "3.2")
declare -a ids=()

# Step 3: Map task numbers to GraphQL node IDs
for task_num in "${task_numbers[@]}"; do
  id=$(echo "$sub_issues" | jq -r \
    --arg task "$task_num" \
    '.data.repository.issue.subIssues.nodes[] | select(.title | startswith($task)) | .id')
  ids+=("$id")
  echo "Found: $task_num -> $id"
done

echo ""
echo "Starting reordering (${#ids[@]} sub-issues)..."
echo ""

# Step 4: Place each issue (starting from 2nd) after the previous one
for i in $(seq 1 $((${#ids[@]} - 1))); do
  current_id="${ids[$i]}"
  previous_id="${ids[$((i-1))]}"
  task_name="${task_numbers[$i]}"

  echo "[$((i+1))/${#ids[@]}] Moving $task_name after ${task_numbers[$((i-1))]}..."

  # Execute reprioritizeSubIssue mutation
  gh api graphql -f query='mutation { reprioritizeSubIssue(input: {issueId: "'"$PARENT_ID"'", subIssueId: "'"$current_id"'", afterId: "'"$previous_id"'"}) { issue { number } } }' > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "  ✅ Success"
  else
    echo "  ❌ Failed"
  fi

  sleep 0.3  # Rate limiting mitigation
done

echo ""
echo "✅ All sub-issues reordered successfully!"
```

**Key Implementation Notes**:
1. **NO manual ID copy-paste**: Always fetch IDs via GraphQL
2. **Sequential placement**: Process from front to back (reverse order fails)
3. **Rate limiting**: Insert 0.3s delay between mutations
4. **Error handling**: Check exit code, continue on failure


### 4. Output & Progress Report

**Success Output Format**:

```
✅ GitHub issues created successfully!

Feature: 2025-09-25-item-discount
Parent issue: #177

Created 2 new sub-issues:
- #241: 4.2 商品詳細画面での割引情報表示 ✅
- #242: 4.3 ショッピングカートでの割引価格計算と表示 ✅

Reused 17 existing sub-issues:
- #190: 1.1 Add discount rate field to item model ✅
- #191: 1.2 Discount change history management ✅
- #192: 1.3 注文・カート時の割引情報保存機能 ✅
...

Total: 19 sub-issues linked to #177
✅ All sub-issues reordered by task number (1.1 → 7.2)

View parent issue: https://github.com/tent-inc/kaeuru/issues/177

📊 Progress: 17/19 tasks completed (89.5%)
🚀 Token savings: 98% vs MCP tools (~1,000 tokens vs ~47,000)
```

**Status Indicators**:
- ✅ after issue number = Task marked as `[x]` completed in tasks.md
- No indicator = Task still pending `[ ]`

---

## GraphQL API Reference (Implementation Details)

### Schema Definitions

**CRITICAL**: These schemas are the source of truth. Do NOT guess field names.

#### AddSubIssueInput Schema

```graphql
input AddSubIssueInput {
  issueId: ID!        # Parent issue ID (NOT parentIssueId!)
  subIssueId: ID!     # Sub-issue ID to add
}

type AddSubIssuePayload {
  subIssue: Issue     # The added sub-issue
}
```

**Common Mistake**: Using `parentIssueId` instead of `issueId`

**Correct Usage**:
```bash
gh api graphql -f query='
  mutation($issueId: ID!, $subIssueId: ID!) {
    addSubIssue(input: {issueId: $issueId, subIssueId: $subIssueId}) {
      subIssue { id number title }
    }
  }
' -f issueId="I_parent" -f subIssueId="I_new"
```

#### ReprioritizeSubIssueInput Schema

```graphql
input ReprioritizeSubIssueInput {
  issueId: ID!        # Parent issue ID
  subIssueId: ID!     # Sub-issue to reorder
  afterId: ID         # Place after this issue (OR beforeId, one required)
  beforeId: ID        # Place before this issue
}

type ReprioritizeSubIssuePayload {
  issue: Issue        # The parent issue (NOT subIssue!)
}
```

**Correct Usage**:
```bash
gh api graphql -f query='
  mutation($issueId: ID!, $subIssueId: ID!, $afterId: ID!) {
    reprioritizeSubIssue(input: {
      issueId: $issueId,
      subIssueId: $subIssueId,
      afterId: $afterId
    }) {
      issue { number }
    }
  }
' -f issueId="I_parent" -f subIssueId="I_current" -f afterId="I_previous"
```

### Query Patterns

**Pattern 1: Fetch Sub-issues (with variables)**
```bash
OWNER="tent-inc"
REPO="kaeuru"
ISSUE_NUMBER=177

gh api graphql -f query='query { repository(owner: "'"$OWNER"'", name: "'"$REPO"'") { issue(number: '"$ISSUE_NUMBER"') { id subIssues(first: 100) { nodes { id number title } pageInfo { hasNextPage endCursor } } } } }'
```

**Pattern 2: Get Issue ID from Number (REST API - RECOMMENDED)**
```bash
OWNER="tent-inc"
REPO="kaeuru"
ISSUE_NUMBER=177

gh api repos/$OWNER/$REPO/issues/$ISSUE_NUMBER | jq -r '.node_id'
```

**Pattern 3: Get Issue ID from Number (GraphQL alternative)**
```bash
OWNER="tent-inc"
REPO="kaeuru"
ISSUE_NUMBER=177

gh api graphql -f query='query { repository(owner: "'"$OWNER"'", name: "'"$REPO"'") { issue(number: '"$ISSUE_NUMBER"') { id } } }' | jq -r '.data.repository.issue.id'
```

---


## Appendix: Design Rationale

### Why gh Commands Only?

**Token Efficiency**:
| Method | Token Usage | Reduction |
|--------|-------------|-----------|
| MCP tools | ~47,000 tokens | - |
| gh commands | ~1,000 tokens | **98%** |

**Technical Advantages**:
- **No Dependencies**: Only gh CLI (no MCP server)
- **Direct API Access**: No abstraction layer overhead
- **Full Control**: Inspect responses with jq, debug queries
- **Fast Execution**: No tool marshalling overhead

**Design Trade-offs**:
- **Pro**: Maximum token efficiency, essential for large task lists
- **Pro**: Self-contained, no external service dependencies
- **Con**: More verbose syntax (GraphQL queries vs MCP function calls)
- **Con**: Manual error handling (no MCP abstraction)

**Decision**: Verbosity trade-off is acceptable given 98% token reduction and elimination of external dependencies.

think deeply

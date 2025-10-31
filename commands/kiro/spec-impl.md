---
description: Execute spec tasks using TDD methodology
allowed-tools: Bash, Read, Write, Edit, MultiEdit, Grep, Glob, LS, WebFetch, WebSearch
argument-hint: <feature-name> [task-numbers] [--commit]
---

# Execute Spec Tasks with TDD

Execute implementation tasks for **$1** using Kent Beck's Test-Driven Development methodology.

## Instructions

### Pre-Execution Validation
Validate required files exist for feature **$1**:
- Requirements: `docs/.kiro/specs/$1/requirements.md`
- Design: `docs/.kiro/specs/$1/design.md`  
- Tasks: `docs/.kiro/specs/$1/tasks.md`
- Metadata: `docs/.kiro/specs/$1/spec.json`

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

### Task Execution
1. **Feature**: $1
2. **Task numbers**: $2 (optional, defaults to all pending tasks)
3. **Commit mode**: Check if $3 contains `--commit` flag
4. **Load all context** (steering + spec documents)
5. **Execute selected tasks** using TDD methodology

### TDD Implementation
For each selected task:

1. **RED**: Write failing tests first
2. **GREEN**: Write minimal code to pass tests
3. **REFACTOR**: Clean up and improve code structure
4. **Verify**:
   - All tests pass
   - No regressions in existing tests
   - Code quality and test coverage maintained
5. **Commit** (only if `--commit` flag provided):
   - Stage all changes with `git add`
   - Create descriptive commit with task reference
   - Format: `#issue feat: implement [task-description]` or similar conventional commit
6. **Mark Complete**: Update checkbox from `- [ ]` to `- [x]` in tasks.md

**Note**: Follow Kent Beck's TDD methodology strictly, implementing only the specific task requirements. If `--commit` flag is provided, each task should result in a single, atomic commit.

## Implementation Notes

- **Feature**: Use `$1` for feature name
- **Tasks**: Use `$2` for specific task numbers (optional)
- **Commit Flag**: Use `$3` (or any argument) containing `--commit` to enable auto-commit
- **Validation**: Check all required spec files exist
- **TDD Focus**: Always write tests before implementation
- **Conditional Commits**: Only commit if `--commit` flag is explicitly provided
- **Commit Format**: When committing, follow conventional commit format with issue reference
- **Task Tracking**: Update checkboxes in tasks.md as completed (regardless of commit mode)

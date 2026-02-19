---
name: tdd
description: Drive implementation with a strict red-green-refactor workflow
argument-hint: [scope or requirement]
---

# TDD

Enforce a test-first implementation loop to reduce typo bugs, broken references, and partial
changes that pass locally but fail in CI.

Use this skill when implementing a feature or bugfix where test coverage can define expected
behavior clearly.

## Input

`$ARGUMENTS` may include a scope hint (ticket, module, or requirement summary). If omitted, infer
scope from the current branch, open issue references, and recent file changes.

Examples:

- `/tdd`
- `/tdd auth login timeout handling`
- `/tdd #123 sanitize webhook payload`

## Prerequisites

- You are on a feature branch, not the default branch.
- Local test command(s) are known from `README`, `package.json`, `Makefile`, or repo docs.
- The requirement or acceptance criteria are explicit enough to encode as tests.

## Workflow

### 1. Define behavior and test target

1. Read the requirement, issue, or bug report.
2. Identify observable behavior to verify (inputs, outputs, errors, side effects).
3. Choose the narrowest test layer that proves the behavior:
   - Unit test first by default.
   - Integration test when behavior crosses boundaries.
   - End-to-end only when lower layers cannot validate the requirement.
4. State assumptions and edge cases before writing code.

### 2. Red phase (failing test first)

1. Add or update tests that encode the desired behavior.
2. Run only relevant tests first for fast feedback.
3. Confirm tests fail for the expected reason:
   - If tests pass immediately, strengthen assertions and re-run.
   - If tests fail for unrelated reasons, fix the test setup before proceeding.
4. Do not edit production code during Red except minimal scaffolding required for compilation.

Exit gate for Red:
- At least one new/updated test fails for the target behavior.
- Failure message matches the requirement gap.

### 3. Green phase (minimal passing implementation)

1. Implement the smallest production change needed to satisfy failing tests.
2. Avoid broad refactors, API redesigns, or speculative cleanup in this phase.
3. Re-run the focused test set until all target tests pass.
4. Run related test suites to catch regressions near touched code.

Exit gate for Green:
- New target tests pass.
- No new failures in nearby test scope.

### 4. Refactor phase (keep behavior, improve design)

1. Improve naming, duplication, cohesion, and readability.
2. Keep public behavior unchanged.
3. Re-run target and related tests after each meaningful refactor.
4. If any refactor introduces uncertainty, add a regression test before continuing.

Exit gate for Refactor:
- Code is cleaner with no behavior drift.
- Tests remain green.

### 5. Full validation gate

Run full local validation before opening/updating PR:

1. Full test suite.
2. Lint/format checks used by CI.
3. Type checks/build checks (if present).

If any command fails, fix and re-run before declaring complete.

### 6. Commit and reporting

1. Commit with message that references the issue/work item.
2. Include what changed in tests and implementation.
3. Report concise TDD trace:
   - Red: which tests failed first
   - Green: minimal code path added
   - Refactor: what was improved safely

## Guardrails

- Do not skip Red because "the fix is obvious."
- Do not merge implementation-only changes without tests unless the repo explicitly disallows tests
  for that layer.
- Do not batch unrelated refactors with behavior changes.
- If requirements are ambiguous, stop and clarify before Green.

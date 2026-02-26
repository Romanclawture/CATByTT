# Codex Agent Prompt — Backend Task

## Task
{{TASK}}

## Business Context
{{CONTEXT}}

## Relevant Files
{{FILES}}

## Customer Context
{{CUSTOMER_CONTEXT}}

## Instructions
1. Read AGENTS.md / CLAUDE.md if present in the repo root
2. Understand the full scope before writing code
3. Follow existing patterns — check similar files for conventions
4. Write unit tests for all new functionality
5. Handle edge cases and errors explicitly
6. Keep commits atomic with clear messages
7. When complete: `git add -A && git commit -m "descriptive message" && git push && gh pr create --fill`

## Constraints
- Do NOT modify unrelated files
- Do NOT change package versions unless required
- Do NOT skip tests
- If blocked, document what's blocking you in the PR description

## Definition of Done
- [ ] Code changes implement the full task
- [ ] All tests pass (`npm test` or equivalent)
- [ ] No lint errors (`npm run lint` or equivalent)
- [ ] No type errors (`npm run typecheck` or equivalent)
- [ ] PR created with clear title and description
- [ ] Commits are clean and atomic

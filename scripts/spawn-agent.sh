#!/usr/bin/env bash
set -euo pipefail

# CATByTT Agent Spawner
# Creates a git worktree + tmux session for a coding agent

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${CATBYTT_HOME:-.catbytt}/active-tasks.json"

# Defaults
AGENT_TYPE="codex"
MAX_AGENTS=5
WORKTREE_BASE="/tmp/catbytt-worktrees"

usage() {
  cat <<EOF
Usage: spawn-agent.sh [options]

Options:
  --repo <path>        Target repository path (required)
  --task <description> Task description (required)
  --agent <type>       Agent type: codex|claude|gemini (default: codex)
  --branch <name>      Branch name (auto-generated if omitted)
  --files <paths>      Comma-separated list of relevant files
  --context <text>     Additional context for the agent
  --priority <level>   Priority: low|medium|high (default: medium)
  -h, --help           Show this help
EOF
  exit 0
}

# Parse args
REPO=""
TASK=""
BRANCH=""
FILES=""
CONTEXT=""
PRIORITY="medium"

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO="$2"; shift 2;;
    --task) TASK="$2"; shift 2;;
    --agent) AGENT_TYPE="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --files) FILES="$2"; shift 2;;
    --context) CONTEXT="$2"; shift 2;;
    --priority) PRIORITY="$2"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

# Validate
if [[ -z "$REPO" || -z "$TASK" ]]; then
  echo "Error: --repo and --task are required"
  usage
fi

if [[ ! -d "$REPO/.git" ]]; then
  echo "Error: $REPO is not a git repository"
  exit 1
fi

# Generate branch name if not provided
if [[ -z "$BRANCH" ]]; then
  SLUG=$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | cut -c1-50)
  BRANCH="catbytt/${SLUG}-$(date +%s | tail -c 5)"
fi

# Generate task ID
TASK_ID="cat-$(date +%s)-$$"
SESSION_NAME="catbytt-${TASK_ID}"

# Check active agent count
if [[ -f "$REGISTRY" ]]; then
  ACTIVE_COUNT=$(jq '[.[] | select(.status == "running")] | length' "$REGISTRY" 2>/dev/null || echo 0)
  if [[ "$ACTIVE_COUNT" -ge "$MAX_AGENTS" ]]; then
    echo "Error: Max agents ($MAX_AGENTS) already running. Wait for one to finish or increase MAX_AGENTS."
    exit 1
  fi
fi

# Create worktree
WORKTREE_PATH="${WORKTREE_BASE}/${TASK_ID}"
echo "Creating worktree at $WORKTREE_PATH on branch $BRANCH..."

cd "$REPO"
git fetch origin main 2>/dev/null || true
git worktree add -b "$BRANCH" "$WORKTREE_PATH" origin/main 2>/dev/null || \
  git worktree add -b "$BRANCH" "$WORKTREE_PATH" main

echo "Worktree created."

# Build the agent prompt
PROMPT_FILE="${WORKTREE_PATH}/.catbytt-prompt.md"
cat > "$PROMPT_FILE" <<PROMPT
# Task: ${TASK}

## Context
${CONTEXT:-No additional context provided.}

## Relevant Files
${FILES:-No specific files specified. Explore the codebase as needed.}

## Instructions
1. Understand the task fully before writing code
2. Follow existing code conventions and patterns
3. Write tests for any new functionality
4. Keep commits atomic and well-described
5. When done: commit, push, and create a PR with \`gh pr create --fill\`

## Definition of Done
- [ ] Code changes committed and pushed
- [ ] PR created with clear description
- [ ] Tests pass locally
- [ ] No lint errors
- [ ] If UI changes: include screenshot in PR description
PROMPT

# Choose agent command
case "$AGENT_TYPE" in
  codex)
    AGENT_CMD="cd ${WORKTREE_PATH} && codex --full-auto -q '$(cat "$PROMPT_FILE")'"
    ;;
  claude)
    AGENT_CMD="cd ${WORKTREE_PATH} && claude -p '$(cat "$PROMPT_FILE")'"
    ;;
  gemini)
    AGENT_CMD="cd ${WORKTREE_PATH} && gemini '$(cat "$PROMPT_FILE")'"
    ;;
  *)
    echo "Error: Unknown agent type: $AGENT_TYPE"
    exit 1
    ;;
esac

# Log file
LOG_DIR="${CATBYTT_HOME:-.catbytt}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/${TASK_ID}.log"

# Launch tmux session
echo "Launching ${AGENT_TYPE} agent in tmux session: ${SESSION_NAME}..."
tmux new-session -d -s "$SESSION_NAME" "script -q ${LOG_FILE} bash -c '${AGENT_CMD}'"

# Register task
mkdir -p "$(dirname "$REGISTRY")"
if [[ ! -f "$REGISTRY" ]]; then
  echo "[]" > "$REGISTRY"
fi

TASK_JSON=$(jq -n \
  --arg id "$TASK_ID" \
  --arg task "$TASK" \
  --arg branch "$BRANCH" \
  --arg agent "$AGENT_TYPE" \
  --arg session "$SESSION_NAME" \
  --arg worktree "$WORKTREE_PATH" \
  --arg repo "$REPO" \
  --arg status "running" \
  --arg priority "$PRIORITY" \
  --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg log "$LOG_FILE" \
  '{
    id: $id,
    task: $task,
    branch: $branch,
    agent: $agent,
    session: $session,
    worktree: $worktree,
    repo: $repo,
    status: $status,
    priority: $priority,
    started: $started,
    log: $log,
    pr: null,
    attempts: 1,
    max_attempts: 3
  }')

jq --argjson task "$TASK_JSON" '. += [$task]' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"

echo ""
echo "✅ Agent spawned!"
echo "   Task ID:    $TASK_ID"
echo "   Branch:     $BRANCH"
echo "   Session:    $SESSION_NAME"
echo "   Worktree:   $WORKTREE_PATH"
echo "   Log:        $LOG_FILE"
echo ""
echo "   Attach:     tmux attach -t $SESSION_NAME"
echo "   Send keys:  tmux send-keys -t $SESSION_NAME 'your message' Enter"

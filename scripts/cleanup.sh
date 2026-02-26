#!/usr/bin/env bash
set -euo pipefail

# CATByTT Cleanup
# Removes completed/failed task worktrees and cleans up registry

REGISTRY="${CATBYTT_HOME:-.catbytt}/active-tasks.json"
WORKTREE_BASE="/tmp/catbytt-worktrees"

if [[ ! -f "$REGISTRY" ]]; then
  echo "No registry found."
  exit 0
fi

echo "=== CATByTT Cleanup $(date) ==="

# Kill orphaned tmux sessions
TASKS=$(jq -c '.[] | select(.status == "completed" or .status == "failed" or .status == "merged")' "$REGISTRY")

while IFS= read -r task; do
  [[ -z "$task" ]] && continue
  
  SESSION=$(echo "$task" | jq -r '.session')
  WORKTREE=$(echo "$task" | jq -r '.worktree')
  REPO=$(echo "$task" | jq -r '.repo')
  BRANCH=$(echo "$task" | jq -r '.branch')
  ID=$(echo "$task" | jq -r '.id')
  STATUS=$(echo "$task" | jq -r '.status')
  
  echo "Cleaning up: $ID ($STATUS)"
  
  # Kill tmux session if still running
  tmux kill-session -t "$SESSION" 2>/dev/null && echo "  Killed tmux session: $SESSION" || true
  
  # Remove worktree
  if [[ -d "$WORKTREE" ]]; then
    cd "$REPO" 2>/dev/null && git worktree remove "$WORKTREE" --force 2>/dev/null && \
      echo "  Removed worktree: $WORKTREE" || \
      echo "  Warning: Could not remove worktree: $WORKTREE"
  fi
  
  # Delete branch if merged
  if [[ "$STATUS" == "merged" && -d "$REPO" ]]; then
    cd "$REPO" && git branch -D "$BRANCH" 2>/dev/null && \
      echo "  Deleted local branch: $BRANCH" || true
    cd "$REPO" && git push origin --delete "$BRANCH" 2>/dev/null && \
      echo "  Deleted remote branch: $BRANCH" || true
  fi

done <<< "$TASKS"

# Remove cleaned-up tasks from registry
jq '[.[] | select(.status != "completed" and .status != "failed" and .status != "merged")]' \
  "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"

# Clean up old alert files (older than 24h)
find "${CATBYTT_HOME:-.catbytt}/" -name "alerts-*.txt" -mmin +1440 -delete 2>/dev/null || true

# Clean up old log files (older than 7 days)
find "${CATBYTT_HOME:-.catbytt}/logs/" -name "*.log" -mmin +10080 -delete 2>/dev/null || true

REMAINING=$(jq 'length' "$REGISTRY")
echo ""
echo "Cleanup complete. $REMAINING active tasks remaining."

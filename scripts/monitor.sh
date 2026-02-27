#!/usr/bin/env bash
set -euo pipefail

# StickyNicky Agent Monitor
# Runs via cron every 10 minutes to babysit all agents
# 100% deterministic — no LLM calls, pure script logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${CATBYTT_HOME:-.stickynicky}/active-tasks.json"
ALERTS=""

if [[ ! -f "$REGISTRY" ]]; then
  echo "No active tasks registry found."
  exit 0
fi

TASKS=$(jq -c '.[]' "$REGISTRY")

if [[ -z "$TASKS" ]]; then
  echo "No active tasks."
  exit 0
fi

echo "=== StickyNicky Monitor $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo ""

while IFS= read -r task; do
  ID=$(echo "$task" | jq -r '.id')
  TASK_DESC=$(echo "$task" | jq -r '.task')
  SESSION=$(echo "$task" | jq -r '.session')
  BRANCH=$(echo "$task" | jq -r '.branch')
  REPO=$(echo "$task" | jq -r '.repo')
  STATUS=$(echo "$task" | jq -r '.status')
  ATTEMPTS=$(echo "$task" | jq -r '.attempts')
  MAX_ATTEMPTS=$(echo "$task" | jq -r '.max_attempts')
  AGENT_TYPE=$(echo "$task" | jq -r '.agent')
  WORKTREE=$(echo "$task" | jq -r '.worktree')

  echo "--- Task: $ID ($TASK_DESC) ---"
  echo "    Status: $STATUS | Agent: $AGENT_TYPE | Attempts: $ATTEMPTS/$MAX_ATTEMPTS"

  # Skip completed/failed tasks
  if [[ "$STATUS" == "completed" || "$STATUS" == "failed" || "$STATUS" == "merged" ]]; then
    echo "    Skipping ($STATUS)"
    continue
  fi

  # 1. Check if tmux session is alive
  SESSION_ALIVE=$(tmux has-session -t "$SESSION" 2>/dev/null && echo "yes" || echo "no")
  echo "    Session alive: $SESSION_ALIVE"

  if [[ "$SESSION_ALIVE" == "no" && "$STATUS" == "running" ]]; then
    echo "    ⚠️  Session died!"
    
    # Check if there's a PR already
    PR_URL=""
    if [[ -d "$REPO" ]]; then
      PR_URL=$(cd "$REPO" && gh pr list --head "$BRANCH" --json url -q '.[0].url' 2>/dev/null || echo "")
    fi

    if [[ -n "$PR_URL" ]]; then
      echo "    PR found: $PR_URL — marking as pr_open"
      jq --arg id "$ID" --arg pr "$PR_URL" '
        map(if .id == $id then .status = "pr_open" | .pr = $pr else . end)
      ' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
      STATUS="pr_open"
    else
      # No PR and session died — agent failed
      if [[ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ]]; then
        echo "    Respawning (attempt $((ATTEMPTS + 1))/$MAX_ATTEMPTS)..."
        ALERTS="${ALERTS}\n🔄 Respawning agent for: $TASK_DESC (attempt $((ATTEMPTS + 1)))"
        
        # Update attempts
        jq --arg id "$ID" '
          map(if .id == $id then .attempts = (.attempts + 1) | .status = "respawning" else . end)
        ' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
        
        # Respawn
        "${SCRIPT_DIR}/spawn-agent.sh" \
          --repo "$REPO" \
          --task "$TASK_DESC" \
          --agent "$AGENT_TYPE" \
          --branch "$BRANCH" 2>&1 || true
      else
        echo "    ❌ Max attempts reached. Marking as failed."
        ALERTS="${ALERTS}\n❌ Agent failed after $MAX_ATTEMPTS attempts: $TASK_DESC"
        jq --arg id "$ID" '
          map(if .id == $id then .status = "failed" else . end)
        ' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
      fi
    fi
  fi

  # 2. Check for open PRs
  if [[ "$STATUS" == "pr_open" || "$STATUS" == "running" ]]; then
    PR_URL=$(echo "$task" | jq -r '.pr // empty')
    
    if [[ -z "$PR_URL" && -d "$REPO" ]]; then
      PR_URL=$(cd "$REPO" && gh pr list --head "$BRANCH" --json url -q '.[0].url' 2>/dev/null || echo "")
      if [[ -n "$PR_URL" ]]; then
        echo "    New PR found: $PR_URL"
        jq --arg id "$ID" --arg pr "$PR_URL" '
          map(if .id == $id then .status = "pr_open" | .pr = $pr else . end)
        ' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
        STATUS="pr_open"
      fi
    fi

    # 3. Check CI status
    if [[ -n "$PR_URL" && -d "$REPO" ]]; then
      PR_NUM=$(echo "$PR_URL" | grep -o '[0-9]*$')
      CI_STATUS=$(cd "$REPO" && gh pr checks "$PR_NUM" --json state -q '.[].state' 2>/dev/null | sort -u || echo "UNKNOWN")
      
      echo "    CI: $CI_STATUS"

      if echo "$CI_STATUS" | grep -q "SUCCESS"; then
        # Check review status
        REVIEW_STATE=$(cd "$REPO" && gh pr view "$PR_NUM" --json reviewDecision -q '.reviewDecision' 2>/dev/null || echo "")
        echo "    Review: ${REVIEW_STATE:-pending}"

        if [[ "$REVIEW_STATE" == "APPROVED" || -z "$REVIEW_STATE" ]]; then
          echo "    ✅ PR ready for human review!"
          ALERTS="${ALERTS}\n✅ PR #${PR_NUM} ready for review: $TASK_DESC\n   $PR_URL"
          jq --arg id "$ID" '
            map(if .id == $id then .status = "ready_for_review" else . end)
          ' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
        fi

      elif echo "$CI_STATUS" | grep -q "FAILURE"; then
        echo "    ❌ CI failed!"
        
        if [[ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ]]; then
          ALERTS="${ALERTS}\n🔄 CI failed for: $TASK_DESC — respawning with failure context"
          # Get failure details
          FAILURE_LOG=$(cd "$REPO" && gh pr checks "$PR_NUM" 2>/dev/null | grep -i fail || echo "Unknown failure")
          
          jq --arg id "$ID" --arg log "$FAILURE_LOG" '
            map(if .id == $id then .attempts = (.attempts + 1) | .status = "respawning" | .last_failure = $log else . end)
          ' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
        else
          ALERTS="${ALERTS}\n❌ CI keeps failing for: $TASK_DESC (giving up after $MAX_ATTEMPTS attempts)"
          jq --arg id "$ID" '
            map(if .id == $id then .status = "failed" else . end)
          ' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
        fi
      fi
    fi
  fi

  echo ""
done <<< "$TASKS"

# Output alerts
if [[ -n "$ALERTS" ]]; then
  echo "=== ALERTS ==="
  echo -e "$ALERTS"
  
  # Write alerts to file for OpenClaw to pick up
  ALERT_FILE="${CATBYTT_HOME:-.stickynicky}/alerts-$(date +%s).txt"
  echo -e "$ALERTS" > "$ALERT_FILE"
  echo ""
  echo "Alerts written to: $ALERT_FILE"
fi

echo "=== Monitor complete ==="

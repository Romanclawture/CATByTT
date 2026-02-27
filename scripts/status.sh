#!/usr/bin/env bash
set -euo pipefail

# StickyNicky Status — Quick overview of all agents

REGISTRY="${CATBYTT_HOME:-.stickynicky}/active-tasks.json"

if [[ ! -f "$REGISTRY" ]]; then
  echo "No active tasks."
  exit 0
fi

TOTAL=$(jq 'length' "$REGISTRY")
RUNNING=$(jq '[.[] | select(.status == "running")] | length' "$REGISTRY")
PR_OPEN=$(jq '[.[] | select(.status == "pr_open")] | length' "$REGISTRY")
READY=$(jq '[.[] | select(.status == "ready_for_review")] | length' "$REGISTRY")
FAILED=$(jq '[.[] | select(.status == "failed")] | length' "$REGISTRY")
COMPLETED=$(jq '[.[] | select(.status == "completed" or .status == "merged")] | length' "$REGISTRY")

echo "🐯 StickyNicky Agent Status"
echo "========================"
echo "  Running:          $RUNNING"
echo "  PR Open:          $PR_OPEN"
echo "  Ready for Review: $READY"
echo "  Failed:           $FAILED"
echo "  Completed:        $COMPLETED"
echo "  Total:            $TOTAL"
echo ""

# Show running agents
if [[ "$RUNNING" -gt 0 ]]; then
  echo "🔄 Running Agents:"
  jq -r '.[] | select(.status == "running") | "  [\(.agent)] \(.task) (branch: \(.branch))"' "$REGISTRY"
  echo ""
fi

# Show PRs ready for review
if [[ "$READY" -gt 0 ]]; then
  echo "✅ Ready for Review:"
  jq -r '.[] | select(.status == "ready_for_review") | "  \(.task)\n  PR: \(.pr)"' "$REGISTRY"
  echo ""
fi

# Show failed
if [[ "$FAILED" -gt 0 ]]; then
  echo "❌ Failed:"
  jq -r '.[] | select(.status == "failed") | "  \(.task) (attempts: \(.attempts)/\(.max_attempts))"' "$REGISTRY"
  echo ""
fi

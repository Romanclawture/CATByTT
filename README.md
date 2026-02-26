# CATByTT — Coding Agent Team, Built by Two Tigers 🐯🐯

An AI coding agent swarm orchestrated through OpenClaw. One person, a fleet of coding agents, shipping like a full dev team.

## Architecture

```
You (Telegram) → OpenClaw (Orchestrator) → Coding Agents (Codex / Claude Code)
                        ↓                          ↓
                  Business Context            Git Worktrees
                  Memory / Skills             Tmux Sessions
                  Task Registry               CI/CD Pipeline
                        ↓                          ↓
                  Monitor & Retry  ←──────  PR + AI Reviews
                        ↓
                  Telegram: "PR ready to merge"
```

## How It Works

1. **You describe what you want** → OpenClaw scopes the task with full business context
2. **Orchestrator spawns agents** → Each gets an isolated git worktree + tmux session
3. **Agents code autonomously** → Commit, push, open PRs
4. **Monitoring cron watches** → Checks sessions, CI, reviews every 10 minutes
5. **AI reviewers check PRs** → Multiple models review before you see it
6. **You get pinged** → "PR #42 ready to merge" — review takes 5 minutes
7. **Failed agents get retried** → With better prompts based on what went wrong

## Components

| Component | File | Purpose |
|-----------|------|---------|
| Agent Launcher | `scripts/spawn-agent.sh` | Creates worktree + tmux session |
| Task Registry | `.catbytt/active-tasks.json` | Tracks all running agents |
| Monitor | `scripts/monitor.sh` | Cron job that babysits agents |
| Cleanup | `scripts/cleanup.sh` | Removes orphaned worktrees |
| Templates | `templates/` | Prompt templates per agent type |

## Setup

```bash
# Clone into your OpenClaw workspace
git clone https://github.com/Romanclawture/CATByTT.git

# Make scripts executable
chmod +x scripts/*.sh

# Set your target repo
export CATBYTT_REPO=/path/to/your/project

# Spawn your first agent
./scripts/spawn-agent.sh --repo $CATBYTT_REPO --task "Fix the login bug" --agent codex
```

## Requirements

- OpenClaw (orchestration)
- GitHub CLI (`gh`) authenticated
- `tmux`
- Codex CLI and/or Claude Code CLI
- Node.js project with CI/CD

## Cost

Start at ~$20/month. Scale to ~$200/month with heavy usage.

## License

MIT

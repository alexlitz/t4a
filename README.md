# t4a - Task Queue for AI Agents

A lightweight, file-based task queue for coordinating AI coding agents (Claude, Opencode, Aider, etc.). 823 lines of Python, zero dependencies beyond stdlib + PyYAML.

## Install

```bash
mkdir -p ~/.local/bin
curl -sSL https://raw.githubusercontent.com/alexlitz/t4a/main/t4a -o ~/.local/bin/t4a
chmod +x ~/.local/bin/t4a
```

Ensure `~/.local/bin` is in your PATH:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Quick Start

```bash
# Add a task
t4a add "Implement user authentication"

# Start a worker (uses claude by default)
t4a work

# Or with a specific agent
t4a work --command "opencode --print"
t4a work --command "aider --yes-always"
```

## Commands

### Job Management

| Command | Description |
|---------|-------------|
| `t4a add <prompt>` | Add job to queue |
| `t4a list [--pending\|--running\|--done] [--tree]` | List jobs |
| `t4a status [JOB]` | Show queue or job status |
| `t4a peek [JOB]` | JSON output (for agents to parse) |

### Job Lifecycle

| Command | Description |
|---------|-------------|
| `t4a claim [JOB]` | Claim a job (or specific job) |
| `t4a complete JOB [--summary TEXT]` | Mark job done |
| `t4a fail JOB [--error TEXT]` | Mark job failed |
| `t4a pause JOB` | Pause (releasable) |
| `t4a kill JOB` | Kill running job |
| `t4a retry JOB` | Retry failed job |

### Progress & Checkpoints

| Command | Description |
|---------|-------------|
| `t4a progress JOB <0-100> [--message TEXT]` | Update progress |
| `t4a checkpoint JOB [--message TEXT]` | Save checkpoint |
| `t4a attach JOB` | Attach to running job output |
| `t4a logs JOB [-f]` | View job logs |
| `t4a events JOB` | View event history |

### Worker & Daemon

| Command | Description |
|---------|-------------|
| `t4a work [--daemon]` | Start worker (fg or bg) |
| `t4a daemon start\|stop\|status` | Manage background worker |
| `t4a monitor [--auto-recover]` | Monitor and recover stalled jobs |

### GPU & Resources

| Command | Description |
|---------|-------------|
| `t4a gpu status` | Show GPU status |
| `t4a gpu reserve N [JOB]` | Reserve N GPUs |
| `t4a gpu release JOB` | Release GPU reservation |

### Admin

| Command | Description |
|---------|-------------|
| `t4a approve JOB` | Approve gated job |
| `t4a priority JOB <0-100>` | Set priority |
| `t4a recover` | Recover stalled jobs |
| `t4a gc [--older-than N]` | Clean jobs older than N days |
| `t4a config get\|set KEY [VALUE]` | View/edit config |

## Job Options

```bash
t4a add "Train LLM" \
  --priority 80 \              # 0-100, default 50
  --gpu 2 \                    # Reserve 2 GPUs
  --gpu-mem 16000 \            # Min 16GB VRAM per GPU
  --depends-on job-abc123 \    # Wait for dependency
  --requires-approval          # Block until approved
```

## Agent Integration

### For LLMs to Check Queue

```bash
t4a peek                    # JSON summary of queue state
t4a peek job-abc123         # JSON summary of specific job
```

Output format:
```json
{
  "queue": {"pending": 3, "running": 1, "done": 12},
  "gpu": {"available": 2, "total": 4},
  "jobs": {"pending": [...], "running": [...]}
}
```

### For LLMs to Delegate

```bash
t4a ask job-abc123 "What files were modified?"
```

Uses a cheaper model (claude-3-5-haiku by default) to answer questions about a job.

### Worker Configuration

Edit `~/.t4a/config.yaml`:

```yaml
agents:
  default:
    command: claude --print
    capabilities: [file_read, file_write, shell_exec]
  cheap:
    command: claude --model claude-3-5-haiku --print
    capabilities: [file_read]
  opencode:
    command: opencode --print
  aider:
    command: aider --yes-always

checkpoint:
  interval: 300              # Auto-checkpoint every 5 min

session:
  claim_timeout: 300         # Session dead after 5 min no heartbeat

hooks:
  on_job_complete: []
  on_job_fail: []
```

## Features

### Priority Queue
Jobs sorted by priority (higher = more urgent). GPU jobs get -10 penalty to prefer non-GPU jobs when equal priority.

### Dependencies
```bash
t4a add "Set up database"           # Returns job-aaa111
t4a add "Add users table" --depends-on job-aaa111
t4a add "Add auth" --depends-on job-aaa111  # Can have multiple deps
```

### Approval Gates
```bash
t4a add "Deploy to production" --requires-approval
# Job sits in pending until:
t4a approve job-abc123
```

### GPU Management
- Exclusive GPU reservation per job
- Memory requirements checked before allocation
- Auto-release on complete/fail/pause
- `CUDA_VISIBLE_DEVICES` set for worker process

### Checkpointing
- Auto-checkpoint every N seconds (configurable)
- Manual checkpoints with `t4a checkpoint`
- Context preserved in `~/.t4a/jobs/{id}/context.md`
- Jobs resume from last checkpoint after crash

### Auto-Recovery
```bash
t4a monitor --auto-recover
```
- Monitors running jobs for stalled heartbeats
- Auto-pauses jobs whose session died
- Can run as separate process from worker

## File Structure

```
~/.t4a/
├── config.yaml          # Configuration
├── daemon.pid           # Daemon PID file
├── daemon.log           # Daemon output log
├── gpus.yaml            # GPU reservations
├── resources.yaml       # Resource usage tracking
├── jobs/
│   └── {job-id}/
│       ├── job.yaml     # Job definition (immutable)
│       ├── state.yaml   # Current state (mutable)
│       ├── context.md   # Resume context for agent
│       ├── output.log   # Agent stdout/stderr
│       └── events.jsonl # Event log
├── queue/
│   ├── pending/         # Symlinks to pending jobs
│   ├── running/         # Symlinks to running jobs
│   └── done/            # Symlinks to completed jobs
├── sessions/
│   └── {session-id}/
│       ├── session.yaml # Session metadata
│       └── heartbeat    # Last heartbeat timestamp
├── approvals/
│   └── {job-id}         # Exists if job approved
└── delegation/
    └── {task-id}/
        └── task.yaml    # Delegation task
```

## Testing

```bash
python3 test_t4a.py       # Run 26 unit tests
```

## Examples

### Background Worker for Claude
```bash
t4a daemon start
t4a daemon status         # Check if running
t4a daemon stop           # Stop daemon
```

### Priority-Based Processing
```bash
# High priority tasks first
t4a add "Fix production bug" --priority 95
t4a add "Refactor module" --priority 60
t4a add "Write docs" --priority 20
```

### GPU Training Pipeline
```bash
# Reserve GPUs for training
t4a add "Preprocess data" --priority 80
t4a add "Train model epoch 1" --gpu 2 --gpu-mem 20000 --priority 70
t4a add "Train model epoch 2" --gpu 2 --gpu-mem 20000 --priority 70 --depends-on job-prev
```

### Safe Deployment with Approval
```bash
t4a add "Run migrations" --requires-approval --priority 90
t4a add "Deploy to staging" --requires-approval --depends-on job-migration
t4a add "Deploy to prod" --requires-approval --depends-on job-staging

# After review:
t4a approve job-migration
t4a approve job-staging
t4a approve job-prod
```

## Integration Tips

### With Opencode
Add to your project's AGENTS.md:
```markdown
## Task Queue

Before starting work, check for queued tasks:
\`\`\`bash
t4a peek
\`\`\`

If tasks exist, claim and work on them:
\`\`\`bash
t4a work --command "opencode --print"
\`\`\`
```

### With Claude Code
```bash
t4a work --command "claude --print"
```

### Cron-Based Scheduler
```cron
# Add periodic tasks
0 9 * * * t4a add "Daily security scan" --priority 70
0 0 * * 0 t4a add "Weekly cleanup" --priority 30
```

## Global Agent Integration

Make t4a available to all your projects by adding instructions to global agent configs.

### Opencode Global

Create or edit `~/.config/opencode/AGENTS.md`:

```markdown
# Task Queue

Before starting work, check for queued tasks:

    t4a peek

If tasks exist, work on them:

    t4a work --command "opencode --print"

Or claim manually:

    JOB=$(t4a claim)
    t4a status $JOB
```

### Claude Code Global

Create or edit `~/.claude/CLAUDE.md`:

```markdown
# Task Queue

Before starting work, check for queued tasks:

    t4a peek

If tasks exist, work on them:

    t4a work --command "claude --print"

Or claim manually:

    JOB=$(t4a claim)
    t4a status $JOB
```

### Project-Level Integration

Copy the included templates to your projects:

```bash
# For Opencode
cp AGENTS.md /path/to/your/project/

# For Claude Code
cp CLAUDE.md /path/to/your/project/
```

### Shell Alias

Add to your shell config for convenience:

```bash
# ~/.bashrc or ~/.zshrc
alias tq='t4a'
alias tqa='t4a add'
alias tql='t4a list'
alias tqs='t4a status'
alias tqw='t4a work --command "claude --print"'
```

## License

MIT

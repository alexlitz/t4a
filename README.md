# t4a - Task Queue for Agents

A lightweight, file-based task queue for AI coding agents. 975 lines of Python.

## Install

```bash
cp t4a ~/bin/t4a
chmod +x ~/bin/t4a
```

## Quick Start

```bash
t4a add "Implement authentication" --priority 80
t4a work --command "claude --print"
```

## Commands

| Command | Description |
|---------|-------------|
| `t4a add <prompt>` | Add job (options: --priority, --gpu, --gpu-mem, --requires-approval, --depends-on) |
| `t4a list [--tree]` | List jobs |
| `t4a status [JOB]` | Queue or job status |
| `t4a peek [JOB]` | JSON summary (for agents) |
| `t4a ask JOB <question>` | Ask cheap agent about job |
| `t4a work [--daemon]` | Start worker (foreground or daemon) |
| `t4a daemon start\|stop\|status` | Background worker control |
| `t4a monitor [--auto-recover]` | Monitor and recover stalled jobs |
| `t4a claim\|complete\|fail\|pause\|kill\|retry JOB` | Job lifecycle |
| `t4a priority JOB N` | Set priority (0-100) |
| `t4a progress JOB PCT` | Update progress |
| `t4a checkpoint JOB` | Create checkpoint |
| `t4a approve JOB` | Approve gated job |
| `t4a attach\|logs\|events JOB` | View job output |
| `t4a gpu status` | GPU status |
| `t4a recover` | Recover stalled jobs |
| `t4a gc [--older-than N]` | Clean old jobs |

## Features

### Agent Integration
```bash
t4a peek                          # Queue state as JSON
t4a peek job-abc123               # Job state as JSON
t4a ask job-abc123 "Is it stuck?" # Delegate to cheap agent
```

### Daemon Mode
```bash
t4a work --daemon                 # Run in background
t4a daemon status                 # Check status
t4a daemon stop                   # Stop daemon
```

### Auto-Recovery
```bash
t4a monitor --auto-recover        # Monitor and auto-recover stalled jobs
```

### Job Queue
- Priority-based (0-100)
- Dependencies: `--depends-on job-id`
- Approval gates: `--requires-approval`

### GPU Support
```bash
t4a add "Train model" --gpu 2 --gpu-mem 8000
t4a gpu status
```

### Context Persistence
- Checkpoints saved automatically
- Jobs survive agent crashes
- Resume from last checkpoint

## File Structure

```
~/.t4a/
├── config.yaml      # Configuration
├── daemon.pid       # Daemon PID
├── daemon.log       # Daemon logs
├── jobs/{id}/
│   ├── job.yaml     # Job definition
│   ├── state.yaml   # Current state
│   ├── context.md   # Resume context
│   ├── output.log   # Agent output
│   └── events.jsonl # Event stream
└── queue/
    ├── pending/     # Waiting jobs
    ├── running/     # Active jobs
    └── done/        # Completed jobs
```

## Testing

```bash
python3 test_t4a.py  # Run 26 unit tests
```

## Integration with Claude/Opencode

```bash
t4a work --command "claude --print"
t4a work --command "opencode --print"

# Or configure in ~/.t4a/config.yaml
agents:
  default:
    command: claude --print
  cheap:
    command: claude --model claude-3-5-haiku --print
```

# t4a - Task Queue Integration

This project manages tasks through t4a, a task queue for AI agents.

## Before Starting Work

Check the queue:

```bash
t4a peek
```

If pending tasks exist, claim and work on them:

```bash
t4a work --command "opencode --print"
```

## Manual Task Management

```bash
# Claim specific job
t4a claim job-abc123

# Check what it needs
t4a status job-abc123

# Update progress while working
t4a progress job-abc123 50 --message "Halfway done"

# Create checkpoint before risky change
t4a checkpoint job-abc123 --message "Before refactor"

# Mark complete
t4a complete job-abc123 --summary "Implemented X, Y, Z"
```

## Adding Tasks

```bash
# Basic task
t4a add "Write unit tests for auth module"

# With priority (0-100, higher = more urgent)
t4a add "Fix critical bug" --priority 95

# With GPU requirement
t4a add "Train model" --gpu 2 --gpu-mem 16000

# With dependency
t4a add "Deploy to prod" --depends-on job-abc123

# Requiring approval
t4a add "Delete production data" --requires-approval
```

## Useful Commands

```bash
t4a list                  # List all jobs
t4a list --pending        # Only pending
t4a status               # Queue summary
t4a logs job-abc123 -f   # Follow job output
t4a events job-abc123    # Event history
```

## Install

```bash
mkdir -p ~/.local/bin
curl -sSL https://raw.githubusercontent.com/alexlitz/t4a/main/t4a -o ~/.local/bin/t4a
chmod +x ~/.local/bin/t4a
```

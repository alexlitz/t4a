# t4a - Task Queue Integration

This project includes a task queue system. Before starting new work, check for queued tasks.

## Quick Check

```bash
t4a peek
```

If there are pending or running jobs, consider working on them first:

```bash
# Work on highest priority task
t4a work --command "claude --print"

# Or manually claim and complete
JOB=$(t4a claim)
t4a status $JOB
# ... do the work ...
t4a complete $JOB --summary "Done"
```

## Adding Tasks

When you identify work that should be deferred or parallelized:

```bash
t4a add "Task description" --priority 50

# With options:
t4a add "GPU training task" --gpu 2 --priority 80
t4a add "Deploy after review" --requires-approval --depends-on job-prev
```

## Checking Status

```bash
t4a status              # Queue overview
t4a status job-abc123   # Specific job
t4a list --tree         # Tree view with deps
```

## Install

If t4a is not installed:

```bash
mkdir -p ~/.local/bin
curl -sSL https://raw.githubusercontent.com/alexlitz/t4a/main/t4a -o ~/.local/bin/t4a
chmod +x ~/.local/bin/t4a
```

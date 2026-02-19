#!/bin/bash
# Simple test agent that simulates GPU work
cat > /dev/null  # Consume stdin (the prompt)
echo "Starting GPU job..."
echo "PROGRESS:10% Starting"
sleep 3
echo "PROGRESS:50% Processing on GPU"
sleep 3
echo "PROGRESS:90% Finishing up"
sleep 2
echo "PROGRESS:100% Complete"
echo "GPU job finished successfully"

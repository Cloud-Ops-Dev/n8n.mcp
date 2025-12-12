#!/bin/sh
# Common logging script for n8n workflows
# Usage: ./workflow-logger.sh <workflow_name> <status> [details]

WORKFLOW_NAME=$1
STATUS=$2
DETAILS=$3
LOG_FILE="/logs/workflow-execution.log"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Get timestamp in CST/CDT (America/Chicago)
TIMESTAMP=$(TZ="America/Chicago" date +"%Y-%m-%d %H:%M:%S %Z")

# Format log entry
if [ -z "$DETAILS" ]; then
  LOG_ENTRY="[$TIMESTAMP] $WORKFLOW_NAME - $STATUS"
else
  LOG_ENTRY="[$TIMESTAMP] $WORKFLOW_NAME - $STATUS - $DETAILS"
fi

# Append to log file
echo "$LOG_ENTRY" >> "$LOG_FILE"

# Also output to stdout for workflow visibility
echo "✓ Logged: $LOG_ENTRY"

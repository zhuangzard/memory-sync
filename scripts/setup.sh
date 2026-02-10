#!/bin/bash
# memory-sync setup — 自动添加三层记忆cron jobs
# Usage: bash setup.sh [--tz TIMEZONE] [--model MODEL]

set -e

TIMEZONE="${TIMEZONE:-America/New_York}"
MODEL="${MODEL:-anthropic/claude-sonnet-4-5}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --tz) TIMEZONE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🧠 Memory Sync Setup"
echo "  Timezone: $TIMEZONE"
echo "  Model: $MODEL"
echo ""

# Read prompt templates
DAILY_PROMPT=$(cat "$TEMPLATE_DIR/daily-sync-prompt.md")
WEEKLY_PROMPT=$(cat "$TEMPLATE_DIR/weekly-compound-prompt.md")
MICRO_PROMPT=$(cat "$TEMPLATE_DIR/micro-sync-prompt.md")

# Check if openclaw CLI is available
if ! command -v openclaw &> /dev/null; then
  # Try common paths
  if [ -f "$HOME/.npm-global/bin/openclaw" ]; then
    OPENCLAW="$HOME/.npm-global/bin/openclaw"
  else
    echo "❌ openclaw CLI not found. Please add it to PATH."
    exit 1
  fi
else
  OPENCLAW="openclaw"
fi

# Get gateway URL and token from config
GATEWAY_PORT=$(python3 -c "import json; c=json.load(open('$HOME/.openclaw/openclaw.json')); print(c.get('gateway',{}).get('port',18789))" 2>/dev/null || echo "18789")
GATEWAY_TOKEN=$(python3 -c "import json; c=json.load(open('$HOME/.openclaw/openclaw.json')); print(c['gateway']['auth']['token'])" 2>/dev/null || echo "")

API_BASE="http://127.0.0.1:${GATEWAY_PORT}/api"

if [ -z "$GATEWAY_TOKEN" ]; then
  echo "❌ Could not read gateway token from config"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $GATEWAY_TOKEN"

# Function to add a cron job via API
add_cron() {
  local name="$1"
  local expr="$2"
  local message="$3"
  
  echo "  Adding: $name ..."
  
  # Escape the message for JSON
  local escaped_message=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$message")
  
  curl -s -X POST "$API_BASE/cron/jobs" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{
      \"job\": {
        \"name\": \"$name\",
        \"schedule\": {
          \"kind\": \"cron\",
          \"expr\": \"$expr\",
          \"tz\": \"$TIMEZONE\"
        },
        \"payload\": {
          \"kind\": \"agentTurn\",
          \"message\": $escaped_message,
          \"model\": \"$MODEL\"
        },
        \"sessionTarget\": \"isolated\",
        \"enabled\": true
      }
    }" | python3 -c "
import sys,json
try:
  r=json.load(sys.stdin)
  if r.get('ok'):
    print('    ✅ Created: ' + r.get('jobId',''))
  else:
    print('    ❌ Error: ' + str(r.get('error','')))
except:
  print('    ❌ Failed to parse response')
"
}

echo "📦 Adding cron jobs..."
echo ""

# Layer 1: Daily Sync (every night at 11 PM)
add_cron "Memory: Daily Sync (11 PM)" "0 23 * * *" "$DAILY_PROMPT"

# Layer 2: Weekly Compound (Sunday 10 PM)
add_cron "Memory: Weekly Compound (Sunday 10 PM)" "0 22 * * 0" "$WEEKLY_PROMPT"

# Layer 3: Micro-Sync (every 3 hours during day)
add_cron "Memory: Micro-Sync (Every 3h)" "0 10,13,16,19,22 * * *" "$MICRO_PROMPT"

echo ""
echo "✅ All done! Three memory sync cron jobs have been added."
echo ""
echo "📋 Recommended: Add this to your AGENTS.md:"
echo ""
echo '## Memory Retrieval (MANDATORY)'
echo 'Never read MEMORY.md or memory/*.md in full for lookups. Use memory_search/qmd:'
echo '1. memory_search("<question>") — semantic search'
echo '2. memory_get(<file>, from=<line>, lines=20) — pull only needed snippet'
echo '3. Only if search returns nothing: fall back to reading files'
echo ''
echo "💡 Verify with: openclaw cron list"

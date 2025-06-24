#!/bin/bash

# 📊 CHECK AUTO-SYNC STATUS AND LOGS
# Use this to monitor your scheduled auto-sync

echo "📊 AUTO-SYNC STATUS CHECK"
echo "========================"

# Check if cron job is installed
echo "🔍 Checking cron job status..."
if crontab -l | grep -q "auto_sync_cron.sh"; then
  echo "✅ Cron job is installed and active"
  echo "   Schedule: Every hour at minute 0"
  next_hour=$(date -v+1H '+%Y-%m-%d %H:00:00')
  echo "   Next run: $next_hour"
else
  echo "❌ Cron job is NOT installed"
  echo "   Run: crontab crontab_entry.txt"
fi

echo ""

# Check log file
LOG_FILE="/Users/julius/Desktop/App new/Landing Page/auto_sync.log"
if [ -f "$LOG_FILE" ]; then
  echo "📋 Recent auto-sync logs (last 10 entries):"
  echo "----------------------------------------"
  tail -n 10 "$LOG_FILE"
  echo ""
  echo "📈 Log summary:"
  echo "   Total runs: $(grep -c "Starting scheduled payment method sync" "$LOG_FILE")"
  echo "   Successful runs: $(grep -c "Scheduled auto-sync completed successfully" "$LOG_FILE")"
  echo "   Failed runs: $(grep -c "Scheduled auto-sync failed" "$LOG_FILE")"
  echo "   Orders synced today: $(grep "$(date '+%Y-%m-%d')" "$LOG_FILE" | grep -o "Successfully synced [0-9]* orders" | grep -o "[0-9]*" | awk '{sum += $1} END {print sum+0}')"
else
  echo "📋 No log file found yet"
  echo "   The script hasn't run yet or logs haven't been created"
fi

echo ""
echo "💡 Commands:"
echo "   View full logs: cat auto_sync.log"
echo "   Test manually: ./auto_sync_cron.sh"
echo "   Edit cron job: crontab -e"
echo "   Remove cron job: crontab -r" 
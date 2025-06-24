#!/bin/bash

# 🔄 AUTO-SYNC RECENT ORDERS - CRON VERSION
# This version is optimized for running via cron with proper logging

# Set up environment
export PATH="/usr/local/bin:/usr/bin:/bin"
SCRIPT_DIR="/Users/julius/Desktop/App new/Landing Page"
LOG_FILE="$SCRIPT_DIR/auto_sync.log"

# Function to log with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🔄 AUTO-SYNC: Starting scheduled payment method sync..."

SUPABASE_URL="https://juwurgxmwltebeuqindt.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1d3VyZ3htd2x0ZWJldXFpbmR0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODk0NTQ4OCwiZXhwIjoyMDY0NTIxNDg4fQ.nj1ABY1MwJuvHO87Mq7HAcNeSM40MoQr4929Nr2zNsE"

# Function to call the auto-sync function
call_auto_sync() {
  log "📞 Calling auto-sync function..."
  
  response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    "$SUPABASE_URL/functions/v1/auto-sync-payment-methods")
  
  http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')
  
  if [ "$http_code" -eq 200 ]; then
    log "✅ AUTO-SYNC SUCCESS"
    
    # Parse key info from response
    orders_checked=$(echo "$body" | grep -o '"orders_checked":[0-9]*' | cut -d':' -f2)
    orders_synced=$(echo "$body" | grep -o '"orders_synced":[0-9]*' | cut -d':' -f2)
    success_rate=$(echo "$body" | grep -o '"success_rate":"[^"]*"' | cut -d'"' -f4)
    
    log "📊 Orders checked: $orders_checked"
    log "📊 Orders synced: $orders_synced"
    log "📊 Success rate: $success_rate"
    
    if [ "$orders_synced" -gt 0 ]; then
      log "🎉 Successfully synced $orders_synced orders with real payment method data!"
      
      # Send notification (optional - you can enable this)
      # osascript -e 'display notification "Synced '$orders_synced' payment methods" with title "Auto-Sync Complete"'
    else
      log "✨ No orders needed syncing - all recent orders already have real payment data"
    fi
    
    return 0
    
  else
    log "❌ AUTO-SYNC FAILED"
    log "   HTTP $http_code: $body"
    
    # Send error notification (optional - you can enable this)
    # osascript -e 'display notification "Auto-sync failed: HTTP '$http_code'" with title "Auto-Sync Error"'
    
    return 1
  fi
}

# Run the auto-sync
if call_auto_sync; then
  log "✅ Scheduled auto-sync completed successfully"
else
  log "❌ Scheduled auto-sync failed"
  exit 1
fi

# Clean up old log entries (keep last 100 lines)
if [ -f "$LOG_FILE" ]; then
  tail -n 100 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

log "🔄 AUTO-SYNC: Scheduled run complete" 
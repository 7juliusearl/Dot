#!/bin/bash

# 🔄 AUTO-SYNC RECENT ORDERS WITH PLACEHOLDER PAYMENT METHOD DATA
# Run this periodically (e.g., every hour) to catch any orders that didn't get real card data

echo "🔄 AUTO-SYNC: Checking for recent orders with placeholder payment method data..."

SUPABASE_URL="https://juwurgxmwltebeuqindt.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1d3VyZ3htd2x0ZWJldXFpbmR0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODk0NTQ4OCwiZXhwIjoyMDY0NTIxNDg4fQ.nj1ABY1MwJuvHO87Mq7HAcNeSM40MoQr4929Nr2zNsE"

# Function to call the auto-sync function
call_auto_sync() {
  echo "📞 Calling auto-sync function..."
  
  response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    "$SUPABASE_URL/functions/v1/auto-sync-payment-methods")
  
  http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')
  
  if [ "$http_code" -eq 200 ]; then
    echo "✅ AUTO-SYNC SUCCESS"
    
    # Parse key info from response
    orders_checked=$(echo "$body" | grep -o '"orders_checked":[0-9]*' | cut -d':' -f2)
    orders_synced=$(echo "$body" | grep -o '"orders_synced":[0-9]*' | cut -d':' -f2)
    success_rate=$(echo "$body" | grep -o '"success_rate":"[^"]*"' | cut -d'"' -f4)
    
    echo "📊 Orders checked: $orders_checked"
    echo "📊 Orders synced: $orders_synced"
    echo "📊 Success rate: $success_rate"
    
    if [ "$orders_synced" -gt 0 ]; then
      echo "🎉 Successfully synced $orders_synced orders with real payment method data!"
    else
      echo "✨ No orders needed syncing - all recent orders already have real payment data"
    fi
    
  else
    echo "❌ AUTO-SYNC FAILED"
    echo "   HTTP $http_code: $body"
    return 1
  fi
}

# Run the auto-sync
call_auto_sync

echo ""
echo "💡 TIP: You can add this script to a cron job to run automatically:"
echo "   # Run every hour"
echo "   0 * * * * /path/to/auto_sync_recent_orders.sh"
echo ""
echo "💡 Or run it manually whenever you notice a new purchase with placeholder data" 
#!/bin/bash

# 🔄 SYNC MOST RECENT PURCHASE
# This will sync payment method data for the most recent purchase

echo "🔍 Checking most recent purchases for missing payment method data..."

SUPABASE_URL="https://juwurgxmwltebeuqindt.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1d3VyZ3htd2x0ZWJldXFpbmR0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODk0NTQ4OCwiZXhwIjoyMDY0NTIxNDg4fQ.nj1ABY1MwJuvHO87Mq7HAcNeSM40MoQr4929Nr2zNsE"

# Function to sync a customer
sync_customer() {
  local customer_id=$1
  local email=$2
  
  echo "🔄 Syncing customer: $customer_id ($email)"
  
  response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"action\": \"sync_single_customer\", \"customer_id\": \"$customer_id\"}" \
    "$SUPABASE_URL/functions/v1/sync-payment-methods")
  
  http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')
  
  if [ "$http_code" -eq 200 ]; then
    echo "✅ SUCCESS: $customer_id"
    # Parse the response to show key info
    if echo "$body" | grep -q '"has_real_data":true'; then
      brand=$(echo "$body" | grep -o '"payment_method_brand":"[^"]*"' | cut -d'"' -f4)
      last4=$(echo "$body" | grep -o '"payment_method_last4":"[^"]*"' | cut -d'"' -f4)
      echo "   📊 Real card data found: $brand ending in $last4"
    else
      echo "   📋 Clean placeholder data (****) - no real card data available"
    fi
  else
    echo "❌ FAILED: $customer_id"
    echo "   HTTP $http_code: $body"
  fi
}

# Get the most recent purchases that might need syncing
echo "📋 If you know the customer ID from the recent purchase, enter it below:"
echo "   Or press Enter to sync some common recent customers"
read -p "Customer ID (or press Enter): " customer_id

if [ -n "$customer_id" ]; then
  # Sync the specific customer
  sync_customer "$customer_id" "recent purchase"
else
  echo "💡 To find the recent customer ID, run check_recent_purchase.sql"
  echo "💡 Or check your Stripe dashboard for the most recent payment"
  echo ""
  echo "🔄 You can also run the full batch sync script if needed:"
  echo "   ./batch_sync_curl_fixed.sh"
fi 
#!/bin/bash

# 🔄 BATCH PAYMENT METHOD SYNC - CURL VERSION
# This uses your service role key directly

echo "🚀 Starting batch payment method sync via curl..."

SUPABASE_URL="https://juwurgxmwltebeuqindt.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1d3VyZ3htd2x0ZWJldXFpbmR0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczMzEzMzk2MCwiZXhwIjoyMDQ4NzA5OTYwfQ.gNKBvw_Z6-JpapkF5M_VRXeJz5WNWFKQ4wfJP8V8QP8"

CUSTOMER_IDS=(
  "cus_SYTcC4irOkLilX"  # sarahdeloachphotography@gmail.com
  "cus_SYOlI54YnfORSB"  # ambergcphotos@gmail.com  
  "cus_SYOpAgoMKUl6jA"  # nic.dampier@gmail.com
  "cus_SYNoUuO1DZfCkx"  # lunuphotography@gmail.com
  "cus_SYLdNppx7h9O0g"  # madisonhernandezphotography@gmail.com
  "cus_SYL3wPUyfhaAMJ"  # sammy@scoylephoto.com
  "cus_SYKpQEtSq8KAnO"  # lkdanielphotography@gmail.com
  "cus_SYIqIrOdyoDljg"  # christa@christaandcophoto.com
  "cus_SYHXPA4yxz6cde"  # kendrickjlittle1@gmail.com
  "cus_SYFSaOLJ3AFVRl"  # contact@emerlinphotography.com
)

success_count=0
fail_count=0

for i in "${!CUSTOMER_IDS[@]}"; do
  customer_id="${CUSTOMER_IDS[$i]}"
  echo "Syncing $((i+1))/10: $customer_id"
  
  response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"action\": \"sync_single_customer\", \"customer_id\": \"$customer_id\"}" \
    "$SUPABASE_URL/functions/v1/sync-payment-methods")
  
  http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')
  
  if [ "$http_code" -eq 200 ]; then
    echo "✅ $((i+1))/10 completed: $customer_id"
    echo "   Response: $body"
    ((success_count++))
  else
    echo "❌ $((i+1))/10 failed: $customer_id"
    echo "   HTTP $http_code: $body"
    ((fail_count++))
  fi
  
  # Add delay between requests (except for last one)
  if [ $((i+1)) -lt ${#CUSTOMER_IDS[@]} ]; then
    echo "   Waiting 2 seconds..."
    sleep 2
  fi
done

echo ""
echo "🎯 BATCH SYNC COMPLETE!"
echo "✅ Successful: $success_count/${#CUSTOMER_IDS[@]}"
echo "❌ Failed: $fail_count/${#CUSTOMER_IDS[@]}"
success_rate=$(( success_count * 100 / ${#CUSTOMER_IDS[@]} ))
echo "📊 Success Rate: $success_rate%"
echo ""
echo "Next step: Run check_payment_method_results.sql to verify the updates" 
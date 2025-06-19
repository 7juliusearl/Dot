#!/bin/bash

# Deploy and Run Payment Method Sync for Existing Users
echo "🚀 Deploying payment method sync function..."

# Deploy the function
supabase functions deploy sync-payment-methods

if [ $? -eq 0 ]; then
    echo "✅ Function deployed successfully!"
    echo ""
    echo "🔄 Running payment method sync for all 87 users..."
    echo "This will fetch real card digits from Stripe for existing users."
    echo ""
    
    # Run the function
    curl -X POST \
      "$(supabase status | grep 'API URL' | awk '{print $3}')/functions/v1/sync-payment-methods" \
      -H "Authorization: Bearer $(supabase status | grep 'anon key' | awk '{print $3}')" \
      -H "Content-Type: application/json" \
      -d '{}'
    
    echo ""
    echo ""
    echo "✅ Payment method sync completed!"
    echo ""
    echo "📊 To check the results, run this SQL query:"
    echo "SELECT * FROM payment_method_quality_monitor;"
    echo ""
    echo "📋 To see sync logs:"
    echo "SELECT * FROM sync_logs WHERE operation = 'payment_method_sync_from_stripe' ORDER BY created_at DESC LIMIT 20;"
else
    echo "❌ Failed to deploy function. Please check your Supabase setup."
    exit 1
fi 
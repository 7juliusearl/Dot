# Manual Payment Method Sync Instructions

## Option 1: Automated Sync (Recommended)

Run the automated sync function:

```bash
./deploy_and_run_payment_sync.sh
```

This will:
1. Deploy the Supabase Edge Function
2. Fetch real payment method data from Stripe for all 87 users
3. Update your database with actual card digits
4. Provide detailed logging and results

## Option 2: Manual Sync (If automated fails)

If the automated approach doesn't work, you can manually sync specific users:

### Step 1: Get users needing sync
```sql
SELECT customer_id, email, payment_intent_id 
FROM users_needing_stripe_sync 
LIMIT 10;
```

### Step 2: For each user, use the manual update function
```sql
-- Example: Update a specific user with real card data
SELECT update_payment_method_data('cus_customer_id', 'visa', '4242');
```

### Step 3: Check progress
```sql
SELECT * FROM payment_method_quality_monitor;
```

## Option 3: Webhook-based Gradual Sync

Update your existing webhook handlers with the improved payment method capture logic from `improved_webhook_payment_method_capture.ts`. This will gradually fix users as they interact with your system.

## Monitoring Progress

### Check overall quality:
```sql
SELECT * FROM payment_method_quality_monitor;
```

### View sync logs:
```sql
SELECT * FROM sync_logs 
WHERE operation = 'payment_method_sync_from_stripe' 
ORDER BY created_at DESC 
LIMIT 20;
```

### Count remaining users needing sync:
```sql
SELECT COUNT(*) as users_still_needing_sync 
FROM users_needing_stripe_sync;
```

## Expected Results

After running the sync:
- **Before**: 87 users with '****' placeholder data
- **After**: Most users should have real 4-digit card numbers like '4242', '1234', etc.
- **Success Rate**: Expect 70-90% success rate (some users may not have accessible payment methods in Stripe)

## Troubleshooting

If sync fails for some users:
1. Check if they have active subscriptions in Stripe
2. Verify payment intents are still accessible
3. Some very old payment methods may no longer be retrievable from Stripe
4. Users who paid with non-card methods won't have card digits

## Next Steps

1. Run the sync
2. Monitor the results
3. Update your webhook handlers to prevent future fake data
4. Set up regular monitoring of payment method data quality 
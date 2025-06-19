# Run Payment Method Sync via Supabase Dashboard

Since you don't have the Supabase CLI installed, here's how to run the payment method sync through your Supabase dashboard:

## 🎯 **Method 1: Deploy via Supabase Dashboard**

1. **Go to your Supabase Dashboard** → Your Project → Edge Functions

2. **Create a new function called `sync-payment-methods`**

3. **Copy the code** from `supabase/functions/sync-payment-methods/index.ts` into the function editor

4. **Deploy the function**

5. **Run the function** by making a POST request to:
   ```
   https://YOUR_PROJECT_ID.supabase.co/functions/v1/sync-payment-methods
   ```

## 🎯 **Method 2: Direct SQL Approach (Simpler)**

If the Edge Function approach is too complex, you can run this SQL script directly in your Supabase SQL editor:

```sql
-- This will show you a sample of users that need syncing
SELECT 
  'Users needing payment method sync:' as info,
  customer_id,
  email,
  payment_intent_id,
  purchase_type
FROM users_needing_stripe_sync 
LIMIT 10;

-- You can then manually update specific users if you have their real card data
-- Example (replace with real data):
-- SELECT update_payment_method_data('cus_example123', 'visa', '4242');
```

## 🎯 **Method 3: Install Supabase CLI (Recommended for future)**

If you want to install the Supabase CLI for future use:

### Install Homebrew first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Then install Supabase CLI:
```bash
brew install supabase/tap/supabase
```

### Then you can run:
```bash
./deploy_and_run_payment_sync.sh
```

## 🔍 **Quick Check: What's the Current Status?**

Run this in your Supabase SQL editor to see the current state:

```sql
SELECT * FROM payment_method_quality_monitor;
```

This will show you:
- Total active orders
- How many have real card data vs placeholders
- Quality percentage

## 📞 **Need Help?**

If you're not sure how to proceed, let me know which method you'd prefer:
1. Dashboard Edge Function deployment
2. Manual SQL updates
3. Installing CLI tools first

I can guide you through whichever approach you're most comfortable with! 
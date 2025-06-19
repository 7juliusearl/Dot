# 🚀 Exact Deployment Instructions

## Step 1: Deploy stripe-webhook-complete

1. **Go to:** Supabase Dashboard → Your Project → Edge Functions
2. **Click:** `stripe-webhook-complete` function
3. **Replace ALL code** with this:

```typescript
// Copy the ENTIRE contents of: supabase/functions/stripe-webhook-complete/index.ts
// (The file has been updated with improved payment method capture)
```

4. **Click:** Deploy

## Step 2: Deploy stripe-webhook

1. **In same dashboard:** Edge Functions
2. **Click:** `stripe-webhook` function  
3. **Replace ALL code** with this:

```typescript
// Copy the ENTIRE contents of: supabase/functions/stripe-webhook/index.ts
// (The file has been updated with improved payment method capture)
```

4. **Click:** Deploy

## Step 3: Test

1. **Make a test payment**
2. **Check function logs** for: `✅ FINAL SUCCESS: Real payment method captured`
3. **Run this SQL:**

```sql
SELECT 
  email,
  payment_method_last4,
  CASE 
    WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN '✅ Real card data'
    ELSE '❌ Problem!'
  END as status
FROM stripe_orders 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
```

## ✅ Success Indicators:
- Function logs show: `✅ FINAL SUCCESS: Real payment method captured: visa ending in 4242`
- Database shows real 4-digit card numbers like `'4242'`, `'1234'`
- NO fake data like `'cac6'`, `'37d8'`

## 🚨 If Problems:
- Check function logs for error messages
- Verify STRIPE_SECRET_KEY environment variable
- Test with Stripe test mode first 
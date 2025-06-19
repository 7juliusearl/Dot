# Manual Fix for Ali @mossandelder.com

## Quick Fix via Supabase Dashboard

1. Go to Supabase Dashboard: https://supabase.com/dashboard/project/juwurgxmwltebeuqindt/editor
2. Open SQL Editor 
3. Run this exact SQL:

```sql
INSERT INTO stripe_orders (
  checkout_session_id,
  payment_intent_id,
  customer_id,
  amount_subtotal,
  amount_total,
  currency,
  payment_status,
  status,
  purchase_type,
  email
) VALUES (
  'cs_live_b1JIr1pgimXLuTfpSCl99h6DFTjsJprRuQTe0CS6qjX5KsQW425tSP8ASZ',
  'pi_3RWWnQInTpoMSXou2g80Ymke',
  'cus_SRPbc4DEJouCjg',
  399,
  399,
  'usd',
  'paid',
  'completed',
  'monthly',
  'ali@mossandelder.com'
);
```

This will create the missing order record and allow Ali to access her subscription.

## Alternative: Use your app's admin panel to manually add the order with these details:
- Email: ali@mossandelder.com
- Customer ID: cus_SRPbc4DEJouCjg
- Amount: $3.99
- Status: completed
- Type: monthly 
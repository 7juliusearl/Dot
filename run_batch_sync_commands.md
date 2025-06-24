# 🔄 BATCH PAYMENT METHOD SYNC COMMANDS

## Run these commands one by one in your Supabase Dashboard

Go to: https://supabase.com/dashboard/project/juwurgxmwltebeuqindt/functions/sync-payment-methods

**Click "Invoke Function" and paste each payload:**

### 1. Sarah (sarahdeloachphotography@gmail.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYTcC4irOkLilX"}
```

### 2. Amber (ambergcphotos@gmail.com)  
```json
{"action": "sync_single_customer", "customer_id": "cus_SYOlI54YnfORSB"}
```

### 3. Nic (nic.dampier@gmail.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYOpAgoMKUl6jA"}
```

### 4. Lunu Photography (lunuphotography@gmail.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYNoUuO1DZfCkx"}
```

### 5. Madison (madisonhernandezphotography@gmail.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYLdNppx7h9O0g"}
```

### 6. Sammy (sammy@scoylephoto.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYL3wPUyfhaAMJ"}
```

### 7. LK Daniel Photography (lkdanielphotography@gmail.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYKpQEtSq8KAnO"}
```

### 8. Christa (christa@christaandcophoto.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYIqIrOdyoDljg"}
```

### 9. Kendrick (kendrickjlittle1@gmail.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYHXPA4yxz6cde"}
```

### 10. Emerlin Photography (contact@emerlinphotography.com)
```json
{"action": "sync_single_customer", "customer_id": "cus_SYFSaOLJ3AFVRl"}
```

## ✅ Expected Results:

After each sync, you should see a response like:
```json
{
  "customer_id": "cus_...",
  "success": true,
  "payment_method_brand": "visa",
  "payment_method_last4": "4242",
  "has_real_data": true
}
```

## 🔍 Check Results:

After running all 10 syncs, run the `check_payment_method_results.sql` script again to verify all customers now show real card digits instead of ****.

## 📊 Success Metrics:

- **Before**: 10 customers with `****` placeholders
- **Target**: 10 customers with real card digits like `1234`, `5678`, etc.
- **Brands**: Should show `visa`, `mastercard`, `amex`, etc. instead of `card` 
# NEW PRICING STRUCTURE - WEBHOOK UPDATES

## Updated Pricing Logic (Effective Immediately)

**NEW PRICING STRUCTURE:**
- **$99.00** (9900 cents) = `lifetime`
- **$27.99** (2799 cents) = `yearly` 
- **$3.99** (399 cents) = `monthly`

## Files Updated

### 1. IMPROVED_WEBHOOK_HANDLER.ts
- ✅ Updated `detectPurchaseType()` function
- ✅ Changed from `amount_total > 1000` to `amount_total >= 9900` for lifetime
- ✅ Changed from `amount_total >= 2700` to `amount_total === 2799` for yearly

### 2. supabase/functions/stripe-webhook-public/index.ts  
- ✅ Updated purchase type detection logic
- ✅ Lifetime: `amount_total >= 9900` (was `> 1000`)
- ✅ Yearly: `amount_total === 2799` (was `>= 2700`)

### 3. supabase/functions/stripe-webhook-complete/index.ts
- ✅ Updated purchase type detection logic  
- ✅ Lifetime: `amount_total >= 9900` (was payment mode check)
- ✅ Yearly: `amount_total === 2799` (was `>= 2700`)

### 4. netlify/functions/stripe-webhook-complete.mts
- ✅ Updated purchase type detection logic
- ✅ Lifetime: `amount_total >= 9900` (was `> 1000`) 
- ✅ Yearly: `amount_total === 2799` (was `>= 2700`)

## Key Changes Made

1. **Lifetime Detection**: Changed from checking `amount_total > 1000` to `amount_total >= 9900`
2. **Yearly Detection**: Changed from checking `amount_total >= 2700` to `amount_total === 2799`
3. **Price ID Fallbacks**: Maintained existing price ID checks as secondary validation
4. **Comments Added**: Clear documentation of new pricing structure in code

## Result

✅ **All new orders will now be correctly categorized:**
- $99.00 payments → `lifetime`
- $27.99 payments → `yearly`  
- $3.99 payments → `monthly`

## Historical Data Fix

✅ **Historical batch fixed separately:**
- Orders 82-154 with $27.99 updated from `monthly` to `lifetime` (per user request)
- This was a one-time historical correction, separate from the new pricing logic

## Deployment Required

⚠️ **Action Required:** Deploy the updated webhook functions to production:
- Supabase Edge Functions need redeployment
- Netlify Functions will auto-deploy on next push

---
**Status**: ✅ Webhook logic updated for new pricing structure
**Date**: January 2025
**Testing**: New orders should now categorize correctly based on amount 
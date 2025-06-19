-- First, let's see what enum values exist
SELECT 
    enumlabel 
FROM pg_enum 
WHERE enumtypid = (
    SELECT oid 
    FROM pg_type 
    WHERE typname = 'stripe_order_status'
);

-- Let's see an example order to copy the pattern
SELECT * FROM stripe_orders LIMIT 1;

-- Now create Ali's order using a working status value
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
    'processing',  -- Use a safe enum value
    'monthly',
    'ali@mossandelder.com'
); 
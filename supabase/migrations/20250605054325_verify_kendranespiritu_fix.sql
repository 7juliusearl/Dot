-- Verify the fix for kendranespiritu@gmail.com and troubleshoot why dashboard still not working

SELECT '=== CURRENT STATE VERIFICATION ===' as info;

-- Check if user exists
SELECT 'USER EXISTS:' as check, 
       COUNT(*) as count, 
       id as user_id
FROM auth.users 
WHERE email = 'kendranespiritu@gmail.com'
GROUP BY id;

-- Check customer records
SELECT 'CUSTOMER RECORDS:' as check,
       COUNT(*) as count,
       user_id,
       customer_id,
       email,
       payment_type,
       deleted_at
FROM stripe_customers 
WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
   OR email = 'kendranespiritu@gmail.com'
GROUP BY user_id, customer_id, email, payment_type, deleted_at;

-- Check completed orders (this is what dashboard looks for)
SELECT 'COMPLETED ORDERS:' as check,
       COUNT(*) as count,
       customer_id,
       status,
       purchase_type,
       email,
       payment_intent_id,
       created_at,
       deleted_at
FROM stripe_orders 
WHERE email = 'kendranespiritu@gmail.com'
   OR customer_id IN (
     SELECT customer_id FROM stripe_customers 
     WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
   )
GROUP BY customer_id, status, purchase_type, email, payment_intent_id, created_at, deleted_at
ORDER BY created_at DESC;

-- Simulate the EXACT dashboard query to see what it returns
SELECT 'DASHBOARD SIMULATION:' as check;

WITH user_orders AS (
  SELECT so.*
  FROM stripe_orders so
  JOIN stripe_customers sc ON so.customer_id = sc.customer_id
  WHERE sc.user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
    AND sc.deleted_at IS NULL
  ORDER BY so.created_at DESC
  LIMIT 1
)
SELECT 
  CASE WHEN COUNT(*) > 0 THEN 'FOUND ORDER - DASHBOARD SHOULD WORK' ELSE 'NO ORDER FOUND - DASHBOARD WILL SHOW NO SUBSCRIPTION' END as result,
  COUNT(*) as order_count,
  MAX(customer_id) as customer_id,
  MAX(purchase_type) as purchase_type,
  MAX(status) as status
FROM user_orders;

-- Check recent logs to see if order was created
SELECT 'RECENT LOGS:' as check,
       operation,
       status,
       details->>'user_email' as email,
       details->>'reason' as reason,
       created_at
FROM sync_logs 
WHERE details->>'user_email' = 'kendranespiritu@gmail.com'
   OR operation LIKE '%kendranespiritu%'
   OR operation = 'create_missing_order'
ORDER BY created_at DESC
LIMIT 5;

-- If no order found, let's force create one with direct approach
DO $$
DECLARE
    user_rec RECORD;
    customer_rec RECORD;
BEGIN
    -- Get user and customer info
    SELECT * INTO user_rec FROM auth.users WHERE email = 'kendranespiritu@gmail.com';
    
    IF user_rec.id IS NOT NULL THEN
        SELECT * INTO customer_rec FROM stripe_customers 
        WHERE user_id = user_rec.id AND deleted_at IS NULL;
        
        IF customer_rec.customer_id IS NOT NULL THEN
            -- Check if order already exists
            IF NOT EXISTS (
                SELECT 1 FROM stripe_orders 
                WHERE customer_id = customer_rec.customer_id 
                AND status = 'completed' 
                AND deleted_at IS NULL
            ) THEN
                -- Force create the order
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
                    email,
                    created_at,
                    updated_at
                ) VALUES (
                    'cs_force_' || customer_rec.customer_id,
                    'pi_force_' || customer_rec.customer_id,
                    customer_rec.customer_id,
                    399,
                    399,
                    'usd',
                    'paid',
                    'completed',
                    'monthly',
                    'kendranespiritu@gmail.com',
                    NOW(),
                    NOW()
                );
                
                RAISE NOTICE 'FORCE CREATED ORDER FOR CUSTOMER %', customer_rec.customer_id;
            ELSE
                RAISE NOTICE 'ORDER ALREADY EXISTS FOR CUSTOMER %', customer_rec.customer_id;
            END IF;
        ELSE
            RAISE NOTICE 'NO CUSTOMER RECORD FOUND FOR USER %', user_rec.email;
        END IF;
    ELSE
        RAISE NOTICE 'USER NOT FOUND: kendranespiritu@gmail.com';
    END IF;
END $$;

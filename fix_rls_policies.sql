-- Fix RLS policies to allow users to see their own subscription data

-- 1. First check current RLS policies
SELECT 'CURRENT RLS POLICIES:' as info;
SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies 
WHERE tablename IN ('stripe_orders', 'stripe_customers')
ORDER BY tablename, policyname;

-- 2. Check if RLS is enabled on the tables
SELECT 'RLS STATUS:' as info;
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('stripe_orders', 'stripe_customers');

-- 3. Create or update RLS policy for stripe_customers (users can see their own customer record)
DROP POLICY IF EXISTS "Users can view their own customer data" ON stripe_customers;
CREATE POLICY "Users can view their own customer data" 
ON stripe_customers FOR SELECT 
USING (auth.uid() = user_id);

-- 4. Create or update RLS policy for stripe_orders (users can see orders for their customer_id)
DROP POLICY IF EXISTS "Users can view their own orders" ON stripe_orders;
CREATE POLICY "Users can view their own orders" 
ON stripe_orders FOR SELECT 
USING (
  customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE user_id = auth.uid()
  )
);

-- 5. Test the policies work by checking as authenticated user
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "beef2e59-1cdf-408a-a2f2-c56e07a723bc"}';

SELECT 'TEST: User can see their customer record:' as info;
SELECT customer_id, user_id, email 
FROM stripe_customers 
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

SELECT 'TEST: User can see their orders:' as info;
SELECT id, customer_id, payment_intent_id, amount_total, status, purchase_type
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

-- Reset
RESET ROLE;
RESET request.jwt.claims;

-- 6. Final verification - show updated policies
SELECT 'UPDATED RLS POLICIES:' as info;
SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies 
WHERE tablename IN ('stripe_orders', 'stripe_customers')
ORDER BY tablename, policyname; 
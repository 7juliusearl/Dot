-- Fix specific batch: Change $27.99 orders from 'monthly' to 'lifetime'
-- Based on stripe_orders_rows (1).sql data

UPDATE stripe_orders 
SET purchase_type = 'lifetime'
WHERE amount_total = 2799 
  AND purchase_type = 'monthly'
  AND id IN (
    82, 83, 85, 86, 87, 88, 89, 90, 91, 93, 94, 95, 96, 97, 98, 99, 
    100, 101, 102, 104, 105, 106, 107, 109, 110, 111, 112, 113, 114, 
    115, 116, 117, 119, 121, 122, 123, 125, 126, 128, 130, 131, 132, 
    133, 134, 135, 137, 138, 139, 141, 142, 143, 146, 147, 148, 149, 
    150, 152, 153
  );

-- Verify the changes
SELECT id, amount_total, purchase_type, email 
FROM stripe_orders 
WHERE id IN (
    82, 83, 85, 86, 87, 88, 89, 90, 91, 93, 94, 95, 96, 97, 98, 99, 
    100, 101, 102, 104, 105, 106, 107, 109, 110, 111, 112, 113, 114, 
    115, 116, 117, 119, 121, 122, 123, 125, 126, 128, 130, 131, 132, 
    133, 134, 135, 137, 138, 139, 141, 142, 143, 146, 147, 148, 149, 
    150, 152, 153
)
ORDER BY id; 
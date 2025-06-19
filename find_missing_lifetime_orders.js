// Script to find missing lifetime orders in Stripe
// Run this in Node.js with: node find_missing_lifetime_orders.js

import Stripe from 'stripe';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

async function findLifetimeOrders() {
  console.log('🔍 Searching for lifetime orders in Stripe...\n');
  
  try {
    // Search for recent checkout sessions
    const sessions = await stripe.checkout.sessions.list({
      limit: 100,
      expand: ['data.line_items']
    });
    
    console.log(`Found ${sessions.data.length} recent checkout sessions\n`);
    
    const lifetimeOrders = [];
    
    for (const session of sessions.data) {
      // Look for sessions with higher amounts (likely lifetime)
      if (session.amount_total > 1000) { // More than $10
        const customerEmail = session.customer_details?.email || session.customer_email;
        
        lifetimeOrders.push({
          sessionId: session.id,
          customerId: session.customer,
          email: customerEmail,
          amountTotal: session.amount_total,
          amountDollars: (session.amount_total / 100).toFixed(2),
          paymentStatus: session.payment_status,
          paymentIntent: session.payment_intent,
          created: new Date(session.created * 1000).toISOString(),
          lineItems: session.line_items?.data?.map(item => ({
            description: item.description,
            quantity: item.quantity,
            amount: item.amount_total
          }))
        });
      }
    }
    
    console.log(`🎯 Found ${lifetimeOrders.length} potential lifetime orders:\n`);
    
    lifetimeOrders.forEach((order, index) => {
      console.log(`${index + 1}. ${order.email || 'No email'}`);
      console.log(`   Amount: $${order.amountDollars}`);
      console.log(`   Session: ${order.sessionId}`);
      console.log(`   Date: ${order.created}`);
      console.log(`   Status: ${order.paymentStatus}`);
      if (order.lineItems?.length) {
        console.log(`   Items: ${order.lineItems.map(item => item.description).join(', ')}`);
      }
      console.log('');
    });
    
    // Generate SQL to insert missing orders
    if (lifetimeOrders.length > 0) {
      console.log('\n📝 SQL to add missing lifetime orders:');
      console.log('-- Run this in Supabase SQL Editor to add missing lifetime customers\n');
      
      lifetimeOrders.forEach(order => {
        console.log(`INSERT INTO stripe_orders (
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
  '${order.sessionId}',
  '${order.paymentIntent || ''}',
  '${order.customerId || ''}',
  ${order.amountTotal},
  ${order.amountTotal},
  'usd',
  '${order.paymentStatus}',
  'completed',
  'lifetime',
  '${order.email || ''}'
);`);
        console.log('');
      });
    }
    
  } catch (error) {
    console.error('Error searching Stripe:', error.message);
  }
}

// Run the search
findLifetimeOrders(); 
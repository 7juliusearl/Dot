/*
  # Improved Payment Method Capture for Webhook Handlers
  
  This is an enhanced version of the payment method capture logic
  that should be used in your webhook handlers to ensure you always
  get real card digits, never fake data.
*/

async function capturePaymentMethodDetails(
  stripe: any,
  session: any,
  customerId: string
): Promise<{ payment_method_brand: string; payment_method_last4: string }> {
  let payment_method_brand = 'card';
  let payment_method_last4 = '****';
  
  console.log(`Starting payment method capture for customer: ${customerId}`);
  console.log(`Session mode: ${session.mode}, Payment intent: ${session.payment_intent}`);

  try {
    // Method 1: For subscription checkouts, get from subscription's default payment method
    if (session.mode === 'subscription' && session.subscription) {
      console.log('Attempting to get payment method from subscription...');
      
      const subscription = await stripe.subscriptions.retrieve(session.subscription, {
        expand: ['default_payment_method']
      });
      
      const paymentMethod = subscription.default_payment_method;
      if (paymentMethod?.card) {
        payment_method_brand = paymentMethod.card.brand || 'card';
        payment_method_last4 = paymentMethod.card.last4 || '****';
        console.log(`✅ SUCCESS: Got payment method from subscription: ${payment_method_brand} ending in ${payment_method_last4}`);
        
        // Validate we got real card digits
        if (payment_method_last4.match(/^[0-9]{4}$/)) {
          return { payment_method_brand, payment_method_last4 };
        } else {
          console.warn(`⚠️ WARNING: Subscription payment method last4 is not 4 digits: ${payment_method_last4}`);
        }
      } else {
        console.log('No card data found in subscription default payment method');
      }
    }

    // Method 2: Get from payment intent (works for both subscription and one-time payments)
    if (session.payment_intent && payment_method_last4 === '****') {
      console.log('Attempting to get payment method from payment intent...');
      
      const paymentIntent = await stripe.paymentIntents.retrieve(session.payment_intent, {
        expand: ['payment_method']
      });
      
      const paymentMethod = paymentIntent.payment_method;
      if (paymentMethod?.card) {
        payment_method_brand = paymentMethod.card.brand || 'card';
        payment_method_last4 = paymentMethod.card.last4 || '****';
        console.log(`✅ SUCCESS: Got payment method from payment intent: ${payment_method_brand} ending in ${payment_method_last4}`);
        
        // Validate we got real card digits
        if (payment_method_last4.match(/^[0-9]{4}$/)) {
          return { payment_method_brand, payment_method_last4 };
        } else {
          console.warn(`⚠️ WARNING: Payment intent payment method last4 is not 4 digits: ${payment_method_last4}`);
        }
      } else {
        console.log('No card data found in payment intent payment method');
      }
    }

    // Method 3: For subscriptions, try listing customer's payment methods
    if (session.mode === 'subscription' && payment_method_last4 === '****') {
      console.log('Attempting to get payment method from customer payment methods list...');
      
      const paymentMethods = await stripe.paymentMethods.list({
        customer: customerId,
        type: 'card',
        limit: 1
      });
      
      if (paymentMethods.data.length > 0) {
        const paymentMethod = paymentMethods.data[0];
        if (paymentMethod.card) {
          payment_method_brand = paymentMethod.card.brand || 'card';
          payment_method_last4 = paymentMethod.card.last4 || '****';
          console.log(`✅ SUCCESS: Got payment method from customer payment methods: ${payment_method_brand} ending in ${payment_method_last4}`);
          
          // Validate we got real card digits
          if (payment_method_last4.match(/^[0-9]{4}$/)) {
            return { payment_method_brand, payment_method_last4 };
          } else {
            console.warn(`⚠️ WARNING: Customer payment method last4 is not 4 digits: ${payment_method_last4}`);
          }
        }
      } else {
        console.log('No payment methods found for customer');
      }
    }

    // Method 4: Try to get from setup intent if available
    if (session.setup_intent && payment_method_last4 === '****') {
      console.log('Attempting to get payment method from setup intent...');
      
      const setupIntent = await stripe.setupIntents.retrieve(session.setup_intent, {
        expand: ['payment_method']
      });
      
      const paymentMethod = setupIntent.payment_method;
      if (paymentMethod?.card) {
        payment_method_brand = paymentMethod.card.brand || 'card';
        payment_method_last4 = paymentMethod.card.last4 || '****';
        console.log(`✅ SUCCESS: Got payment method from setup intent: ${payment_method_brand} ending in ${payment_method_last4}`);
        
        // Validate we got real card digits
        if (payment_method_last4.match(/^[0-9]{4}$/)) {
          return { payment_method_brand, payment_method_last4 };
        } else {
          console.warn(`⚠️ WARNING: Setup intent payment method last4 is not 4 digits: ${payment_method_last4}`);
        }
      }
    }

  } catch (error) {
    console.error('❌ ERROR: Failed to capture payment method details:', error);
  }

  // Final validation and logging
  if (payment_method_last4 === '****') {
    console.warn(`⚠️ WARNING: Could not capture real payment method data for customer ${customerId}. Using placeholder.`);
  } else if (!payment_method_last4.match(/^[0-9]{4}$/)) {
    console.error(`❌ ERROR: Captured invalid payment method last4: ${payment_method_last4}. Resetting to placeholder.`);
    payment_method_last4 = '****';
    payment_method_brand = 'card';
  } else {
    console.log(`✅ FINAL SUCCESS: Real payment method captured: ${payment_method_brand} ending in ${payment_method_last4}`);
  }

  return { payment_method_brand, payment_method_last4 };
}

/*
  # Usage in your webhook handler:
  
  Replace the existing payment method capture logic with:
  
  ```typescript
  const { payment_method_brand, payment_method_last4 } = await capturePaymentMethodDetails(
    stripe, 
    session, 
    customerId
  );
  ```
  
  This ensures:
  1. Multiple fallback methods to get real card data
  2. Proper validation that last4 is actually 4 digits
  3. Detailed logging for debugging
  4. Never generates fake data from payment_intent_id or other sources
  5. Falls back to clean '****' placeholder if real data can't be obtained
*/

// Also create a function to sync existing users' payment method data
async function syncExistingUserPaymentMethod(
  stripe: any, 
  customerId: string, 
  supabase: any
): Promise<{ success: boolean; payment_method_brand?: string; payment_method_last4?: string; error?: string }> {
  
  try {
    console.log(`Syncing payment method for existing customer: ${customerId}`);
    
    // Get customer's active subscriptions
    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      status: 'active',
      limit: 1,
      expand: ['data.default_payment_method']
    });
    
    let payment_method_brand = 'card';
    let payment_method_last4 = '****';
    
    if (subscriptions.data.length > 0) {
      const subscription = subscriptions.data[0];
      const paymentMethod = subscription.default_payment_method;
      
      if (paymentMethod?.card) {
        payment_method_brand = paymentMethod.card.brand || 'card';
        payment_method_last4 = paymentMethod.card.last4 || '****';
        
        if (payment_method_last4.match(/^[0-9]{4}$/)) {
          // Update database with real payment method data
          const { error: orderError } = await supabase
            .from('stripe_orders')
            .update({
              payment_method_brand,
              payment_method_last4,
              updated_at: new Date().toISOString()
            })
            .eq('customer_id', customerId)
            .eq('status', 'completed')
            .is('deleted_at', null);
          
          if (orderError) {
            console.error('Failed to update orders:', orderError);
            return { success: false, error: 'Failed to update orders' };
          }
          
          const { error: subError } = await supabase
            .from('stripe_subscriptions')
            .update({
              payment_method_brand,
              payment_method_last4,
              updated_at: new Date().toISOString()
            })
            .eq('customer_id', customerId)
            .is('deleted_at', null);
          
          if (subError) {
            console.error('Failed to update subscriptions:', subError);
            return { success: false, error: 'Failed to update subscriptions' };
          }
          
          console.log(`✅ Successfully synced payment method for ${customerId}: ${payment_method_brand} ending in ${payment_method_last4}`);
          return { success: true, payment_method_brand, payment_method_last4 };
        }
      }
    }
    
    return { success: false, error: 'No valid payment method found' };
    
  } catch (error) {
    console.error(`Failed to sync payment method for ${customerId}:`, error);
    return { success: false, error: error.message };
  }
} 
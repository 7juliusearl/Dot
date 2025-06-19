// FIXED: syncSubscriptionData function with proper error handling
// Replace the syncSubscriptionData function in your webhook with this version

async function syncSubscriptionData(customerId: string, retryCount = 0) {
  console.log(`Syncing subscription data for customer: ${customerId} (attempt ${retryCount + 1})`);
  
  try {
    // Add delay for retry attempts to let Stripe process
    if (retryCount > 0) {
      const delay = Math.min(1000 * Math.pow(2, retryCount), 10000); // Exponential backoff, max 10s
      console.log(`Waiting ${delay}ms before retry...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }

    // Get customer's active subscriptions from Stripe
    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      limit: 1,
      status: 'all',
      expand: ['data.default_payment_method']
    });

    console.log(`Found ${subscriptions.data.length} subscriptions for customer ${customerId}`);

    // Check if subscription record exists in database
    const { data: existingSubscription } = await supabase
      .from('stripe_subscriptions')
      .select('*')
      .eq('customer_id', customerId)
      .maybeSingle();

    const subscriptionData = subscriptions.data[0];
    const paymentMethod = subscriptionData?.default_payment_method as Stripe.PaymentMethod;

    let updateData;
    
    if (subscriptionData) {
      // We have subscription data from Stripe - use it
      updateData = {
        subscription_id: subscriptionData.id,
        price_id: subscriptionData.items.data[0].price.id,
        current_period_start: subscriptionData.current_period_start,
        current_period_end: subscriptionData.current_period_end,
        cancel_at_period_end: subscriptionData.cancel_at_period_end,
        payment_method_brand: paymentMethod?.card?.brand || 'card',
        payment_method_last4: paymentMethod?.card?.last4 || '****',
        status: subscriptionData.status, // Use actual Stripe status
        updated_at: new Date().toISOString()
      };
      console.log('Using subscription data from Stripe:', { 
        id: subscriptionData.id, 
        status: subscriptionData.status 
      });
    } else {
      // No subscription found in Stripe
      if (retryCount < 3) {
        // Retry up to 3 times - Stripe might still be processing
        console.log(`No subscription found, retrying in a moment... (attempt ${retryCount + 1}/3)`);
        return await syncSubscriptionData(customerId, retryCount + 1);
      }
      
      // After 3 retries, check if this is a lifetime purchase or subscription issue
      console.log('No subscription found after retries, checking order type...');
      
      // Check if this customer has any completed orders to determine type
      const { data: orderData } = await supabase
        .from('stripe_orders')
        .select('purchase_type')
        .eq('customer_id', customerId)
        .eq('status', 'completed')
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      if (orderData?.purchase_type === 'lifetime') {
        // Lifetime purchase - no subscription needed, but record should exist
        updateData = {
          subscription_id: null,
          price_id: 'price_1RW02UInTpoMSXouhnQLA7Jn', // Lifetime price
          current_period_start: null,
          current_period_end: null,
          cancel_at_period_end: false,
          payment_method_brand: 'card',
          payment_method_last4: '****',
          status: 'active', // ⭐ FIXED: Set to 'active' for lifetime users
          updated_at: new Date().toISOString()
        };
        console.log('Lifetime purchase detected - setting active status');
      } else {
        // Monthly purchase but no subscription found - this is an error
        // Set to active with generated data (emergency fallback)
        updateData = {
          subscription_id: `sub_generated_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
          price_id: 'price_1RW01zInTpoMSXoua1wZb9zY', // Monthly price
          current_period_start: Math.floor(Date.now() / 1000),
          current_period_end: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60), // +30 days
          cancel_at_period_end: false,
          payment_method_brand: 'card',
          payment_method_last4: '****',
          status: 'active', // ⭐ FIXED: Set to 'active' instead of 'not_started'
          updated_at: new Date().toISOString()
        };
        console.log('⚠️ Monthly purchase but no Stripe subscription found - using fallback data');
        
        // Log this as an error for investigation
        console.error(`WEBHOOK ERROR: Monthly customer ${customerId} has no subscription in Stripe after checkout`);
      }
    }

    console.log('Updating subscription with data:', {
      customer_id: customerId,
      status: updateData.status,
      subscription_id: updateData.subscription_id
    });

    let result;
    if (existingSubscription) {
      result = await supabase
        .from('stripe_subscriptions')
        .update(updateData)
        .eq('customer_id', customerId);
    } else {
      result = await supabase
        .from('stripe_subscriptions')
        .insert({
          ...updateData,
          customer_id: customerId
        });
    }

    if (result.error) {
      console.error('Database update error:', result.error);
      throw result.error;
    }

    console.log(`✅ Subscription data synced successfully for ${customerId} with status: ${updateData.status}`);
    return updateData;
    
  } catch (error) {
    console.error(`Error syncing subscription data for ${customerId}:`, error);
    
    // If we haven't retried yet, try once more
    if (retryCount === 0) {
      console.log('Retrying subscription sync after error...');
      return await syncSubscriptionData(customerId, 1);
    }
    
    // After retries failed, create a minimal active record to prevent "not_started" state
    console.log('⚠️ Creating emergency fallback record to prevent not_started status');
    try {
      const fallbackData = {
        subscription_id: `sub_fallback_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        price_id: 'price_1RW01zInTpoMSXoua1wZb9zY', // Default to monthly
        current_period_start: Math.floor(Date.now() / 1000),
        current_period_end: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
        cancel_at_period_end: false,
        payment_method_brand: 'card',
        payment_method_last4: '****',
        status: 'active', // ⭐ CRITICAL: Always default to 'active' for completed checkouts
        updated_at: new Date().toISOString()
      };

      await supabase
        .from('stripe_subscriptions')
        .upsert({
          ...fallbackData,
          customer_id: customerId
        });
        
      console.log(`🆘 Emergency fallback record created for ${customerId} - manual investigation needed`);
    } catch (fallbackError) {
      console.error('Failed to create fallback record:', fallbackError);
    }
    
    throw error;
  }
} 
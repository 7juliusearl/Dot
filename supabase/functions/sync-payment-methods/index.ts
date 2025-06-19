import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.21.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
      apiVersion: '2023-10-16',
    })

    console.log('Starting payment method sync for existing users...')

    // Get all users needing payment method sync (simplified query)
    const { data: ordersNeedingSync, error: fetchError } = await supabase
      .from('stripe_orders')
      .select('customer_id, payment_intent_id, purchase_type, email')
      .eq('status', 'completed')
      .is('deleted_at', null)
      .eq('payment_method_last4', '****')
      .order('created_at', { ascending: false })

    if (fetchError) {
      throw new Error(`Failed to fetch orders: ${fetchError.message}`)
    }

    console.log(`Found ${ordersNeedingSync.length} orders needing payment method sync`)

    const results = {
      total_orders: ordersNeedingSync.length,
      successful_syncs: 0,
      failed_syncs: 0,
      errors: [] as any[],
      synced_users: [] as any[]
    }

    // Process each order
    for (const order of ordersNeedingSync) {
      try {
        console.log(`Processing customer: ${order.customer_id} (${order.email})`)
        
        let payment_method_brand = 'card'
        let payment_method_last4 = '****'
        let sync_method = 'none'

        // Method 1: Try to get from active subscription
        try {
          const subscriptions = await stripe.subscriptions.list({
            customer: order.customer_id,
            status: 'active',
            limit: 1,
            expand: ['data.default_payment_method']
          })

          if (subscriptions && subscriptions.data && subscriptions.data.length > 0) {
            const subscription = subscriptions.data[0]
            const paymentMethod = subscription.default_payment_method as Stripe.PaymentMethod
            
            if (paymentMethod && paymentMethod.card) {
              payment_method_brand = paymentMethod.card.brand || 'card'
              payment_method_last4 = paymentMethod.card.last4 || '****'
              sync_method = 'active_subscription'
              console.log(`✅ Got payment method from active subscription: ${payment_method_brand} ending in ${payment_method_last4}`)
            }
          }
        } catch (error: any) {
          console.log(`No active subscription found for ${order.customer_id}:`, error?.message || 'Unknown error')
        }

        // Method 2: Try to get from payment intent if we have one
        if (payment_method_last4 === '****' && order.payment_intent_id && order.payment_intent_id.startsWith('pi_')) {
          try {
            const paymentIntent = await stripe.paymentIntents.retrieve(order.payment_intent_id, {
              expand: ['payment_method']
            })

            const paymentMethod = paymentIntent.payment_method as Stripe.PaymentMethod
            if (paymentMethod?.card) {
              payment_method_brand = paymentMethod.card.brand || 'card'
              payment_method_last4 = paymentMethod.card.last4 || '****'
              sync_method = 'payment_intent'
              console.log(`✅ Got payment method from payment intent: ${payment_method_brand} ending in ${payment_method_last4}`)
            }
          } catch (error: any) {
            console.log(`Failed to get payment method from payment intent ${order.payment_intent_id}:`, error.message)
          }
        }

        // Method 3: Try to get from customer's payment methods
        if (payment_method_last4 === '****') {
          try {
            const paymentMethods = await stripe.paymentMethods.list({
              customer: order.customer_id,
              type: 'card',
              limit: 1
            })

            if (paymentMethods && paymentMethods.data && paymentMethods.data.length > 0) {
              const paymentMethod = paymentMethods.data[0]
              if (paymentMethod && paymentMethod.card) {
                payment_method_brand = paymentMethod.card.brand || 'card'
                payment_method_last4 = paymentMethod.card.last4 || '****'
                sync_method = 'customer_payment_methods'
                console.log(`✅ Got payment method from customer payment methods: ${payment_method_brand} ending in ${payment_method_last4}`)
              }
            }
          } catch (error: any) {
            console.log(`Failed to get payment methods for customer ${order.customer_id}:`, error?.message || 'Unknown error')
          }
        }

        // Method 4: Try to get from any subscription (including canceled)
        if (payment_method_last4 === '****') {
          try {
            const allSubscriptions = await stripe.subscriptions.list({
              customer: order.customer_id,
              status: 'all',
              limit: 5,
              expand: ['data.default_payment_method']
            })

            if (allSubscriptions && allSubscriptions.data) {
              for (const subscription of allSubscriptions.data) {
                const paymentMethod = subscription.default_payment_method as Stripe.PaymentMethod
                if (paymentMethod && paymentMethod.card) {
                  payment_method_brand = paymentMethod.card.brand || 'card'
                  payment_method_last4 = paymentMethod.card.last4 || '****'
                  sync_method = 'any_subscription'
                  console.log(`✅ Got payment method from subscription ${subscription.id}: ${payment_method_brand} ending in ${payment_method_last4}`)
                  break
                }
              }
            }
          } catch (error: any) {
            console.log(`Failed to get subscriptions for customer ${order.customer_id}:`, error?.message || 'Unknown error')
          }
        }

        // Update database if we got real card data
        if (payment_method_last4 !== '****' && payment_method_last4.match(/^[0-9]{4}$/)) {
          // Update stripe_orders
          const { error: orderError } = await supabase
            .from('stripe_orders')
            .update({
              payment_method_brand,
              payment_method_last4,
              updated_at: new Date().toISOString()
            })
            .eq('customer_id', order.customer_id)
            .eq('status', 'completed')
            .is('deleted_at', null)

          if (orderError) {
            throw new Error(`Failed to update orders: ${orderError.message}`)
          }

          // Update stripe_subscriptions
          const { error: subError } = await supabase
            .from('stripe_subscriptions')
            .update({
              payment_method_brand,
              payment_method_last4,
              updated_at: new Date().toISOString()
            })
            .eq('customer_id', order.customer_id)
            .is('deleted_at', null)

          if (subError) {
            console.warn(`Failed to update subscriptions for ${order.customer_id}: ${subError.message}`)
          }

          // Log the successful sync
          await supabase
            .from('sync_logs')
            .insert({
              customer_id: order.customer_id,
              operation: 'payment_method_sync_from_stripe',
              status: 'success',
              details: {
                email: order.email,
                payment_method_brand,
                payment_method_last4,
                sync_method,
                timestamp: new Date().toISOString()
              }
            })

          results.successful_syncs++
          results.synced_users.push({
            customer_id: order.customer_id,
            email: order.email,
            payment_method_brand,
            payment_method_last4,
            sync_method
          })

          console.log(`✅ Successfully synced ${order.customer_id}: ${payment_method_brand} ending in ${payment_method_last4}`)
        } else {
          // Log failed sync
          await supabase
            .from('sync_logs')
            .insert({
              customer_id: order.customer_id,
              operation: 'payment_method_sync_from_stripe',
              status: 'failed',
              details: {
                email: order.email,
                error: 'No valid payment method found in Stripe',
                timestamp: new Date().toISOString()
              }
            })

          results.failed_syncs++
          results.errors.push({
            customer_id: order.customer_id,
            email: order.email,
            error: 'No valid payment method found in Stripe'
          })

          console.log(`❌ Failed to sync ${order.customer_id}: No valid payment method found`)
        }

        // Add small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 100))

      } catch (error: any) {
        console.error(`Error processing customer ${order.customer_id}:`, error)
        results.failed_syncs++
        results.errors.push({
          customer_id: order.customer_id,
          email: order.email || 'unknown',
          error: error.message
        })

        // Log the error
        await supabase
          .from('sync_logs')
          .insert({
            customer_id: order.customer_id,
            operation: 'payment_method_sync_from_stripe',
            status: 'error',
            details: {
              error: error.message,
              timestamp: new Date().toISOString()
            }
          })
      }
    }

    console.log('Payment method sync completed:', results)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Payment method sync completed',
        results
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error: any) {
    console.error('Error in payment method sync:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
}) 
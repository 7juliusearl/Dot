import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

// Create two clients: one for auth, one for admin operations
const supabaseAuth = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '');
const supabaseAdmin = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');

const stripeSecret = Deno.env.get('STRIPE_SECRET_KEY')!;
const stripe = new Stripe(stripeSecret, {
  appInfo: {
    name: 'Bolt Integration',
    version: '1.0.0',
  },
});

function corsResponse(body: string | object | null, status = 200) {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  };

  if (status === 204) {
    return new Response(null, { status, headers });
  }

  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...headers,
      'Content-Type': 'application/json',
    },
  });
}

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return corsResponse({}, 204);
    }

    if (req.method !== 'POST') {
      return corsResponse({ error: 'Method not allowed' }, 405);
    }

    const { price_id, mode } = await req.json();

    const error = validateParameters(
      { price_id, mode },
      {
        price_id: 'string',
        mode: { values: ['payment', 'subscription'] },
      },
    );

    if (error) {
      return corsResponse({ error }, 400);
    }

    const authHeader = req.headers.get('Authorization')!;
    const token = authHeader.replace('Bearer ', '');
    const {
      data: { user },
      error: getUserError,
    } = await supabaseAuth.auth.getUser(token);

    if (getUserError) {
      return corsResponse({ error: 'Failed to authenticate user' }, 401);
    }

    if (!user) {
      return corsResponse({ error: 'User not found' }, 404);
    }

    const { data: customer, error: getCustomerError } = await supabaseAdmin
      .from('stripe_customers')
      .select('customer_id')
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .maybeSingle();

    if (getCustomerError) {
      console.error('Failed to fetch customer information from the database', getCustomerError);
      return corsResponse({ error: 'Failed to fetch customer information' }, 500);
    }

    let customerId;

    if (!customer || !customer.customer_id) {
      // Check if customer already exists in Stripe to prevent duplicates
      let existingStripeCustomer;
      try {
        const stripeCustomers = await stripe.customers.list({
          email: user.email,
          limit: 1
        });
        existingStripeCustomer = stripeCustomers.data[0];
      } catch (error) {
        console.error('Error checking existing Stripe customers:', error);
      }

      let stripeCustomerId;
      
      if (existingStripeCustomer) {
        console.log(`Found existing Stripe customer ${existingStripeCustomer.id} for user ${user.id}`);
        stripeCustomerId = existingStripeCustomer.id;
      } else {
        const newCustomer = await stripe.customers.create({
          email: user.email,
          metadata: {
            userId: user.id,
          },
        });
        console.log(`Created new Stripe customer ${newCustomer.id} for user ${user.id}`);
        stripeCustomerId = newCustomer.id;
      }

      // Use upsert to handle potential race conditions and duplicate entries
      console.log('Attempting to create customer mapping:', {
        user_id: user.id,
        customer_id: stripeCustomerId,
        user_email: user.email
      });

      const { error: createCustomerError } = await supabaseAdmin.from('stripe_customers').upsert({
        user_id: user.id,
        customer_id: stripeCustomerId,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id',
        ignoreDuplicates: false
      });

      if (createCustomerError) {
        console.error('DETAILED ERROR for customer mapping:', {
          error: createCustomerError,
          code: createCustomerError.code,
          message: createCustomerError.message,
          details: createCustomerError.details,
          hint: createCustomerError.hint
        });

        // Only delete the Stripe customer if we just created it
        if (!existingStripeCustomer) {
          try {
            await stripe.customers.del(stripeCustomerId);
          } catch (deleteError) {
            console.error('Failed to clean up Stripe customer after database error:', deleteError);
          }
        }

        return corsResponse({ 
          error: 'Failed to create customer mapping',
          debug: {
            code: createCustomerError.code,
            message: createCustomerError.message,
            details: createCustomerError.details
          }
        }, 500);
      }

      if (mode === 'subscription') {
        // Use upsert for subscription record too
        const { error: createSubscriptionError } = await supabaseAdmin.from('stripe_subscriptions').upsert({
          customer_id: stripeCustomerId,
          status: 'not_started',
          updated_at: new Date().toISOString()
        }, {
          onConflict: 'customer_id',
          ignoreDuplicates: true
        });

        if (createSubscriptionError) {
          console.error('Failed to save subscription in the database', createSubscriptionError);
          // Don't fail the entire process for subscription record issues
          console.log('Continuing with checkout despite subscription record issue');
        }
      }

      customerId = stripeCustomerId;
      console.log(`Successfully set up customer ${customerId}`);
    } else {
      customerId = customer.customer_id;

      if (mode === 'subscription') {
        const { data: subscription, error: getSubscriptionError } = await supabaseAdmin
          .from('stripe_subscriptions')
          .select('status')
          .eq('customer_id', customerId)
          .maybeSingle();

        if (getSubscriptionError) {
          console.error('Failed to fetch subscription information from the database', getSubscriptionError);
          return corsResponse({ error: 'Failed to fetch subscription information' }, 500);
        }

        if (!subscription) {
          const { error: createSubscriptionError } = await supabaseAdmin.from('stripe_subscriptions').insert({
            customer_id: customerId,
            status: 'not_started',
          });

          if (createSubscriptionError) {
            console.error('Failed to create subscription record for existing customer', createSubscriptionError);
            return corsResponse({ error: 'Failed to create subscription record for existing customer' }, 500);
          }
        }
      }
    }

    // Validate origin for security
    const origin = req.headers.get('Origin');
    const allowedOrigins = [
      'https://dayoftimeline.app',
      'https://www.dayoftimeline.app',
      'http://localhost:5173',
      'http://localhost:3000'
    ];
    
    const baseUrl = origin && allowedOrigins.includes(origin) 
      ? origin 
      : 'https://dayoftimeline.app';

    console.log(`Using base URL: ${baseUrl} for checkout session`);

    // Create URLs with proper encoding
    const planType = mode === 'subscription' ? 'yearly' : 'lifetime';
    const successUrl = new URL('/payment/verify', baseUrl);
    successUrl.searchParams.set('plan', planType);
    
    const cancelUrl = new URL('/payment', baseUrl);
    cancelUrl.searchParams.set('plan', planType);

    console.log(`Success URL: ${successUrl.toString()}`);
    console.log(`Cancel URL: ${cancelUrl.toString()}`);

    // Create Checkout Session with properly encoded URLs
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      payment_method_types: ['card'],
      line_items: [
        {
          price: price_id,
          quantity: 1,
        },
      ],
      mode,
      success_url: successUrl.toString(),
      cancel_url: cancelUrl.toString(),
      allow_promotion_codes: true,
    });

    console.log(`Created checkout session ${session.id} for customer ${customerId}`);

    return corsResponse({ sessionId: session.id, url: session.url });
  } catch (error: any) {
    console.error(`Checkout error: ${error.message}`);
    return corsResponse({ error: error.message }, 500);
  }
});

type ExpectedType = 'string' | { values: string[] };
type Expectations<T> = { [K in keyof T]: ExpectedType };

function validateParameters<T extends Record<string, any>>(values: T, expected: Expectations<T>): string | undefined {
  for (const parameter in values) {
    const expectation = expected[parameter];
    const value = values[parameter];

    if (expectation === 'string') {
      if (value == null) {
        return `Missing required parameter ${parameter}`;
      }
      if (typeof value !== 'string') {
        return `Expected parameter ${parameter} to be a string got ${JSON.stringify(value)}`;
      }
    } else {
      if (!expectation.values.includes(value)) {
        return `Expected parameter ${parameter} to be one of ${expectation.values.join(', ')}`;
      }
    }
  }

  return undefined;
}
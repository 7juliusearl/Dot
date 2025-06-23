import type { Context, Config } from "@netlify/functions";
import { createHmac } from 'crypto';

export default async (req: Request, context: Context) => {
  console.log('Stripe webhook proxy invoked:', req.method);

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // Get environment variables  
    const supabaseUrl = process.env.VITE_SUPABASE_URL;
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    console.log('Environment variables check:', {
      hasSupabaseUrl: !!supabaseUrl,
      hasServiceKey: !!serviceRoleKey,
      hasWebhookSecret: !!stripeWebhookSecret,
      supabaseUrlLength: supabaseUrl?.length || 0
    });

    if (!supabaseUrl || !serviceRoleKey) {
      console.error('Missing Supabase environment variables', {
        supabaseUrl: supabaseUrl?.substring(0, 20),
        hasServiceKey: !!serviceRoleKey
      });
      return new Response(`Configuration error: missing ${!supabaseUrl ? 'VITE_SUPABASE_URL' : 'SUPABASE_SERVICE_ROLE_KEY'}`, { status: 500 });
    }

    // Get the raw request body for signature verification
    const body = await req.text();
    const stripeSignature = req.headers.get('stripe-signature');

    console.log('Webhook received:', {
      hasSignature: !!stripeSignature,
      bodyLength: body.length,
      supabaseUrl: supabaseUrl?.substring(0, 20) + '...'
    });

    // Verify Stripe signature if webhook secret is available
    if (stripeWebhookSecret && stripeSignature) {
      try {
        const signature = stripeSignature.split(',').reduce((acc, part) => {
          const [key, value] = part.split('=');
          acc[key] = value;
          return acc;
        }, {} as Record<string, string>);

        const expectedSignature = createHmac('sha256', stripeWebhookSecret)
          .update(signature.t + '.' + body)
          .digest('hex');

        if (signature.v1 !== expectedSignature) {
          console.error('Invalid Stripe signature');
          return new Response('Invalid signature', { status: 400 });
        }
      } catch (error) {
        console.error('Signature verification error:', error);
        return new Response('Signature verification failed', { status: 400 });
      }
    }

    // Forward to the working Netlify function instead of broken Supabase function
    const netlifyResponse = await fetch(
      `https://${req.headers.get('host')}/api/stripe-webhook-complete`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'stripe-signature': stripeSignature || '',
        },
        body: body
      }
    );

    const responseText = await netlifyResponse.text();
    console.log('Netlify function response:', {
      status: netlifyResponse.status,
      statusText: netlifyResponse.statusText,
      body: responseText.substring(0, 200)
    });

    // Return success to Stripe
    if (netlifyResponse.ok) {
      return new Response('Webhook processed successfully', { status: 200 });
    } else {
      console.error('Netlify function error:', responseText);
      return new Response('Webhook processing failed', { status: 500 });
    }

  } catch (error) {
    console.error('Webhook proxy error:', error);
    return new Response('Internal server error', { 
      status: 500,
      headers: { 'Content-Type': 'text/plain' }
    });
  }
};

export const config: Config = {
  path: "/api/stripe-webhook"
}; 
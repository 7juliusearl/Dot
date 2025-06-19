import type { Context, Config } from "@netlify/functions";

export default async (req: Request, context: Context) => {
  console.log('Simple webhook proxy invoked:', req.method, req.url);

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // Get the request body
    const body = await req.text();
    const stripeSignature = req.headers.get('stripe-signature');
    
    console.log('Webhook received:', {
      hasSignature: !!stripeSignature,
      bodyLength: body.length,
      bodyPreview: body.substring(0, 100)
    });

    // Parse the webhook payload
    let event;
    try {
      event = JSON.parse(body);
    } catch (e) {
      console.error('Failed to parse JSON:', e);
      return new Response('Invalid JSON', { status: 400 });
    }

    console.log('Webhook event:', {
      type: event.type,
      id: event.id
    });

    // For now, just log the event and return success
    // This will at least stop the 401 errors from Stripe
    if (event.type === 'checkout.session.completed') {
      console.log('Checkout session completed:', event.data?.object?.id);
      
      // TODO: Process the checkout session
      // For now, just acknowledge receipt
      return new Response('Webhook received successfully', { 
        status: 200,
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    // For other event types, also return success
    return new Response('Event acknowledged', { 
      status: 200,
      headers: { 'Content-Type': 'text/plain' }
    });

  } catch (error) {
    console.error('Webhook processing error:', error);
    return new Response('Internal server error', { 
      status: 500,
      headers: { 'Content-Type': 'text/plain' }
    });
  }
};

export const config: Config = {
  path: "/api/stripe-webhook-simple"
}; 
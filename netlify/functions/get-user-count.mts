import type { Context, Config } from "@netlify/functions";
import { createClient } from '@supabase/supabase-js';

export default async (req: Request, context: Context) => {
  // Only allow GET requests
  if (req.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // Create Supabase client with service role key (bypasses RLS)
    const supabase = createClient(
      Netlify.env.get('VITE_SUPABASE_URL')!,
      Netlify.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Count only lifetime purchases (non-deleted)
    const { count, error } = await supabase
      .from('stripe_orders')
      .select('*', { count: 'exact', head: true })
      .eq('purchase_type', 'lifetime')
      .is('deleted_at', null);

    if (error) {
      console.error('Error counting users:', error);
      return new Response(JSON.stringify({ 
        error: 'Database error',
        count: 0 
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ 
      count: count || 0,
      success: true 
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET',
        'Access-Control-Allow-Headers': 'Content-Type'
      }
    });

  } catch (error) {
    console.error('Function error:', error);
    return new Response(JSON.stringify({ 
      error: 'Server error',
      count: 0 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
};

export const config: Config = {
  path: "/api/user-count"
}; 
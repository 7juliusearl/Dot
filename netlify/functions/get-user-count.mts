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

    // Count ONLY lifetime users with completed orders
    const { count, error } = await supabase
      .from('stripe_orders')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'completed')
      .is('deleted_at', null)
      .eq('purchase_type', 'lifetime');

    if (error) {
      console.error('Error counting lifetime users:', error);
      return new Response(JSON.stringify({ 
        error: 'Database error',
        count: 0 
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Also get breakdown for debugging (including $27.99 orders as lifetime)
    const { data: breakdown, error: breakdownError } = await supabase
      .from('stripe_orders')
      .select('purchase_type, amount_total')
      .eq('status', 'completed')
      .is('deleted_at', null)
      .in('purchase_type', ['lifetime', 'monthly', 'yearly']);

    let debugInfo = {};
    if (!breakdownError && breakdown) {
      // Count $27.99 orders as lifetime regardless of their purchase_type
      const lifetimeCount = breakdown.filter(o => 
        o.purchase_type === 'lifetime' || o.amount_total === 2799
      ).length;
      const monthlyCount = breakdown.filter(o => 
        o.purchase_type === 'monthly' && o.amount_total !== 2799
      ).length;
      const yearlyCount = breakdown.filter(o => 
        o.purchase_type === 'yearly' && o.amount_total !== 2799
      ).length;
      
      debugInfo = {
        lifetime: lifetimeCount,
        monthly: monthlyCount,
        yearly: yearlyCount
      };
    }

    console.log('User count breakdown:', debugInfo);
    console.log('Lifetime users count:', count);

    return new Response(JSON.stringify({ 
      count: count || 0,
      success: true,
      breakdown: debugInfo
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
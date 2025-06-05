import type { Context, Config } from "@netlify/functions";

interface SyncResult {
  customer_id: string;
  status: 'success' | 'error';
  data?: any;
  error?: string;
}

export default async (req: Request, context: Context) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }

  try {
    const supabaseUrl = process.env.VITE_SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration');
    }

    // Get all customer IDs from the database that might need sync
    const customersResponse = await fetch(`${supabaseUrl}/rest/v1/stripe_customers?select=customer_id,payment_type`, {
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'apikey': supabaseServiceKey,
        'Content-Type': 'application/json',
      }
    });

    if (!customersResponse.ok) {
      throw new Error('Failed to fetch customers from database');
    }

    const customers = await customersResponse.json();
    const monthlyCustomers = customers.filter((c: any) => c.payment_type === 'monthly');
    
    console.log(`Found ${monthlyCustomers.length} monthly customers to sync`);

    const results: SyncResult[] = [];

    // For each monthly customer, call the stripe-sync function
    for (const customer of monthlyCustomers) {
      try {
        console.log(`Syncing customer: ${customer.customer_id}`);
        
        const syncResponse = await fetch(`${supabaseUrl}/functions/v1/stripe-sync`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            customer_id: customer.customer_id
          })
        });

        if (syncResponse.ok) {
          const syncResult = await syncResponse.json();
          results.push({
            customer_id: customer.customer_id,
            status: 'success',
            data: syncResult
          });
        } else {
          const errorText = await syncResponse.text();
          results.push({
            customer_id: customer.customer_id,
            status: 'error',
            error: errorText
          });
        }
      } catch (error) {
        results.push({
          customer_id: customer.customer_id,
          status: 'error',
          error: error instanceof Error ? error.message : 'Unknown error'
        });
      }
    }

    return new Response(
      JSON.stringify({
        message: 'Sync completed',
        total_customers: monthlyCustomers.length,
        results: results
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error) {
    console.error('Error syncing subscription data:', error);
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
};

export const config: Config = {
  path: "/api/sync-subscription-data"
}; 
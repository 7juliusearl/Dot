import { Handler } from '@netlify/functions';

const CUSTOMER_IDS = [
  'cus_SYTcC4irOkLilX',  // sarahdeloachphotography@gmail.com
  'cus_SYOlI54YnfORSB',  // ambergcphotos@gmail.com  
  'cus_SYOpAgoMKUl6jA',  // nic.dampier@gmail.com
  'cus_SYNoUuO1DZfCkx',  // lunuphotography@gmail.com
  'cus_SYLdNppx7h9O0g',  // madisonhernandezphotography@gmail.com
  'cus_SYL3wPUyfhaAMJ',  // sammy@scoylephoto.com
  'cus_SYKpQEtSq8KAnO',  // lkdanielphotography@gmail.com
  'cus_SYIqIrOdyoDljg',  // christa@christaandcophoto.com
  'cus_SYHXPA4yxz6cde',  // kendrickjlittle1@gmail.com
  'cus_SYFSaOLJ3AFVRl'   // contact@emerlinphotography.com
];

export const handler: Handler = async (event, context) => {
  console.log('🚀 Starting batch payment method sync for 10 customers...');
  
  try {
    const results: Array<{
      customer_id: string;
      success: boolean;
      response?: any;
      error?: string;
    }> = [];
    
    const supabaseUrl = process.env.SUPABASE_URL;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    
    if (!supabaseUrl || !serviceKey) {
      throw new Error('Missing Supabase environment variables');
    }
    
    for (let i = 0; i < CUSTOMER_IDS.length; i++) {
      const customerId = CUSTOMER_IDS[i];
      console.log(`Syncing ${i + 1}/10: ${customerId}`);
      
      try {
        // Call the Supabase sync function
        const response = await fetch(`${supabaseUrl}/functions/v1/sync-payment-methods`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${serviceKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            action: 'sync_single_customer',
            customer_id: customerId
          })
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${await response.text()}`);
        }

        const result = await response.json();
        results.push({
          customer_id: customerId,
          success: true,
          response: result
        });
        
        console.log(`✅ ${i + 1}/10 completed: ${customerId}`);
        
        // Add delay between requests to be nice to APIs
        if (i < CUSTOMER_IDS.length - 1) {
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
        
      } catch (error) {
        console.error(`❌ ${i + 1}/10 failed: ${customerId} - ${error.message}`);
        results.push({
          customer_id: customerId,
          success: false,
          error: error.message
        });
      }
    }

    const successCount = results.filter(r => r.success).length;
    const failCount = results.filter(r => !r.success).length;

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: true,
        message: `Batch payment method sync completed!`,
        summary: {
          total_customers: CUSTOMER_IDS.length,
          successful_syncs: successCount,
          failed_syncs: failCount,
          success_rate: `${((successCount / CUSTOMER_IDS.length) * 100).toFixed(1)}%`
        },
        detailed_results: results,
        next_steps: [
          'Run check_payment_method_results.sql to verify the updates',
          'Customers should now see real card brands and last 4 digits',
          'Any failed syncs may need manual retry'
        ]
      })
    };

  } catch (error) {
    console.error('Batch sync failed:', error);
    
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: false,
        error: error.message,
        message: 'Batch payment method sync failed'
      })
    };
  }
}; 
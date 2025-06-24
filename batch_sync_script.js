// 🔄 BATCH PAYMENT METHOD SYNC SCRIPT
// Run this in your browser console on the Supabase Dashboard

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

const SUPABASE_URL = 'https://juwurgxmwltebeuqindt.supabase.co';
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1d3VyZ3htd2x0ZWJldXFpbmR0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczMzEzMzk2MCwiZXhwIjoyMDQ4NzA5OTYwfQ.gNKBvw_Z6-JpapkF5M_VRXeJz5WNWFKQ4wfJP8V8QP8';

async function batchSyncPaymentMethods() {
  console.log('🚀 Starting batch payment method sync...');
  const results = [];
  
  for (let i = 0; i < CUSTOMER_IDS.length; i++) {
    const customerId = CUSTOMER_IDS[i];
    console.log(`Syncing ${i + 1}/10: ${customerId}`);
    
    try {
      const response = await fetch(`${SUPABASE_URL}/functions/v1/sync-payment-methods`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${SERVICE_KEY}`,
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
        result: result
      });
      
      console.log(`✅ ${i + 1}/10 completed:`, result);
      
      // Add delay between requests
      if (i < CUSTOMER_IDS.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
      
    } catch (error) {
      console.error(`❌ ${i + 1}/10 failed: ${customerId} -`, error);
      results.push({
        customer_id: customerId,
        success: false,
        error: error.message
      });
    }
  }

  const successCount = results.filter(r => r.success).length;
  const failCount = results.filter(r => !r.success).length;

  console.log('\n🎯 BATCH SYNC COMPLETE!');
  console.log(`✅ Successful: ${successCount}/${CUSTOMER_IDS.length}`);
  console.log(`❌ Failed: ${failCount}/${CUSTOMER_IDS.length}`);
  console.log(`📊 Success Rate: ${((successCount / CUSTOMER_IDS.length) * 100).toFixed(1)}%`);
  
  return results;
}

// Run the batch sync
batchSyncPaymentMethods();

/*
HOW TO USE:
1. Open your browser console (F12)
2. Copy and paste this entire script
3. Press Enter
4. Watch the progress in console
5. Run check_payment_method_results.sql to verify
*/ 
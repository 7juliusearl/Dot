// 🔄 BATCH PAYMENT METHOD SYNC SCRIPT - SUPABASE DASHBOARD VERSION
// Run this in your browser console WHILE ON THE SUPABASE DASHBOARD

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

async function batchSyncFromDashboard() {
  console.log('🚀 Starting batch payment method sync from Supabase Dashboard...');
  
  // Get auth token from Supabase Dashboard session
  const authToken = localStorage.getItem('supabase.auth.token');
  if (!authToken) {
    console.error('❌ No auth token found. Make sure you are logged into Supabase Dashboard');
    return;
  }
  
  let parsedToken;
  try {
    parsedToken = JSON.parse(authToken);
  } catch (e) {
    console.error('❌ Could not parse auth token');
    return;
  }
  
  const accessToken = parsedToken.access_token;
  if (!accessToken) {
    console.error('❌ No access token found in session');
    return;
  }
  
  const results = [];
  
  for (let i = 0; i < CUSTOMER_IDS.length; i++) {
    const customerId = CUSTOMER_IDS[i];
    console.log(`Syncing ${i + 1}/10: ${customerId}`);
    
    try {
      const response = await fetch('https://juwurgxmwltebeuqindt.supabase.co/functions/v1/sync-payment-methods', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
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
batchSyncFromDashboard();

/*
🔧 HOW TO USE:
1. Go to https://supabase.com/dashboard/project/juwurgxmwltebeuqindt
2. Make sure you're logged in
3. Open browser console (F12)
4. Copy and paste this entire script
5. Press Enter
6. Watch the progress in console
7. Run check_payment_method_results.sql to verify
*/ 
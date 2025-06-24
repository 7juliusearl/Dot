// 🔍 DEBUG AUTH SCRIPT - Find the correct Supabase auth token
// Run this first to find your auth token

function findSupabaseAuth() {
  console.log('🔍 Searching for Supabase authentication...');
  
  // Check all possible localStorage keys
  const possibleKeys = [
    'supabase.auth.token',
    'sb-juwurgxmwltebeuqindt-auth-token',
    'sb-auth-token',
    'supabase-auth-token',
    'auth-token'
  ];
  
  console.log('📦 Checking localStorage keys...');
  for (const key of possibleKeys) {
    const value = localStorage.getItem(key);
    if (value) {
      console.log(`✅ Found key: ${key}`);
      try {
        const parsed = JSON.parse(value);
        if (parsed.access_token) {
          console.log(`🎯 Found access_token in ${key}:`, parsed.access_token.substring(0, 50) + '...');
          return parsed.access_token;
        }
      } catch (e) {
        console.log(`⚠️ Could not parse ${key}`);
      }
    }
  }
  
  // Check sessionStorage
  console.log('📦 Checking sessionStorage keys...');
  for (const key of possibleKeys) {
    const value = sessionStorage.getItem(key);
    if (value) {
      console.log(`✅ Found key in sessionStorage: ${key}`);
      try {
        const parsed = JSON.parse(value);
        if (parsed.access_token) {
          console.log(`🎯 Found access_token in sessionStorage ${key}:`, parsed.access_token.substring(0, 50) + '...');
          return parsed.access_token;
        }
      } catch (e) {
        console.log(`⚠️ Could not parse sessionStorage ${key}`);
      }
    }
  }
  
  // List all localStorage keys that contain 'supabase' or 'auth'
  console.log('🔍 All localStorage keys containing "supabase" or "auth":');
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (key && (key.includes('supabase') || key.includes('auth'))) {
      console.log(`- ${key}`);
      const value = localStorage.getItem(key);
      if (value && value.length < 200) {
        console.log(`  Value: ${value}`);
      } else {
        console.log(`  Value: [${value ? value.length : 0} characters]`);
      }
    }
  }
  
  // Check if we're on the right domain
  console.log(`🌐 Current domain: ${window.location.hostname}`);
  console.log(`🌐 Current URL: ${window.location.href}`);
  
  if (!window.location.hostname.includes('supabase.com')) {
    console.log('⚠️ You need to be on the Supabase Dashboard (supabase.com) for this to work');
  }
  
  return null;
}

// Run the debug function
const token = findSupabaseAuth();

if (token) {
  console.log('✅ Found auth token! Now running the batch sync...');
  
  // If we found a token, run the batch sync
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

  async function runBatchSync() {
    console.log('🚀 Starting batch payment method sync...');
    const results = [];
    
    for (let i = 0; i < CUSTOMER_IDS.length; i++) {
      const customerId = CUSTOMER_IDS[i];
      console.log(`Syncing ${i + 1}/10: ${customerId}`);
      
      try {
        const response = await fetch('https://juwurgxmwltebeuqindt.supabase.co/functions/v1/sync-payment-methods', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
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
  
  // Run it
  runBatchSync();
  
} else {
  console.log('❌ No auth token found. Try these steps:');
  console.log('1. Make sure you are on https://supabase.com/dashboard/project/juwurgxmwltebeuqindt');
  console.log('2. Make sure you are logged in');
  console.log('3. Try refreshing the page and running this script again');
  console.log('4. Or use the manual method from run_batch_sync_commands.md');
} 
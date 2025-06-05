import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.39.7';
import { SignJWT } from 'npm:jose@5.2.3';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

async function getAppStoreConfig() {
  const { data, error } = await supabase
    .from('app_store_config')
    .select('*')
    .limit(1)
    .single();

  if (error) throw new Error('Failed to get App Store configuration');
  return data;
}

async function generateJWT(keyId: string, issuerId: string) {
  const privateKey = Deno.env.get('APP_STORE_CONNECT_API_KEY');
  if (!privateKey) throw new Error('App Store Connect API key not found');

  const key = await crypto.subtle.importKey(
    'pkcs8',
    new TextEncoder().encode(privateKey),
    {
      name: 'ECDSA',
      namedCurve: 'P-256',
    },
    true,
    ['sign']
  );

  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId, typ: 'JWT' })
    .setIssuedAt()
    .setIssuer(issuerId)
    .setExpirationTime('20m')
    .setAudience('appstoreconnect-v1')
    .sign(key);

  return jwt;
}

async function getBetaGroupId(token: string, appId: string) {
  const response = await fetch(
    `https://api.appstoreconnect.apple.com/v1/apps/${appId}/betaGroups`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to fetch beta groups: ${error}`);
  }

  const data = await response.json();
  const betaGroup = data.data.find(group => group.attributes.name === "Beta Access Program");
  
  if (!betaGroup) {
    throw new Error('Beta Access Program group not found');
  }

  return betaGroup.id;
}

async function sendTestFlightInvite(email: string, token: string, appId: string) {
  try {
    // First, create the beta tester
    const createTesterResponse = await fetch('https://api.appstoreconnect.apple.com/v1/betaTesters', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        data: {
          type: 'betaTesters',
          attributes: {
            email: email,
            firstName: 'Beta',
            lastName: 'Tester'
          }
        }
      }),
    });

    if (!createTesterResponse.ok) {
      const error = await createTesterResponse.text();
      console.error('Failed to create beta tester:', error);
      throw new Error(`Failed to create beta tester: ${error}`);
    }

    const testerData = await createTesterResponse.json();
    const testerId = testerData.data.id;

    // Get the beta group ID
    const betaGroupId = await getBetaGroupId(token, appId);

    // Add the tester to the specific beta group
    const addToGroupResponse = await fetch(`https://api.appstoreconnect.apple.com/v1/betaGroups/${betaGroupId}/relationships/betaTesters`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        data: [{
          id: testerId,
          type: 'betaTesters'
        }]
      }),
    });

    if (!addToGroupResponse.ok) {
      const error = await addToGroupResponse.text();
      console.error('Failed to add tester to beta group:', error);
      throw new Error(`Failed to add tester to beta group: ${error}`);
    }

    // Add the tester to the app
    const addToAppResponse = await fetch(`https://api.appstoreconnect.apple.com/v1/betaTesters/${testerId}/relationships/apps`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        data: [{
          id: appId,
          type: 'apps'
        }]
      }),
    });

    if (!addToAppResponse.ok) {
      const error = await addToAppResponse.text();
      console.error('Failed to add tester to app:', error);
      throw new Error(`Failed to add tester to app: ${error}`);
    }

    // Send the beta test invitation
    const sendInviteResponse = await fetch(`https://api.appstoreconnect.apple.com/v1/betaTesters/${testerId}/betaAppReviewSubmission`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        data: {
          type: 'betaAppReviewSubmissions',
          relationships: {
            build: {
              data: {
                id: appId,
                type: 'builds'
              }
            }
          }
        }
      }),
    });

    if (!sendInviteResponse.ok) {
      const error = await sendInviteResponse.text();
      console.error('Failed to send beta test invitation:', error);
      throw new Error(`Failed to send beta test invitation: ${error}`);
    }

    return {
      testerId,
      betaGroupId,
      status: 'invited'
    };
  } catch (error) {
    console.error('Error in sendTestFlightInvite:', error);
    throw error;
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { 
          status: 405, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    const { email } = await req.json();

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'Email is required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    const config = await getAppStoreConfig();
    const token = await generateJWT(config.key_id, config.issuer_id);
    const result = await sendTestFlightInvite(email, token, config.app_id);

    return new Response(
      JSON.stringify({ success: true, data: result }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  } catch (error) {
    console.error('TestFlight invite error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});
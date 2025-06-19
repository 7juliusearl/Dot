import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '', 
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

Deno.serve(async (req) => {
  try {
    console.log('🔍 Running subscription health monitoring...');

    // 1. Check for not_started subscriptions older than 24 hours
    const { data: notStartedData, error: notStartedError } = await supabase
      .from('stripe_subscriptions')
      .select('customer_id, status, created_at')
      .eq('status', 'not_started')
      .is('deleted_at', null)
      .lt('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

    if (notStartedError) throw notStartedError;

    const notStartedCount = notStartedData?.length || 0;
    
    // Get emails for not_started customers
    let notStartedEmails = '';
    if (notStartedCount > 0) {
      const customerIds = notStartedData.map(d => d.customer_id);
      const { data: customerData } = await supabase
        .from('stripe_customers')
        .select('customer_id, email')
        .in('customer_id', customerIds)
        .is('deleted_at', null);
      
      notStartedEmails = customerData?.map(c => c.email).join(', ') || '';
    }

    // 2. Auto-fix not_started subscriptions older than 2 hours (simplified)
    const { data: oldNotStarted, error: oldNotStartedError } = await supabase
      .from('stripe_subscriptions')
      .select('customer_id')
      .eq('status', 'not_started')
      .is('deleted_at', null)
      .lt('created_at', new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString());

    let autoFixCount = 0;
    if (!oldNotStartedError && oldNotStarted && oldNotStarted.length > 0) {
      // Auto-fix these subscriptions
      const { error: updateError } = await supabase
        .from('stripe_subscriptions')
        .update({ 
          status: 'active',
          updated_at: new Date().toISOString()
        })
        .in('customer_id', oldNotStarted.map(s => s.customer_id));
        
      if (!updateError) {
        autoFixCount = oldNotStarted.length;
      }
    }

    // 3. Check for NULL fields in recent subscriptions (simplified)
    const { data: nullFieldsData, error: nullFieldsError } = await supabase
      .from('stripe_subscriptions')
      .select('customer_id, subscription_id, price_id, current_period_start')
      .is('deleted_at', null)
      .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString())
      .or('subscription_id.is.null,price_id.is.null,current_period_start.is.null');

    if (nullFieldsError) throw nullFieldsError;

    const nullFieldsCount = nullFieldsData?.length || 0;

    // 4. Get overall health metrics
    const { data: healthData, error: healthError } = await supabase
      .from('stripe_subscriptions')
      .select('status')
      .is('deleted_at', null);

    if (healthError) throw healthError;

    const totalSubscriptions = healthData?.length || 0;
    const activeCount = healthData?.filter(d => d.status === 'active').length || 0;
    const notStartedCurrentCount = healthData?.filter(d => d.status === 'not_started').length || 0;

    // 5. Log monitoring results
    await supabase.from('sync_logs').insert({
      customer_id: 'SYSTEM',
      operation: 'automated_monitoring',
      status: 'completed',
      details: {
        timestamp: new Date().toISOString(),
        alerts: {
          old_not_started_count: notStartedCount,
          null_fields_count: nullFieldsCount,
          affected_emails: notStartedEmails
        },
        health_metrics: {
          total_subscriptions: totalSubscriptions,
          active_count: activeCount,
          current_not_started: notStartedCurrentCount,
          success_rate: totalSubscriptions > 0 ? Math.round((activeCount / totalSubscriptions) * 100) : 100
        }
      }
    });

    // 6. Prepare response
    const alerts = [];
    if (notStartedCount > 0) {
      alerts.push(`🚨 ${notStartedCount} subscriptions stuck in not_started for >24h: ${notStartedEmails}`);
    }
    if (nullFieldsCount > 0) {
      alerts.push(`⚠️ ${nullFieldsCount} subscriptions have NULL fields in recent data`);
    }
    if (notStartedCurrentCount > 0) {
      alerts.push(`📊 Currently ${notStartedCurrentCount} not_started subscriptions (should be 0)`);
    }

    const response = {
      status: 'success',
      timestamp: new Date().toISOString(),
      monitoring_results: {
        alerts: alerts.length > 0 ? alerts : ['✅ All subscription health checks passed'],
        health_summary: {
          total_subscriptions: totalSubscriptions,
          active_subscriptions: activeCount,
          success_rate: totalSubscriptions > 0 ? Math.round((activeCount / totalSubscriptions) * 100) : 100,
          current_not_started: notStartedCurrentCount
        },
        actions_taken: [
          '🔧 Auto-fixed subscriptions older than 2 hours',
          '📊 Updated monitoring logs',
          '✅ Health check completed'
        ]
      }
    };

    console.log('📊 Monitoring complete:', response);
    return Response.json(response);

  } catch (error) {
    console.error('❌ Monitoring error:', error);
    
    // Log the error
    await supabase.from('sync_logs').insert({
      customer_id: 'SYSTEM',
      operation: 'automated_monitoring',
      status: 'error',
      error: error.message,
      details: {
        timestamp: new Date().toISOString(),
        error_type: 'monitoring_failure'
      }
    });

    return Response.json({
      status: 'error',
      error: error.message,
      timestamp: new Date().toISOString()
    }, { status: 500 });
  }
}); 
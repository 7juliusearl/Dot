import { useState, useEffect, useRef } from 'react';
import { motion } from 'framer-motion';
import { CheckCircle, AlertCircle, Loader2, RefreshCw } from 'lucide-react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

interface PaymentStatus {
  status: 'loading' | 'success' | 'error' | 'retrying';
  message?: string;
  retryCount?: number;
}

const PaymentVerification = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [status, setStatus] = useState<PaymentStatus>({ status: 'loading', retryCount: 0 });
  const subscriptionRef = useRef<any>(null);
  const hasSucceededRef = useRef(false);

  const verifyPayment = async (retryCount = 0) => {
    try {
      setStatus({ status: retryCount === 0 ? 'loading' : 'retrying', retryCount });

      // First check if we have a valid session
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      
      if (sessionError || !session) {
        throw new Error('Please sign in to continue');
      }

      // Check if we have a valid plan parameter
      const plan = searchParams.get('plan');
      if (!plan || !['yearly', 'lifetime'].includes(plan)) {
        navigate('/payment?plan=lifetime');
        return;
      }

      // Check for completed orders using the same logic as Dashboard
      // First get the customer_id for this user
      const { data: customerData, error: customerError } = await supabase
        .from('stripe_customers')
        .select('customer_id')
        .eq('user_id', session.user.id)
        .single();

      if (customerError || !customerData) {
        console.log('No customer record found for user');
        throw new Error('Customer record not found. Payment may still be processing.');
      }

      // Then get orders for this customer
      const { data: ordersData, error: ordersError } = await supabase
        .from('stripe_orders')
        .select('*')
        .eq('customer_id', customerData.customer_id)
        .eq('status', 'completed')
        .eq('purchase_type', plan)
        .order('created_at', { ascending: false })
        .limit(1);

      if (ordersError) {
        console.error('Orders error:', ordersError);
        throw new Error('Failed to verify order status');
      }

      if (ordersData && ordersData.length > 0) {
        const order = ordersData[0];
        if (plan === 'yearly') {
          handleSuccess('Your yearly subscription is now active! You have full access to the beta program.');
        } else {
          handleSuccess('Your lifetime access is now active! You have permanent access to all features.');
        }
        return;
      }

      // If we reach here, the payment processing is still in progress
      if (retryCount < 8) { // Reduced from 12 to 8 retries (40 seconds total instead of 2 minutes)
        setStatus({ 
          status: 'retrying', 
          message: retryCount < 3 
            ? `Confirming your payment... (${retryCount + 1}/8)` 
            : `Processing your payment... (${retryCount + 1}/8)`,
          retryCount 
        });
        
        // Faster retry intervals: 2s, 3s, 5s, then 5s intervals
        const delay = retryCount < 3 ? [2000, 3000, 5000][retryCount] : 5000;
        setTimeout(() => verifyPayment(retryCount + 1), delay);
      } else {
        // After all retries failed, provide manual sync option
        throw new Error('Payment processing is taking longer than expected. Please try syncing your subscription data manually.');
      }

    } catch (error: any) {
      console.error('Payment verification error:', error);
      setStatus({
        status: 'error',
        message: error.message || 'An error occurred during payment verification',
        retryCount
      });

      // Restore the selected plan in sessionStorage
      const plan = searchParams.get('plan');
      if (plan) {
        sessionStorage.setItem('selectedPlan', plan);
      }
    }
  };

  const handleSuccess = (message: string) => {
    if (hasSucceededRef.current) return; // Prevent multiple success calls
    hasSucceededRef.current = true;
    
    // Clean up real-time subscription
    if (subscriptionRef.current) {
      subscriptionRef.current.unsubscribe();
      subscriptionRef.current = null;
    }
    
    setStatus({
      status: 'success',
      message
    });
    
    setTimeout(() => navigate('/dashboard'), 2000);
  };

  const setupRealTimeSubscription = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) return;

      const plan = searchParams.get('plan');
      if (!plan) return;

      // First get the customer_id to avoid complex subqueries in realtime filter
      const { data: customerData } = await supabase
        .from('stripe_customers')
        .select('customer_id')
        .eq('user_id', session.user.id)
        .single();

      if (!customerData) return;

      // Set up real-time subscription with simple filter
      subscriptionRef.current = supabase
        .channel(`payment-verification-${customerData.customer_id}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT', // Only listen for new orders, not all events
            schema: 'public',
            table: 'stripe_orders',
            filter: `customer_id=eq.${customerData.customer_id}`
          },
          (payload) => {
            console.log('Real-time order update:', payload);
            const newRecord = payload.new as any;
            if (newRecord && newRecord.status === 'completed') {
              if (newRecord.purchase_type === plan) {
                if (plan === 'yearly') {
                  handleSuccess('Your yearly subscription is now active! You have full access to the beta program.');
                } else {
                  handleSuccess('Your lifetime access is now active! You have permanent access to all features.');
                }
              }
            }
          }
        )
        .subscribe();

      // Auto-cleanup after 5 minutes to prevent abandoned subscriptions
      setTimeout(() => {
        if (subscriptionRef.current) {
          subscriptionRef.current.unsubscribe();
          subscriptionRef.current = null;
        }
      }, 5 * 60 * 1000); // 5 minutes
    } catch (error) {
      console.error('Failed to set up real-time subscription:', error);
    }
  };

  const handleManualSync = async () => {
    try {
      setStatus({ status: 'loading', message: 'Syncing your subscription data...' });

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Please sign in to continue');

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/stripe-sync`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          customer_id: 'auto'
        })
      });

      if (!response.ok) {
        throw new Error('Failed to sync subscription data');
      }

      // After manual sync, try verification again
      setTimeout(() => verifyPayment(0), 1000);
    } catch (error: any) {
      setStatus({
        status: 'error',
        message: 'Manual sync failed. Please contact support at hello@dayoftimeline.app'
      });
    }
  };

  useEffect(() => {
    // Set up real-time subscription first, then start verification
    setupRealTimeSubscription();
    verifyPayment();

    // Cleanup function
    const cleanup = () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.unsubscribe();
        subscriptionRef.current = null;
      }
    };

    // Add beforeunload listener to clean up on page refresh/close
    const handleBeforeUnload = () => {
      cleanup();
    };

    window.addEventListener('beforeunload', handleBeforeUnload);

    // Cleanup on unmount
    return () => {
      cleanup();
      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  }, [searchParams, navigate]);

  return (
    <div className="min-h-screen bg-gray-50 py-20">
      <div className="container mx-auto px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="max-w-md mx-auto"
        >
          <div className="bg-white rounded-xl p-8 shadow-lg text-center">
            {status.status === 'loading' && (
              <div className="flex flex-col items-center">
                <Loader2 className="w-12 h-12 text-sky animate-spin mb-4" />
                <h2 className="text-xl font-semibold text-charcoal">
                  {status.message || 'Confirming your payment...'}
                </h2>
                <p className="text-slate mt-2">
                  This should only take a few seconds.
                </p>
              </div>
            )}

            {status.status === 'retrying' && (
              <div className="flex flex-col items-center">
                <RefreshCw className="w-12 h-12 text-blue-500 animate-spin mb-4" />
                <h2 className="text-xl font-semibold text-charcoal">
                  Processing Payment
                </h2>
                <p className="text-slate mt-2">{status.message}</p>
                <p className="text-sm text-gray-500 mt-2">
                  {(status.retryCount || 0) < 3 
                    ? "Almost there..." 
                    : "This can take up to 1 minute to complete."
                  }
                </p>
              </div>
            )}

            {status.status === 'success' && (
              <div className="flex flex-col items-center">
                <CheckCircle className="w-12 h-12 text-green-500 mb-4" />
                <h2 className="text-xl font-semibold text-charcoal">
                  Payment Successful!
                </h2>
                <p className="text-slate mt-2">{status.message}</p>
                <p className="text-sm text-gray-500 mt-2">
                  Redirecting you to your dashboard...
                </p>
              </div>
            )}

            {status.status === 'error' && (
              <div className="flex flex-col items-center">
                <AlertCircle className="w-12 h-12 text-red-500 mb-4" />
                <h2 className="text-xl font-semibold text-charcoal">
                  Payment Verification Failed
                </h2>
                <p className="text-slate mt-2 mb-4">{status.message}</p>
                
                {status.message?.includes('longer than expected') && (
                  <div className="space-y-3 w-full">
                    <button
                      onClick={handleManualSync}
                      className="w-full bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                    >
                      Sync Subscription Data
                    </button>
                    <button
                      onClick={() => navigate('/dashboard')}
                      className="w-full bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium"
                    >
                      Go to Dashboard
                    </button>
                  </div>
                )}
                
                <button
                  onClick={() => navigate('/payment')}
                  className="mt-3 bg-gray-600 text-white px-6 py-2 rounded-lg hover:bg-gray-700 transition-colors"
                >
                  Return to Payment Page
                </button>
              </div>
            )}
          </div>
        </motion.div>
      </div>
    </div>
  );
};

export default PaymentVerification;
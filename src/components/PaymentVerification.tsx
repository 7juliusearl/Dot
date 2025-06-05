import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { createClient } from '@supabase/supabase-js';
import { motion } from 'framer-motion';
import { Loader2, AlertCircle, CheckCircle, RefreshCw } from 'lucide-react';

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

  const verifyPayment = async (retryCount = 0) => {
    try {
      setStatus({ status: 'loading', retryCount });

      // First check if we have a valid session
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      
      if (sessionError || !session) {
        throw new Error('Please sign in to continue');
      }

      // Check if we have a valid plan parameter
      const plan = searchParams.get('plan');
      if (!plan || !['monthly', 'lifetime'].includes(plan)) {
        throw new Error('Invalid payment plan');
      }

      // For monthly subscriptions, check subscription status
      if (plan === 'monthly') {
        const { data: subscription, error: subscriptionError } = await supabase
          .from('stripe_user_subscriptions')
          .select('*')
          .maybeSingle();

        if (subscriptionError) {
          console.error('Subscription error:', subscriptionError);
          throw new Error('Failed to verify subscription status');
        }

        if (subscription?.subscription_status === 'active') {
          setStatus({
            status: 'success',
            message: 'Your monthly subscription has been activated!'
          });
          
          setTimeout(() => navigate('/dashboard'), 2000);
          return;
        }
      }

      // For lifetime purchases, check orders
      if (plan === 'lifetime') {
        const { data: orders, error: ordersError } = await supabase
          .from('stripe_user_orders')
          .select('*')
          .eq('status', 'completed')
          .eq('purchase_type', 'lifetime')
          .maybeSingle();

        if (ordersError) {
          console.error('Orders error:', ordersError);
          throw new Error('Failed to verify order status');
        }

        if (orders) {
          setStatus({
            status: 'success',
            message: 'Your lifetime access has been confirmed!'
          });
          
          setTimeout(() => navigate('/dashboard'), 2000);
          return;
        }
      }

      // If we reach here, the payment processing is still in progress
      if (retryCount < 12) { // Retry for up to 2 minutes (12 retries * 10 seconds)
        setStatus({ 
          status: 'retrying', 
          message: `Processing your payment... (${retryCount + 1}/12)`,
          retryCount 
        });
        
        setTimeout(() => verifyPayment(retryCount + 1), 10000); // Wait 10 seconds before retry
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
      setTimeout(() => verifyPayment(0), 2000);
    } catch (error: any) {
      setStatus({
        status: 'error',
        message: 'Manual sync failed. Please contact support at hello@dayoftimeline.app'
      });
    }
  };

  useEffect(() => {
    verifyPayment();
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
                  {status.message || 'Verifying your payment...'}
                </h2>
                <p className="text-slate mt-2">
                  Please wait while we confirm your payment status.
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
                  This can take up to 2 minutes to complete.
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
import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { createClient } from '@supabase/supabase-js';
import { motion } from 'framer-motion';
import { Loader2, AlertCircle, CheckCircle } from 'lucide-react';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

interface PaymentStatus {
  status: 'loading' | 'success' | 'error';
  message?: string;
}

const PaymentVerification = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [status, setStatus] = useState<PaymentStatus>({ status: 'loading' });

  useEffect(() => {
    const verifyPayment = async () => {
      try {
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

        // Check if the user already has an active subscription or lifetime access
        const { data: subscription, error: subscriptionError } = await supabase
          .from('stripe_user_subscriptions')
          .select('*')
          .maybeSingle();

        if (subscriptionError) {
          throw new Error('Failed to verify subscription status');
        }

        // Check orders for lifetime purchases
        const { data: orders, error: ordersError } = await supabase
          .from('stripe_user_orders')
          .select('*')
          .eq('status', 'completed')
          .eq('purchase_type', 'lifetime')
          .maybeSingle();

        if (ordersError) {
          throw new Error('Failed to verify order status');
        }

        if (subscription?.subscription_status === 'active' || orders) {
          setStatus({
            status: 'success',
            message: 'Your payment has been processed successfully!'
          });
          
          // Redirect to dashboard after 2 seconds
          setTimeout(() => {
            navigate('/dashboard');
          }, 2000);
        } else {
          throw new Error('Payment verification failed');
        }
      } catch (error: any) {
        setStatus({
          status: 'error',
          message: error.message || 'An error occurred during payment verification'
        });

        // Restore the selected plan in sessionStorage
        const plan = searchParams.get('plan');
        if (plan) {
          sessionStorage.setItem('selectedPlan', plan);
        }
      }
    };

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
                  Verifying your payment...
                </h2>
                <p className="text-slate mt-2">
                  Please wait while we confirm your payment status.
                </p>
              </div>
            )}

            {status.status === 'success' && (
              <div className="flex flex-col items-center">
                <CheckCircle className="w-12 h-12 text-green-500 mb-4" />
                <h2 className="text-xl font-semibold text-charcoal">
                  Payment Successful!
                </h2>
                <p className="text-slate mt-2">
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
                <p className="text-slate mt-2">{status.message}</p>
                <button
                  onClick={() => navigate('/payment')}
                  className="mt-6 bg-sky text-slate px-6 py-2 rounded-lg hover:shadow-md transition-shadow"
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
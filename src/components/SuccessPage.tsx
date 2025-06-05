import { useEffect } from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { CheckCircle, ExternalLink, AlertTriangle } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

const SuccessPage = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const navigate = useNavigate();

  const testFlightLink = "https://testflight.apple.com/join/cGYTUPH1";
  const disclaimer = "This TestFlight link is for your personal use only. Sharing this public link is strictly prohibited. If we discover that this link has been shared, your beta access program will be immediately canceled without any refunds.";

  useEffect(() => {
    const verifyPayment = async () => {
      try {
        // Check if we have a valid session
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        
        if (sessionError || !session) {
          navigate('/');
          return;
        }

        // Check if the user has an active subscription or lifetime access
        const { data: orders, error: ordersError } = await supabase
          .from('stripe_orders')
          .select('*')
          .eq('status', 'completed')
          .order('created_at', { ascending: false })
          .limit(1);

        if (ordersError || !orders?.length) {
          navigate('/payment');
          return;
        }
      } catch (error) {
        console.error('Payment verification error:', error);
        navigate('/payment');
      }
    };

    verifyPayment();
  }, [navigate]);

  return (
    <div className="min-h-screen bg-gray-50 py-20" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="max-w-2xl mx-auto"
        >
          <div className="bg-white rounded-xl p-8 shadow-lg text-center">
            <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-6" />
            <h1 className="text-3xl font-bold text-charcoal mb-4">Payment Successful!</h1>
            <p className="text-slate text-lg mb-8">
              Thank you for your purchase. You now have access to the Day of Timeline beta program.
            </p>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-8">
              <h2 className="text-xl font-semibold text-blue-800 mb-4">Your TestFlight Access</h2>
              <p className="text-blue-700 mb-4">
                Click the link below to join the TestFlight beta and download the app:
              </p>
              <a
                href={testFlightLink}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center bg-sky text-slate px-6 py-3 rounded-full font-medium hover:shadow-lg transition-shadow"
              >
                Join TestFlight Beta <ExternalLink className="ml-2 w-5 h-5" />
              </a>
            </div>

            <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-left">
              <div className="flex items-start">
                <AlertTriangle className="text-red-600 w-5 h-5 mt-1 mr-3 flex-shrink-0" />
                <div>
                  <h3 className="text-lg font-semibold text-red-800 mb-2">Important Disclaimer:</h3>
                  <p className="text-red-700">{disclaimer}</p>
                </div>
              </div>
            </div>

            <button
              onClick={() => navigate('/dashboard')}
              className="mt-8 bg-sky text-slate px-8 py-3 rounded-full font-medium hover:shadow-lg transition-shadow"
            >
              Go to Dashboard
            </button>
          </div>
        </motion.div>
      </div>
    </div>
  );
};

export default SuccessPage;
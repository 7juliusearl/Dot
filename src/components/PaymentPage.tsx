import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { Shield, Star, Clock, AlertTriangle, Check, Mail } from 'lucide-react';
import { products } from '../stripe-config';
import { createClient } from '@supabase/supabase-js';
import { useNavigate, useSearchParams } from 'react-router-dom';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

interface PaymentPageProps {
  onAuthFailure: () => void;
}

const PaymentPage = ({ onAuthFailure }: PaymentPageProps) => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [selectedPlan, setSelectedPlan] = useState<'lifetime' | 'monthly'>('lifetime');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const plan = searchParams.get('plan');
    if (plan === 'lifetime' || plan === 'monthly') {
      setSelectedPlan(plan);
    }
    setError(null);

    // Add entry to browser history to handle back button correctly
    window.history.replaceState(
      { ...window.history.state, page: 'payment', plan: plan || 'lifetime' },
      '',
      window.location.href
    );
  }, [searchParams]);

  // Handle browser back button
  useEffect(() => {
    const handlePopState = (event: PopStateEvent) => {
      // If user navigates back from external site (like Stripe), 
      // ensure they land on a valid page
      if (event.state?.page === 'payment') {
        // Stay on payment page
        return;
      }
      // Let normal navigation happen
    };

    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  const handlePayment = async () => {
    try {
      setIsLoading(true);
      setError(null);

      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      
      if (sessionError) {
        await onAuthFailure();
        throw new Error('Your session has expired. Please sign in again.');
      }

      if (!session) {
        throw new Error('Please sign in to continue');
      }

      const product = selectedPlan === 'lifetime' ? products.lifetime : products.monthly;

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/stripe-checkout`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          price_id: product.priceId,
          mode: product.mode
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to create checkout session');
      }

      const { url } = await response.json();
      if (url) {
        window.location.href = url;
      } else {
        throw new Error('No checkout URL received');
      }
    } catch (err: any) {
      console.error('Payment error:', err);
      setError(err.message || 'Failed to process payment');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 py-20" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="max-w-3xl mx-auto"
        >
          <div className="text-center mb-12">
            <h1 className="text-3xl md:text-4xl font-bold text-charcoal mb-4">
              Beta Access Program
            </h1>
            <div className="bg-sky bg-opacity-20 rounded-xl p-6 mb-8">
              <h2 className="text-2xl font-bold text-charcoal mb-2">Early Access Pricing</h2>
              <p className="text-slate">Limited spots available due to high demand</p>
            </div>

            <div className="bg-gradient-to-r from-blue-50 to-sky-50 border border-blue-100 rounded-xl p-8 mb-8 shadow-sm">
              <div className="flex items-center justify-center mb-4">
                <div className="bg-blue-100 rounded-full p-3">
                  <Mail className="text-blue-600 w-6 h-6" />
                </div>
              </div>
              <h3 className="text-xl font-semibold text-blue-900 mb-2">TestFlight Access</h3>
              <p className="text-blue-800">
                After your payment is processed, please allow 10-20 minutes for us to manually send your TestFlight invite. If you haven't received the invite within 24 hours, please email us at hello@dayoftimeline.app and we'll get it sorted right away.
              </p>
              <p className="text-blue-700 text-sm mt-2">
                Pro tip: Add hello@dayoftimeline.app to your contacts to ensure delivery
              </p>
            </div>

            <p className="text-lg font-medium text-charcoal mb-6">Select Your Plan</p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 mb-8">
            {/* Lifetime Plan */}
            <div 
              className={`bg-white rounded-xl p-8 shadow-lg transition-all cursor-pointer ${
                selectedPlan === 'lifetime' 
                  ? 'border-4 border-sky ring-4 ring-sky ring-opacity-20 shadow-xl transform scale-[1.02]' 
                  : 'border-2 border-transparent hover:border-sky hover:shadow-xl'
              }`}
              onClick={() => setSelectedPlan('lifetime')}
            >
              <div className="text-center mb-8">
                <h3 className="text-xl font-bold text-charcoal mb-4">Lifetime Access</h3>
                <div className="mb-4">
                  <span className="text-slate line-through text-lg">$99.99</span>
                  <div className="flex items-center justify-center gap-2">
                    <span className="text-4xl font-bold text-charcoal">$27.99</span>
                    <span className="text-slate">one-time</span>
                  </div>
                  <span className="inline-block bg-green-100 text-green-800 text-sm px-3 py-1 rounded-full mt-2">
                    72% OFF FOR BETA USERS!
                  </span>
                </div>
              </div>

              <ul className="space-y-4 mb-8">
                <li className="flex items-center text-slate">
                  <Check size={18} className="text-sky mr-2 flex-shrink-0" />
                  <span>Lifetime access to all features</span>
                </li>
                <li className="flex items-center text-slate">
                  <Check size={18} className="text-sky mr-2 flex-shrink-0" />
                  <span>Early access to beta features</span>
                </li>
                <li className="flex items-center text-slate">
                  <Check size={18} className="text-sky mr-2 flex-shrink-0" />
                  <span>All future updates included</span>
                </li>
              </ul>
            </div>

            {/* Monthly Plan */}
            <div 
              className={`bg-white rounded-xl p-8 shadow-lg transition-all cursor-pointer ${
                selectedPlan === 'monthly' 
                  ? 'border-4 border-sky ring-4 ring-sky ring-opacity-20 shadow-xl transform scale-[1.02]' 
                  : 'border-2 border-transparent hover:border-sky hover:shadow-xl'
              }`}
              onClick={() => setSelectedPlan('monthly')}
            >
              <div className="text-center mb-8">
                <h3 className="text-xl font-bold text-charcoal mb-4">Monthly Access</h3>
                <div className="mb-4">
                  <span className="text-slate line-through text-lg">$7.99</span>
                  <div className="flex items-center justify-center gap-2">
                    <span className="text-4xl font-bold text-charcoal">$3.99</span>
                    <span className="text-slate">/month</span>
                  </div>
                  <span className="inline-block bg-green-100 text-green-800 text-sm px-3 py-1 rounded-full mt-2">
                    BETA PRICE
                  </span>
                </div>
              </div>

              <ul className="space-y-4 mb-8">
                <li className="flex items-center text-slate">
                  <Check size={18} className="text-sky mr-2 flex-shrink-0" />
                  <span>Flexible monthly billing</span>
                </li>
                <li className="flex items-center text-slate">
                  <Check size={18} className="text-sky mr-2 flex-shrink-0" />
                  <span>Price locked at $3.99/month</span>
                </li>
                <li className="flex items-center text-slate">
                  <Check size={18} className="text-sky mr-2 flex-shrink-0" />
                  <span>Cancel anytime</span>
                </li>
              </ul>
            </div>
          </div>

          <div className="bg-white rounded-xl p-8 shadow-lg mb-8">
            <div className="space-y-6 mb-8">
              <div className="flex items-start">
                <Shield className="text-sky w-6 h-6 mt-1 mr-3 flex-shrink-0" />
                <p className="text-slate">
                  Your contribution helps support development and ensures you get the best possible experience.
                </p>
              </div>
              <div className="flex items-start">
                <Star className="text-sky w-6 h-6 mt-1 mr-3 flex-shrink-0" />
                <p className="text-slate">
                  Get immediate access to all beta features and help shape the future of wedding day organization.
                </p>
              </div>
              <div className="flex items-start">
                <Clock className="text-sky w-6 h-6 mt-1 mr-3 flex-shrink-0" />
                <p className="text-slate">
                  Lock in the best possible price before our official App Store launch.
                </p>
              </div>
            </div>

            <button 
              className={`w-full bg-sky text-slate py-3 rounded-lg font-medium transition-all ${
                isLoading ? 'opacity-75 cursor-not-allowed' : 'hover:shadow-lg'
              }`}
              onClick={handlePayment}
              disabled={isLoading}
            >
              {isLoading ? 'Processing...' : selectedPlan === 'lifetime' 
                ? 'Get Lifetime Access - $27.99' 
                : 'Start Monthly Plan - $3.99/month'}
            </button>
            {error && (
              <p className="mt-4 text-red-600 text-sm">{error}</p>
            )}
          </div>

          <div className="bg-amber-50 border border-amber-100 rounded-xl p-6">
            <div className="flex items-start">
              <AlertTriangle className="text-amber-500 w-6 h-6 mt-1 mr-3 flex-shrink-0" />
              <div>
                <h3 className="font-semibold text-amber-800 mb-2">Beta Product Disclaimer</h3>
                <p className="text-amber-700 mb-4">
                  Please note that this is a beta product. Some features may be broken or missing as we continue development. By joining the beta program, you acknowledge that you're using pre-release software that may change significantly before final release. We really appreciate your patience and understanding as we work on making this the best product possible! Thank you :)
                </p>
                <ul className="space-y-2 text-amber-700">
                  <li>• <span className="font-semibold">Refund Policy:</span> Refunds are only available within 24 hours of purchase</li>
                  <li>• <span className="font-semibold">Platform Support:</span> Currently available for iOS only - Android support is not available</li>
                </ul>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
};

export default PaymentPage;
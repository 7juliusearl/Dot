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
  const [selectedPlan, setSelectedPlan] = useState<'lifetime' | 'yearly'>('lifetime');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const plan = searchParams.get('plan');
    if (plan === 'lifetime' || plan === 'yearly') {
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
        // For guest checkout, redirect to sign in first
        navigate('/signin?redirect=/payment&plan=' + selectedPlan);
        return;
      }

      const product = selectedPlan === 'lifetime' ? products.lifetime : products.yearly;

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
            <div className="bg-gradient-to-r from-red-50 to-orange-50 border border-red-200 rounded-xl p-6 mb-8">
              <h2 className="text-2xl font-bold text-red-800 mb-2">🔥 Final Batch: Lifetime Access Ending Soon</h2>
              <p className="text-red-700 font-medium">This is the last opportunity to secure lifetime access at this price. After this batch fills up, we're transitioning to yearly pricing to ensure sustainable development.</p>
            </div>

            <div className="bg-blue-50 border border-blue-200 rounded-xl p-6 mb-8">
              <div className="flex items-start">
                <Clock className="text-blue-600 w-6 h-6 mt-1 mr-3 flex-shrink-0" />
                <div>
                  <h3 className="font-semibold text-blue-800 mb-2">🔄 Pricing Transition Notice</h3>
                  <p className="text-blue-700 mb-3">
                    <strong>We're transitioning our pricing model to ensure sustainable development.</strong> This is the final batch where lifetime access is available.
                  </p>
                  <ul className="space-y-2 text-blue-700 mb-3">
                    <li>• <span className="font-semibold">Current Batch:</span> Choose between Lifetime ($99.99) or Yearly ($27.99)</li>
                    <li>• <span className="font-semibold">Next Batch:</span> Only yearly pricing will be available</li>
                    <li>• <span className="font-semibold">Grandfathering:</span> Your chosen plan rate is locked forever</li>
                  </ul>
                  <p className="text-blue-700 text-sm">
                    This change allows us to provide consistent updates and support while honoring our early supporters with the best possible rates.
                  </p>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-r from-blue-50 to-sky-50 border border-blue-100 rounded-xl p-8 mb-8 shadow-sm">
              <div className="flex items-center justify-center mb-4">
                <div className="bg-blue-100 rounded-full p-3">
                  <Mail className="text-blue-600 w-6 h-6" />
                </div>
              </div>
              <h3 className="text-xl font-semibold text-blue-900 mb-2">App Access</h3>
              <p className="text-blue-800">
                Once your payment is complete, you can find your download link in your account dashboard.
              </p>
            </div>

            <p className="text-lg font-medium text-charcoal mb-6">Choose Your Access Plan</p>
          </div>

          <div className="grid md:grid-cols-2 gap-4 mb-6">
            {/* Lifetime Plan */}
            <div 
              className={`bg-white rounded-lg p-5 shadow-lg transition-all cursor-pointer relative overflow-visible ${
                selectedPlan === 'lifetime' 
                  ? 'border-3 border-purple-500 ring-4 ring-purple-300 ring-opacity-40 shadow-xl transform scale-[1.02]' 
                  : 'border-2 border-purple-300 hover:border-purple-400 hover:shadow-xl hover:ring-2 hover:ring-purple-200 hover:ring-opacity-30'
              }`}
              onClick={() => setSelectedPlan('lifetime')}
            >
              {/* Premium badge */}
              <div className="absolute -top-1 -right-1 bg-gradient-to-r from-purple-500 to-indigo-600 text-white px-2 py-1 rounded-full text-xs font-bold transform rotate-12 shadow-lg">
                LAST CHANCE
              </div>
              <div className="text-center mb-4">
                <h3 className="text-lg font-bold text-charcoal mb-1">Lifetime Access</h3>
                <div className="mb-3">
                  <div className="flex items-center justify-center gap-1">
                    <span className="text-3xl font-bold text-charcoal">$99.99</span>
                    <span className="text-slate text-sm">one-time</span>
                  </div>
                  <span className="inline-block bg-gradient-to-r from-purple-500 to-indigo-600 text-white text-xs px-2 py-1 rounded-full mt-1 font-bold">
                    FINAL BATCH ONLY
                  </span>
                </div>
              </div>

              <ul className="space-y-2 mb-4">
                <li className="flex items-center">
                  <Check className="text-purple-500 w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Lifetime access to all features</span>
                </li>
                <li className="flex items-center">
                  <Check className="text-purple-500 w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Never pay again - grandfathered forever</span>
                </li>
                <li className="flex items-center">
                  <Check className="text-purple-500 w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">All future updates included</span>
                </li>
                <li className="flex items-center">
                  <Check className="text-purple-500 w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Instant app access</span>
                </li>
              </ul>
            </div>

            {/* Yearly Plan */}
            <div 
              className={`bg-white rounded-lg p-5 shadow-lg transition-all cursor-pointer relative overflow-visible ${
                selectedPlan === 'yearly' 
                  ? 'border-3 border-sky ring-4 ring-sky ring-opacity-30 shadow-xl transform scale-[1.02]' 
                  : 'border-2 border-gray-200 hover:border-sky hover:shadow-xl hover:ring-2 hover:ring-sky hover:ring-opacity-20'
              }`}
              onClick={() => setSelectedPlan('yearly')}
            >
              <div className="absolute -top-1 -right-1 bg-gradient-to-r from-emerald-500 to-green-600 text-white px-2 py-1 rounded-full text-xs font-bold transform rotate-12 shadow-lg">
                FOUNDING RATE
              </div>
              <div className="text-center mb-4">
                <h3 className="text-lg font-bold text-charcoal mb-1">Yearly Access</h3>
                <div className="mb-3">
                  <div className="flex items-center justify-center gap-1">
                    <span className="text-3xl font-bold text-charcoal">$27.99</span>
                    <span className="text-slate text-sm">/year</span>
                  </div>
                  <span className="inline-block bg-green-100 text-green-800 text-xs px-2 py-1 rounded-full mt-1 font-medium">
                    FOUNDING MEMBER PRICING
                  </span>
                </div>
              </div>

              <ul className="space-y-2 mb-4">
                <li className="flex items-center">
                  <Check className="text-sky w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Full access to all features</span>
                </li>
                <li className="flex items-center">
                  <Check className="text-sky w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Founding member rate - locked forever</span>
                </li>
                <li className="flex items-center">
                  <Check className="text-sky w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Cancel anytime</span>
                </li>
                <li className="flex items-center">
                  <Check className="text-sky w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Instant app access</span>
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
              className={`w-full bg-gradient-to-r from-purple-600 to-indigo-600 text-white py-4 rounded-lg font-semibold text-lg transition-all shadow-lg ${
                isLoading ? 'opacity-75 cursor-not-allowed' : 'hover:shadow-xl hover:scale-[1.02] transform'
              }`}
              onClick={handlePayment}
              disabled={isLoading}
            >
              {isLoading ? 'Processing...' : selectedPlan === 'lifetime' 
                ? 'Secure Lifetime Access - $99.99' 
                : 'Start Yearly Access - $27.99/year'}
            </button>
            {error && (
              <p className="mt-4 text-red-600 text-sm">{error}</p>
            )}
          </div>

          <div className="bg-red-50 border border-red-200 rounded-xl p-6 mb-6">
            <div className="flex items-start">
              <AlertTriangle className="text-red-600 w-6 h-6 mt-1 mr-3 flex-shrink-0" />
              <div>
                <h3 className="font-semibold text-red-800 mb-2">⚠️ Important Payment Notice</h3>
                <p className="text-red-700 mb-3">
                  <strong>If your payment fails or encounters any issues, please DO NOT attempt to pay again.</strong> Multiple payment attempts can cause technical issues with your account.
                </p>
                <p className="text-red-700 mb-3">
                  Instead, please contact us immediately:
                </p>
                <ul className="space-y-2 text-red-700 mb-3">
                  <li>• <span className="font-semibold">Email:</span> hello@dayoftimeline.app</li>
                  <li>• <span className="font-semibold">Instagram:</span> @spiritmadevisuals</li>
                  <li>• <span className="font-semibold">TikTok:</span> @spiritmadevisuals</li>
                </ul>
                <p className="text-red-700 text-sm">
                  We'll resolve any payment issues quickly and manually. Thank you for your understanding!
                </p>
              </div>
            </div>
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
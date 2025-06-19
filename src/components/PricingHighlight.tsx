import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { Clock, Check, ArrowRight } from 'lucide-react';

const PricingHighlight = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  return (
    <section className="py-10 bg-gradient-to-r from-purple-50 to-indigo-50" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="max-w-3xl mx-auto"
        >
          {/* Urgency Header */}
          <div className="text-center mb-6">
            <div className="inline-flex items-center bg-red-100 text-red-800 px-3 py-1 rounded-full text-xs font-bold mb-3">
              <Clock className="w-3 h-3 mr-1" />
              Final Batch: Lifetime Access Ending
            </div>
            <h2 className="text-2xl md:text-3xl font-bold text-charcoal mb-3">
              Last Chance for Lifetime Access
            </h2>
            <p className="text-lg text-slate">
              After this batch, we're transitioning to yearly pricing. Choose your plan and lock in your rate forever.
            </p>
          </div>

          {/* Pricing Cards */}
          <div className="grid md:grid-cols-2 gap-4 mb-6">
            {/* Lifetime - Featured */}
            <div className="bg-white rounded-lg p-5 shadow-lg border-3 border-purple-500 relative overflow-visible">
              <div className="absolute -top-1 -right-1 bg-gradient-to-r from-purple-500 to-indigo-600 text-white px-2 py-1 rounded-full text-xs font-bold transform rotate-12 shadow-lg">
                LAST CHANCE
              </div>
              
              <div className="text-center mb-4">
                <h3 className="text-lg font-bold text-charcoal mb-1">Lifetime Access</h3>
                <div className="mb-3">
                  <span className="text-slate line-through text-sm">$299 App Store Price</span>
                  <div className="flex items-center justify-center gap-1">
                    <span className="text-3xl font-bold text-charcoal">$99.99</span>
                    <span className="text-slate text-sm">one-time</span>
                  </div>
                  <span className="inline-block bg-gradient-to-r from-purple-500 to-indigo-600 text-white text-xs px-2 py-1 rounded-full mt-1 font-bold">
                    BETA + APP STORE ACCESS
                  </span>
                </div>
              </div>

              <ul className="space-y-2 mb-4">
                <li className="flex items-center">
                  <Check className="text-purple-500 w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Beta access now + App Store version</span>
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
                <li className="flex items-center">
                  <Check className="text-purple-500 w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm font-medium">14-day money-back guarantee</span>
                </li>
              </ul>

              <button 
                onClick={() => window.location.href = '/payment?plan=lifetime'}
                className="w-full bg-gradient-to-r from-purple-600 to-indigo-600 text-white py-2 rounded-lg font-medium hover:shadow-lg transition-all flex items-center justify-center text-sm"
              >
                Get Lifetime Access
                <ArrowRight className="w-4 h-4 ml-1" />
              </button>
            </div>

            {/* Yearly Option */}
            <div className="bg-white rounded-lg p-5 shadow-lg border-2 border-gray-200 relative overflow-visible">
              <div className="absolute -top-1 -right-1 bg-gradient-to-r from-emerald-500 to-green-600 text-white px-2 py-1 rounded-full text-xs font-bold transform rotate-12 shadow-lg">
                FOUNDING RATE
              </div>
              <div className="text-center mb-4">
                <h3 className="text-lg font-bold text-charcoal mb-1">Yearly Access</h3>
                <div className="mb-3">
                  <span className="text-slate line-through text-sm">$99/year App Store Price</span>
                  <div className="flex items-center justify-center gap-1">
                    <span className="text-3xl font-bold text-charcoal">$27.99</span>
                    <span className="text-slate text-sm">/year</span>
                  </div>
                  <span className="inline-block bg-green-100 text-green-800 text-xs px-2 py-1 rounded-full mt-1 font-medium">
                    BETA + APP STORE ACCESS
                  </span>
                </div>
              </div>

              <ul className="space-y-2 mb-4">
                <li className="flex items-center">
                  <Check className="text-sky w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm">Beta access now + App Store version</span>
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
                <li className="flex items-center">
                  <Check className="text-sky w-4 h-4 mr-2 flex-shrink-0" />
                  <span className="text-slate text-sm font-medium">30-day money-back guarantee</span>
                </li>
              </ul>

              <button 
                onClick={() => window.location.href = '/payment?plan=yearly'}
                className="w-full bg-gradient-to-r from-sky-500 to-blue-600 text-white py-2 rounded-lg font-medium hover:shadow-lg transition-all flex items-center justify-center text-sm"
              >
                Get Yearly Access
                <ArrowRight className="w-4 h-4 ml-1" />
              </button>
            </div>
          </div>

          {/* Trust Indicators */}
          <div className="text-center">
            <div className="inline-flex items-center gap-4 text-xs text-slate">
              <div className="flex items-center">
                <svg className="w-3 h-3 text-green-500 mr-1" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
                Secure Payment
              </div>
              <div className="flex items-center">
                <svg className="w-3 h-3 text-green-500 mr-1" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
                Instant Access
              </div>
              <div className="flex items-center">
                <svg className="w-3 h-3 text-green-500 mr-1" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
                40+ Photographers Using
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
};

export default PricingHighlight; 
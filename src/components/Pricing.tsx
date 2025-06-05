import { useState } from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { Check, X } from 'lucide-react';
import { PricingPlan } from '../types';

const Pricing = () => {
  const [annually, setAnnually] = useState(true);
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const plans: PricingPlan[] = [
    {
      id: 1,
      name: 'Solo Creator',
      price: annually ? '$19' : '$29',
      features: {
        included: [
          'Smart task lists',
          'Timeline templates',
          'Basic reminders',
          'Local storage',
          '5GB cloud backup'
        ],
        excluded: [
          'Team coordination',
          'Contractor management',
          'Location sharing',
          'Custom categories'
        ]
      }
    },
    {
      id: 2,
      name: 'Professional',
      price: annually ? '$49' : '$69',
      popular: true,
      features: {
        included: [
          'Everything in Solo Creator',
          'Team coordination',
          'Custom categories',
          'Location sharing',
          'Priority support',
          '50GB cloud backup'
        ],
        excluded: [
          'Contractor management',
          'Advanced analytics'
        ]
      }
    },
    {
      id: 3,
      name: 'Studio',
      price: annually ? '$99' : '$129',
      features: {
        included: [
          'Everything in Professional',
          'Contractor management',
          'Advanced analytics',
          'Unlimited cloud backup',
          'Dedicated support',
          'Custom branding'
        ],
        excluded: []
      }
    }
  ];

  return (
    <section id="pricing" className="py-20 bg-white" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <span className="text-sm font-bold tracking-wider text-sky uppercase">Pricing</span>
          <h2 className="mt-2 text-3xl md:text-4xl font-bold text-charcoal">Professional Organization, Made Simple</h2>
          <p className="mt-4 text-slate max-w-2xl mx-auto">
            Choose the perfect plan for your needs. All plans include our core organization features with different levels of team coordination and support.
          </p>
          
          <div className="mt-8 inline-flex items-center p-1 bg-silver bg-opacity-20 rounded-full">
            <button
              onClick={() => setAnnually(true)}
              className={`px-6 py-2 rounded-full text-sm font-medium transition-all ${
                annually
                  ? 'bg-white shadow-sm text-charcoal'
                  : 'text-slate hover:text-sky'
              }`}
            >
              Annually <span className="text-xs text-sky font-bold">-20%</span>
            </button>
            <button
              onClick={() => setAnnually(false)}
              className={`px-6 py-2 rounded-full text-sm font-medium transition-all ${
                !annually
                  ? 'bg-white shadow-sm text-charcoal'
                  : 'text-slate hover:text-sky'
              }`}
            >
              Monthly
            </button>
          </div>
        </motion.div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 max-w-5xl mx-auto">
          {plans.map((plan, index) => (
            <motion.div
              key={plan.id}
              initial={{ opacity: 0, y: 20 }}
              animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
              transition={{ duration: 0.6, delay: 0.1 * index }}
              className={`bg-white rounded-2xl shadow-lg overflow-hidden border border-silver ${
                plan.popular ? 'ring-2 ring-sky transform -translate-y-4 md:scale-105' : ''
              }`}
            >
              {plan.popular && (
                <div className="bg-sky text-slate text-center text-sm font-medium py-1">
                  Most Popular
                </div>
              )}
              
              <div className="p-8">
                <h3 className="text-xl font-bold text-charcoal mb-2">{plan.name}</h3>
                <div className="flex items-end mb-6">
                  <span className="text-4xl font-bold text-charcoal">{plan.price}</span>
                  <span className="text-slate ml-2">/ {annually ? 'year' : 'month'}</span>
                </div>
                
                <ul className="space-y-4 mb-8">
                  {plan.features.included.map((feature, i) => (
                    <li key={i} className="flex items-center text-slate">
                      <Check size={18} className="text-sky mr-2 flex-shrink-0" />
                      <span>{feature}</span>
                    </li>
                  ))}
                  
                  {plan.features.excluded.map((feature, i) => (
                    <li key={i} className="flex items-center text-silver">
                      <X size={18} className="text-silver mr-2 flex-shrink-0" />
                      <span>{feature}</span>
                    </li>
                  ))}
                </ul>
                
                <button
                  className={`w-full py-3 rounded-lg font-medium transition-all ${
                    plan.popular
                      ? 'bg-sky text-slate hover:shadow-lg'
                      : 'bg-silver bg-opacity-20 text-slate hover:bg-sky hover:text-slate'
                  }`}
                >
                  {plan.popular ? 'Get Started' : 'Choose Plan'}
                </button>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Pricing;
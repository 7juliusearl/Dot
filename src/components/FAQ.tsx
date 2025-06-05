import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { ChevronDown, ChevronUp } from 'lucide-react';
import { FAQ } from '../types';

const FAQSection = () => {
  const [openItems, setOpenItems] = useState<number[]>([]);
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const faqs: FAQ[] = [
    {
      id: 1,
      question: 'Can I try before I subscribe?',
      answer: 'Absolutely! We offer a 14-day free trial on all plans with no credit card required. You\'ll have full access to all features included in your selected plan to ensure it meets your needs before committing.'
    },
    {
      id: 2,
      question: 'What payment methods do you accept?',
      answer: 'We accept all major credit cards including Visa, Mastercard, American Express, and Discover. We also support payment through PayPal and Apple Pay. For Enterprise plans, we can arrange invoicing and bank transfers.'
    },
    {
      id: 3,
      question: 'Can I change my plan later?',
      answer: 'Yes, you can upgrade or downgrade your plan at any time. When upgrading, we\'ll prorate the difference and apply it to your new subscription. When downgrading, the new rate will apply at the start of your next billing cycle.'
    },
    {
      id: 4,
      question: 'Is there a long-term contract?',
      answer: 'No long-term contracts required! Our monthly plans can be canceled anytime. Annual plans offer significant savings and can be refunded on a prorated basis if canceled early (within the first 30 days for a full refund).'
    }
  ];

  const toggleItem = (id: number) => {
    setOpenItems(prev => 
      prev.includes(id) 
        ? prev.filter(item => item !== id) 
        : [...prev, id]
    );
  };

  return (
    <section className="py-20 bg-gray-50" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <span className="text-sm font-bold tracking-wider text-teal-600 uppercase">FAQ</span>
          <h2 className="mt-2 text-3xl md:text-4xl font-bold text-gray-900">Frequently Asked Questions</h2>
        </motion.div>
        
        <div className="max-w-3xl mx-auto">
          <div className="space-y-6">
            {faqs.map((faq, index) => (
              <motion.div
                key={faq.id}
                initial={{ opacity: 0, y: 20 }}
                animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
                transition={{ duration: 0.6, delay: 0.1 * index }}
                className="bg-white rounded-xl shadow-sm overflow-hidden"
              >
                <button
                  onClick={() => toggleItem(faq.id)}
                  className="flex justify-between items-center w-full px-6 py-4 text-left"
                >
                  <h3 className="text-lg font-medium text-gray-900">{faq.question}</h3>
                  {openItems.includes(faq.id) ? (
                    <ChevronUp className="flex-shrink-0 text-gray-500" />
                  ) : (
                    <ChevronDown className="flex-shrink-0 text-gray-500" />
                  )}
                </button>
                
                <AnimatePresence>
                  {openItems.includes(faq.id) && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.3 }}
                      className="overflow-hidden"
                    >
                      <div className="px-6 pb-4 text-gray-600">
                        {faq.answer}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
};

export default FAQSection;
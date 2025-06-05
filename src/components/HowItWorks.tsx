import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';

const HowItWorks = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const steps = [
    {
      number: 1,
      title: 'Set Up',
      description: 'Create a project, timeline and shot lists before the event. Customize a pre-built wedding day templates or create one that matches your style and workflow.'
    },
    {
      number: 2,
      title: 'Execute',
      description: 'Follow reminders and update progress throughout the day. Never second-guess what\'s next on the timeline with our smart notification system.'
    },
    {
      number: 3,
      title: 'Coordinate',
      description: 'Keep your entire team synchronized with real-time updates. Perfect for creatives managing multiple contractors at different locations.'
    }
  ];

  return (
    <section 
      className="py-20" 
      ref={ref}
      style={{
        backgroundImage: 'linear-gradient(to right top, #f1f1f1, #f5f3f4, #faf5f5, #fef8f4, #fdfcf5)'
      }}
    >
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={inView ? { opacity: 1, x: 0 } : { opacity: 0, x: -20 }}
            transition={{ duration: 0.8 }}
            className="space-y-10"
          >
            {steps.map((step, index) => (
              <motion.div
                key={step.number}
                initial={{ opacity: 0, y: 20 }}
                animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
                transition={{ duration: 0.6, delay: 0.1 * index }}
                className="flex items-start"
              >
                <div className="flex-shrink-0 mr-4">
                  <div className="flex items-center justify-center w-12 h-12 rounded-full bg-sky text-slate font-bold text-lg">
                    {step.number}
                  </div>
                </div>
                <div>
                  <h3 className="text-xl font-bold text-charcoal mb-2">{step.title}</h3>
                  <p className="text-slate">{step.description}</p>
                </div>
              </motion.div>
            ))}
          </motion.div>
          
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={inView ? { opacity: 1, x: 0 } : { opacity: 0, x: 20 }}
            transition={{ duration: 0.8 }}
            className="flex justify-center"
          >
            <img
              src="/driving.png"
              alt="Mobile app timeline view while driving"
              className="w-full max-w-lg rounded-2xl shadow-xl"
            />
          </motion.div>
        </div>
      </div>
    </section>
  );
};

export default HowItWorks;
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { Clock, ListTodo } from 'lucide-react';

const AppShowcase = () => {
  const [firstSectionRef, firstSectionInView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });
  
  const [secondSectionRef, secondSectionInView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const scrollToFeatureTabs = () => {
    const element = document.getElementById('more-features');
    if (element) {
      const yOffset = -80;
      const y = element.getBoundingClientRect().top + window.pageYOffset + yOffset;
      window.scrollTo({ top: y, behavior: 'smooth' });
    }
  };

  return (
    <>
      {/* First showcase section */}
      <section className="py-12 bg-white" ref={firstSectionRef}>
        <div className="container mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
            <div className="order-2 md:order-1">
              <motion.div
                initial={{ opacity: 0, x: -20 }}
                animate={firstSectionInView ? { opacity: 1, x: 0 } : { opacity: 0, x: -20 }}
                transition={{ duration: 0.8 }}
                className="flex justify-center"
              >
                <div className="w-[43.2%]">
                  <img
                    src="/timeline-view-portrait.png"
                    alt="Timeline view"
                    className="w-full h-auto"
                    style={{ 
                      filter: 'drop-shadow(0 25px 25px rgb(0 0 0 / 0.15))'
                    }}
                  />
                </div>
              </motion.div>
            </div>
            
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={firstSectionInView ? { opacity: 1, x: 0 } : { opacity: 0, x: 20 }}
              transition={{ duration: 0.8 }}
              className="order-1 md:order-2"
            >
              <div className="mb-4">
                <Clock size={40} className="text-sky" />
              </div>
              <h2 className="text-3xl font-bold text-charcoal mb-3">Smart Timeline Management</h2>
              <p className="text-slate mb-4">
                Keep your entire team synchronized with our intelligent timeline system. Track progress, get reminders, and ensure every moment is captured perfectly.
              </p>
              <button 
                onClick={scrollToFeatureTabs}
                className="bg-sky text-slate px-6 py-3 rounded-full font-medium hover:shadow-lg transition-shadow"
              >
                Learn More
              </button>
            </motion.div>
          </div>
        </div>
      </section>
      
      {/* Second showcase section */}
      <section className="py-12 bg-silver bg-opacity-20" ref={secondSectionRef}>
        <div className="container mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={secondSectionInView ? { opacity: 1, x: 0 } : { opacity: 0, x: -20 }}
              transition={{ duration: 0.8 }}
            >
              <div className="mb-4">
                <ListTodo size={40} className="text-sky" />
              </div>
              <h2 className="text-3xl font-bold text-charcoal mb-3">Task Management</h2>
              <p className="text-slate">
                Organize PDF's from Coordinators, Images, COI's and To-do's per project all in one place. Perfect for referencing documents and keeping yourself and your team up-to date.
              </p>
            </motion.div>
            
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={secondSectionInView ? { opacity: 1, x: 0 } : { opacity: 0, x: 20 }}
              transition={{ duration: 0.8 }}
              className="flex justify-center"
            >
              <div className="w-[43.2%]">
                <img
                  src="/task-view-left.png"
                  alt="Task management"
                  className="w-full h-auto"
                  style={{ 
                    filter: 'drop-shadow(0 25px 25px rgb(0 0 0 / 0.15))'
                  }}
                />
              </div>
            </motion.div>
          </div>
        </div>
      </section>
    </>
  );
};

export default AppShowcase;
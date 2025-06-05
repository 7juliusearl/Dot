import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { Mail, Instagram } from 'lucide-react';

const Contact = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  return (
    <section id="contact" className="py-16 bg-gray-50" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col md:flex-row justify-between">
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={inView ? { opacity: 1, x: 0 } : { opacity: 0, x: -20 }}
            transition={{ duration: 0.6 }}
            className="mb-8 md:mb-0"
          >
            <div className="space-y-4">
              <div className="flex items-center">
                <Mail className="text-sky mr-3 flex-shrink-0" />
                <a href="mailto:hello@dayoftimeline.app" className="text-gray-700 hover:text-sky transition-colors">
                  hello@dayoftimeline.app
                </a>
              </div>
            </div>
          </motion.div>
          
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={inView ? { opacity: 1, x: 0 } : { opacity: 0, x: 20 }}
            transition={{ duration: 0.6 }}
          >
            <div className="flex space-x-4">
              <a 
                href="#" 
                className="w-10 h-10 rounded-full bg-white shadow-md flex items-center justify-center text-gray-700 hover:text-sky hover:shadow-lg transition-all"
                aria-label="Instagram"
              >
                <Instagram size={18} />
              </a>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
};

export default Contact;
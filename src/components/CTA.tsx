import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { useNavigate } from 'react-router-dom';

interface CTAProps {
  onEmailSubmit: (email: string) => void;
}

const CTA = ({ onEmailSubmit }: CTAProps) => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const navigate = useNavigate();

  const handleBetaAccess = () => {
    navigate('/payment?plan=lifetime');
  };

  return (
    <section 
      className="py-24 text-charcoal" 
      ref={ref}
      style={{
        backgroundImage: 'linear-gradient(to bottom, #D1DDF1, #ffffff)'
      }}
    >
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
            transition={{ duration: 0.6 }}
          >
            <h2 className="text-3xl md:text-4xl font-bold mb-6">Join the Beta List</h2>
            <p className="text-xl md:text-2xl mb-10 text-slate">
              Be one of the first to experience our revolutionary wedding day organization app.
            </p>
            
            <button 
              onClick={handleBetaAccess}
              className="bg-sky text-slate px-8 py-3 rounded-full font-medium hover:shadow-lg transition-shadow mb-8"
            >
              Beta Access
            </button>
            
            <p className="text-sm text-slate">
              Limited spots available. Join now to secure your early access discount!
            </p>
          </motion.div>
        </div>
      </div>
    </section>
  );
};

export default CTA;
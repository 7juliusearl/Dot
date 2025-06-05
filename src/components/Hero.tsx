import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { useNavigate } from 'react-router-dom';

const Hero = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const navigate = useNavigate();

  const handleBetaAccess = () => {
    navigate('/payment?plan=lifetime');
  };

  return (
    <header 
      id="home" 
      className="pt-32 pb-0 overflow-hidden"
      ref={ref}
      style={{
        backgroundImage: 'radial-gradient(circle, #f2f2f2, #edeef6, #e4ecfa, #d7eafd, #c7e9ff)'
      }}
    >
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 mt-5">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.8 }}
          className="text-center max-w-4xl mx-auto"
        >
          <span className="inline-block px-4 py-1 mb-6 bg-sand text-charcoal rounded-full text-sm font-medium">
            🚀 Limited Beta Access Available
          </span>
          <h1 className="text-5xl md:text-6xl lg:text-7xl font-bold mb-6 text-charcoal">
            Your Day of Timeline.
          </h1>
          <p className="text-xl md:text-2xl text-slate max-w-3xl mx-auto mb-8">
            Finally, an iOS app that keeps you locked in and efficient while staying creative on a wedding day. 
          </p>
          
          <button 
            onClick={handleBetaAccess}
            className="bg-sky text-slate px-8 py-3 rounded-full font-medium hover:shadow-lg transition-shadow mb-8"
          >
            Get Beta Access
          </button>

          <div className="flex flex-col items-center gap-2">
            <p className="text-sm text-slate font-medium">Coming soon</p>
            <img 
              src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us"
              alt="Download on the App Store"
              className="h-12"
            />
          </div>
        </motion.div>
        
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 40 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          className="mt-16 flex justify-center relative"
          style={{ marginBottom: '-25%' }}
        >
          <div className="relative w-full max-w-[320px]">
            <img 
              src="/load-screen-portrait.png" 
              alt="Day of Timeline App"
              className="w-full h-auto"
              style={{ 
                filter: 'drop-shadow(0 25px 25px rgb(0 0 0 / 0.15))'
              }}
            />
          </div>
        </motion.div>
      </div>
    </header>
  );
};

export default Hero;
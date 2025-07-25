import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';

const Hero = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  return (
    <header 
      id="home" 
      className="pt-32 pb-24 overflow-hidden"
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
            Finally, an app that keeps you locked in and creative on a wedding day.
          </p>

          <div className="flex flex-col items-center gap-6 mb-8">
            <button 
              onClick={() => window.location.href = '/payment?plan=lifetime'}
              className="bg-gradient-to-r from-purple-600 to-indigo-600 text-white px-8 py-4 rounded-full font-bold text-lg hover:shadow-xl transition-all transform hover:scale-105"
            >
              Secure Your Beta Spot
            </button>
            
            <div className="text-center">
              <p className="text-sm text-slate font-medium mb-2">Available now for iOS beta testers</p>
              <div className="flex items-center justify-center gap-2 text-emerald-600">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
                <span className="text-sm font-medium">Instant TestFlight access after payment</span>
              </div>
            </div>
          </div>
        </motion.div>
        
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 40 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          className="mt-16 flex justify-center relative z-10"
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
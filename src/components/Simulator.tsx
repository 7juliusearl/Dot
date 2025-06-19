import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';

const Simulator = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  return (
    <section 
      className="py-20 bg-white" 
      ref={ref}
      id="simulator"
    >
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <span className="text-sm font-bold tracking-wider text-sky uppercase">How It Works</span>
          <h2 className="mt-2 text-3xl md:text-4xl font-bold text-charcoal">See It In Action</h2>
          <p className="mt-4 text-slate max-w-2xl mx-auto">
            Take a guided tour through our app's core features and see how it can transform your workflow.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6, delay: 0.2 }}
        >
                      <div style={{ position: 'relative', boxSizing: 'content-box', maxHeight: '80svh', width: '100%', aspectRatio: '0.4671857619577308', padding: '40px 0 40px 0' }}>
            <iframe 
              src="https://app.supademo.com/embed/cmbg6ftpj4f32sn1rxob1x1fd?embed_v=2" 
              loading="lazy" 
              title="Simulator Demo" 
              allow="clipboard-write; fullscreen" 
              frameBorder="0" 
              allowFullScreen 
              sandbox="allow-scripts allow-same-origin allow-popups allow-forms"
              style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%' }}
            />
          </div>
        </motion.div>
      </div>
    </section>
  );
};

export default Simulator;
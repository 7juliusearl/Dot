import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';

const Partners = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  return (
    <section className="py-12 bg-white" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0 }}
          animate={inView ? { opacity: 1 } : { opacity: 0 }}
          transition={{ duration: 0.8 }}
          className="flex flex-wrap justify-center items-center gap-12 md:gap-16"
        >
        </motion.div>
      </div>
    </section>
  );
};

export default Partners;
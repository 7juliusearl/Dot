import { useRef } from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { ChevronLeft, ChevronRight, Quote } from 'lucide-react';
import { Screenshot } from '../types';
import { Swiper, SwiperSlide } from 'swiper/react';
import 'swiper/css';

const Gallery = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });
  
  const swiperRef = useRef<any>(null);

  const screenshots: Screenshot[] = [
    {
      id: 1,
      image: '/connections.png',
      alt: 'Connections screen showing team members'
    },
    {
      id: 2,
      image: '/inboxgallery.png',
      alt: 'Inbox screen showing team chat'
    },
    {
      id: 3,
      image: '/profile-and-settings.png',
      alt: 'Profile and settings screens'
    }
  ];

  return (
    <section id="gallery" className="py-20 bg-gray-50" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <span className="text-sm font-bold tracking-wider text-sky uppercase">Gallery</span>
          <h2 className="mt-2 text-3xl md:text-4xl font-bold text-charcoal">App Screenshots</h2>
        </motion.div>
        
        <div className="relative">
          <motion.div
            initial={{ opacity: 0 }}
            animate={inView ? { opacity: 1 } : { opacity: 0 }}
            transition={{ duration: 0.8, delay: 0.2 }}
          >
            <Swiper
              onSwiper={(swiper) => {
                swiperRef.current = swiper;
              }}
              spaceBetween={30}
              slidesPerView={1}
              breakpoints={{
                640: {
                  slidesPerView: 2,
                },
                1024: {
                  slidesPerView: 3,
                },
              }}
              className="py-8"
            >
              {screenshots.map((screenshot) => (
                <SwiperSlide key={screenshot.id}>
                  <div className="overflow-hidden rounded-2xl shadow-lg">
                    <img
                      src={screenshot.image}
                      alt={screenshot.alt}
                      className="w-full h-auto transform hover:scale-105 transition-transform duration-500"
                    />
                  </div>
                </SwiperSlide>
              ))}
            </Swiper>
          </motion.div>
          
          <div className="flex justify-center mt-8 gap-4">
            <button
              onClick={() => swiperRef.current?.slidePrev()}
              className="p-3 rounded-full bg-white shadow-md hover:bg-sky hover:text-slate text-charcoal transition-colors"
              aria-label="Previous screenshot"
            >
              <ChevronLeft size={20} />
            </button>
            <button
              onClick={() => swiperRef.current?.slideNext()}
              className="p-3 rounded-full bg-white shadow-md hover:bg-sky hover:text-slate text-charcoal transition-colors"
              aria-label="Next screenshot"
            >
              <ChevronRight size={20} />
            </button>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Gallery;
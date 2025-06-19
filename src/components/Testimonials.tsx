import { useRef } from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { ChevronLeft, ChevronRight, Quote } from 'lucide-react';
import { Testimonial } from '../types';
import { Swiper, SwiperSlide } from 'swiper/react';
import 'swiper/css';

const Testimonials = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });
  
  const swiperRef = useRef<any>(null);

  const testimonials: Testimonial[] = [
    {
      id: 1,
      name: 'Brandon',
      location: 'Wedding Photographer, Palm Springs',
      quote: 'This app saved me 6+ hours on my last wedding! Finally being able to organize and plan the wedding day while checking off those must have shots from the shot list is a game changer! No more scrambling through texts or emails - everything I need is right here.',
      avatar: '/brandon.jpg'
    },
    {
      id: 2,
      name: 'Angelo',
      location: 'Videographer, NYC',
      quote: 'Managing multiple contractors used to be a nightmare. Now my entire team stays synchronized without constant check-ins. This alone has saved me 3-4 hours per wedding and seriously impressed my clients.',
      avatar: '/angelo.jpg'
    },
    {
      id: 3,
      name: 'Jenna',
      location: 'Photographer, Irvine',
      quote: 'Mind blowing! I can\'t believe I\'ve been doing weddings for years without something like this. The in-app team messaging alone saves me 2+ hours of coordination time per event.',
      avatar: '/jenna.jpg'
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
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <span className="text-sm font-bold tracking-wider text-sky uppercase">Testimonials</span>
          <h2 className="mt-2 text-3xl md:text-4xl font-bold text-charcoal">Success Stories from Real Creatives</h2>
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
              {testimonials.map((testimonial) => (
                <SwiperSlide key={testimonial.id}>
                  <div className="bg-white rounded-2xl shadow-lg p-8 h-full flex flex-col border border-silver">
                    <div className="mb-6">
                      <Quote size={36} className="text-sky" />
                    </div>
                    <p className="text-slate mb-6 flex-grow">{testimonial.quote}</p>
                    <div className="flex items-center">
                      <img
                        src={testimonial.avatar}
                        alt={testimonial.name}
                        className="w-12 h-12 rounded-full object-cover mr-4"
                      />
                      <div>
                        <h4 className="font-bold text-charcoal">{testimonial.name}</h4>
                        <p className="text-sky text-sm">{testimonial.location}</p>
                      </div>
                    </div>
                  </div>
                </SwiperSlide>
              ))}
            </Swiper>
          </motion.div>
          
          <div className="flex justify-center mt-8 gap-4">
            <button
              onClick={() => swiperRef.current?.slidePrev()}
              className="p-3 rounded-full bg-white shadow-md hover:bg-sky hover:text-slate text-charcoal transition-colors"
              aria-label="Previous testimonial"
            >
              <ChevronLeft size={20} />
            </button>
            <button
              onClick={() => swiperRef.current?.slideNext()}
              className="p-3 rounded-full bg-white shadow-md hover:bg-sky hover:text-slate text-charcoal transition-colors"
              aria-label="Next testimonial"
            >
              <ChevronRight size={20} />
            </button>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Testimonials;
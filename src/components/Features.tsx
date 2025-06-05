import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { ListTodo, Users, Clock, Camera } from 'lucide-react';
import { Feature } from '../types';

const Features = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const features: Feature[] = [
    {
      id: 1,
      title: 'Smart Timeline Management',
      description: 'Customizable wedding day templates that adapt to your workflow. Automatically adjusts the entire timeline when events are delayed and easily revert to original schedule when back on track.',
      icon: 'clock'
    },
    {
      id: 2,
      title: 'Team Coordination',
      description: 'Keep your entire crew synchronized with real-time updates and chat. Perfect for managing second shooters, assistants, and creatives throughout the day.',
      icon: 'users'
    },
    {
      id: 3,
      title: 'Shot List Organization',
      description: 'Never miss an important photo with categorized shot lists and smart notifications. Customizable templates for different wedding styles and traditions.',
      icon: 'camera'
    },
    {
      id: 4,
      title: 'Task Management',
      description: 'Delegate responsibilities and track completion in real-time. Perfect for coordinating multiple team members across different locations and timeframes.',
      icon: 'todo'
    }
  ];

  const renderIcon = (iconName: string) => {
    switch (iconName) {
      case 'clock':
        return <Clock size={48} className="text-sky" />;
      case 'users':
        return <Users size={48} className="text-sky" />;
      case 'camera':
        return <Camera size={48} className="text-sky" />;
      case 'todo':
        return <ListTodo size={48} className="text-sky" />;
      default:
        return <Clock size={48} className="text-sky" />;
    }
  };

  return (
    <section 
      id="features" 
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
          className="text-center mb-16"
        >
          <span className="text-sm font-bold tracking-wider text-sky uppercase">Features</span>
          <h2 className="mt-2 text-3xl md:text-4xl font-bold text-charcoal">Wedding Day Organization, Simplified</h2>
          <p className="mt-4 text-slate max-w-3xl mx-auto">
            Everything you need to keep yourself and your team synchronized and on track throughout the entire day.
          </p>
        </motion.div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {features.map((feature, index) => (
            <motion.div
              key={feature.id}
              initial={{ opacity: 0, y: 20 }}
              animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
              transition={{ duration: 0.6, delay: 0.1 * index }}
              className="bg-white p-8 rounded-2xl shadow-lg hover:shadow-xl transition-shadow border border-silver"
            >
              <div className="mb-5">
                {renderIcon(feature.icon)}
              </div>
              <h3 className="text-xl font-bold text-charcoal mb-3">{feature.title}</h3>
              <p className="text-slate">{feature.description}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Features;
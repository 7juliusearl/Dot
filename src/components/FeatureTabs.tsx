import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { TabContent } from '../types';

const FeatureTabs = () => {
  const [activeTab, setActiveTab] = useState('overview');
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const tabs: TabContent[] = [
    {
      id: 'home',
      title: 'Home',
      heading: 'Quick Access Dashboard',
      description: 'Everything you need at a glance, including one-tap navigation.',
      content: 'Start your day with confidence using our intuitive home dashboard. See your next event details instantly, access project information, and get turn-by-turn directions with a single tap through Apple Maps integration. No more copy-pasting addresses or switching between apps - everything you need is right where you need it.',
      image: '/homeview-portrait.png',
      imagePosition: 'left'
    },
    {
      id: 'timeline',
      title: 'Timeline',
      heading: 'Smart Timeline Management',
      description: 'Keep yourself or your entire team on schedule throughout the wedding day.',
      content: 'Our intelligent timeline system adapts to your workflow, providing real-time updates and smart notifications, even on your apple watch. When events are delayed, the app automatically recalculates and adjusts the entire day\'s schedule. Running behind? Set the time back, and watch as every subsequent event adjusts accordingly. Back on track? Easily reset to your original timeline with a single tap. Thats just one of many features!',
      image: '/timeline-delay.png',
      imagePosition: 'left'
    },
    {
      id: 'team',
      title: 'Team',
      heading: 'Seamless Team Coordination',
      description: 'Coordinate your entire crew with real-time updates and chat.',
      content: 'Keep everyone in sync with instant updates and chat. Perfect for managing second shooters, assistants, and creatives throughout the day. Assign tasks, track completion, and maintain clear communication channels throughout the day. No more missed shots or confusion about responsibilities.',
      image: '/team-chat-left.png',
      imagePosition: 'right'
    },
    {
      id: 'shotlist',
      title: 'Shot List',
      heading: 'Comprehensive Shot Management',
      description: 'Never miss an important photo with smart shot lists.',
      content: 'Streamline your photography workflow with our intuitive shot list organization. From intimate getting-ready moments to grand reception celebrations, every important shot is meticulously tracked. Our customizable templates adapt to various cultural traditions and special requests, ensuring comprehensive coverage of family portraits and key moments throughout the day.',
      image: '/shot-list-view-portrait.png',
      imagePosition: 'left'
    },
    {
      id: 'overview',
      title: 'Overview',
      heading: 'Quick Access Overview',
      description: 'All crucial wedding day details at your fingertips.',
      content: 'Access vital information instantly with our comprehensive overview screen. From preparation schedules and contact details to ceremony timing and grand entrance coordination - everything that matters is just a glance away. Perfect for your team to be in the know at a glance.',
      image: '/overview-view-portrait.png',
      imagePosition: 'left'
    }
  ];

  const currentTab = tabs.find(tab => tab.id === activeTab) || tabs[0];

  return (
    <section 
      className="py-20" 
      ref={ref} 
      id="more-features"
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
          <span className="text-sm font-bold tracking-wider text-sky uppercase">Features</span>
          <h2 className="mt-2 text-3xl md:text-4xl font-bold text-charcoal">Professional Tools for Professional Results</h2>
        </motion.div>
        
        <div className="mb-12">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="flex flex-wrap justify-center"
          >
            <div className="bg-white rounded-xl shadow-md p-1 mb-8">
              <div className="flex flex-wrap">
                {tabs.map((tab) => (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`relative px-6 py-3 text-sm font-medium rounded-lg transition-all duration-200 ${
                      activeTab === tab.id
                        ? 'text-slate'
                        : 'text-slate hover:text-sky'
                    }`}
                  >
                    {activeTab === tab.id && (
                      <motion.div
                        layoutId="activeTabBackground"
                        className="absolute inset-0 bg-sky rounded-lg"
                        transition={{ type: 'spring', duration: 0.6 }}
                      />
                    )}
                    <span className="relative z-10">{tab.title}</span>
                  </button>
                ))}
              </div>
            </div>
          </motion.div>
          
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.5 }}
            >
              <div className={`grid grid-cols-1 ${currentTab.imagePosition === 'left' ? 'md:grid-cols-2' : 'md:grid-cols-2'} gap-12 items-center`}>
                {currentTab.imagePosition === 'left' && (
                  <div className="flex justify-center">
                    <div className="relative w-[320px] h-[693px]">
                      <img
                        src={currentTab.image}
                        alt={currentTab.title}
                        className="absolute inset-0 w-full h-full object-contain"
                        style={{ 
                          filter: 'drop-shadow(0 25px 25px rgb(0 0 0 / 0.15))'
                        }}
                      />
                    </div>
                  </div>
                )}
                
                <div>
                  <h3 className="text-2xl font-bold text-charcoal mb-4">{currentTab.heading}</h3>
                  <p className="text-slate text-lg mb-4">{currentTab.description}</p>
                  <p className="text-slate mb-6">{currentTab.content}</p>
                </div>
                
                {currentTab.imagePosition === 'right' && (
                  <div className="flex justify-center">
                    <div className="relative w-[320px] h-[693px]">
                      <img
                        src={currentTab.image}
                        alt={currentTab.title}
                        className="absolute inset-0 w-full h-full object-contain"
                        style={{ 
                          filter: 'drop-shadow(0 25px 25px rgb(0 0 0 / 0.15))'
                        }}
                      />
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </section>
  );
};

export default FeatureTabs;
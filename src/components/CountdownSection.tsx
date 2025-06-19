import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { Users, AlertCircle, CheckCircle, Mail, Loader } from 'lucide-react';
import { createClient } from '@supabase/supabase-js';

// Use shared supabase instance to avoid multiple client warnings
const getSupabaseClient = () => {
  if (typeof window !== 'undefined' && (window as any).__supabase) {
    return (window as any).__supabase;
  }
  const supabase = createClient(
    import.meta.env.VITE_SUPABASE_URL!,
    import.meta.env.VITE_SUPABASE_ANON_KEY!
  );
  if (typeof window !== 'undefined') {
    (window as any).__supabase = supabase;
  }
  return supabase;
};



const supabase = getSupabaseClient();

const CountdownSection = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  // Real user count from your database
  const [currentUsers, setCurrentUsers] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  
  // Waitlist state
  const [waitlistEmail, setWaitlistEmail] = useState('');
  const [waitlistStatus, setWaitlistStatus] = useState<'idle' | 'submitting' | 'success' | 'error'>('idle');
  const [waitlistMessage, setWaitlistMessage] = useState('');
  
  const maxUsers = 150; // Total spots available for current batch
  const spotsLeft = maxUsers - currentUsers;
  const isSpotAvailable = spotsLeft > 0;

  useEffect(() => {
    const fetchUserCount = async () => {
      try {
        console.log('🔍 Fetching user count via Netlify function...');
        
        // Call our Netlify function that uses service role to bypass RLS
        const response = await fetch('/api/user-count');
        const data = await response.json();

        console.log('📊 User count response:', data);

        if (response.ok && data.success) {
          console.log('✅ Successfully fetched count:', data.count);
          setCurrentUsers(data.count || 0);
        } else {
          console.error('❌ Error fetching user count:', data.error);
          setCurrentUsers(0);
        }
      } catch (error) {
        console.error('💥 Failed to fetch user count:', error);
        setCurrentUsers(0);
      } finally {
        setIsLoading(false);
      }
    };

    fetchUserCount();
  }, []);

  const handleWaitlistSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!waitlistEmail || !waitlistEmail.includes('@')) {
      setWaitlistStatus('error');
      setWaitlistMessage('Please enter a valid email address');
      return;
    }

    setWaitlistStatus('submitting');
    setWaitlistMessage('');

    try {
      const { error } = await supabase
        .from('waitlist')
        .insert([
          { 
            email: waitlistEmail.toLowerCase().trim(),
            status: 'pending'
          }
        ]);

      if (error) {
        if (error.code === '23505') { // Unique constraint violation
          setWaitlistStatus('error');
          setWaitlistMessage('This email is already on the waitlist!');
        } else {
          setWaitlistStatus('error');
          setWaitlistMessage('Failed to join waitlist. Please try again.');
        }
      } else {
        setWaitlistStatus('success');
        setWaitlistMessage('🎉 Thank you for joining the waitlist! You\'ll be the first to know when Batch 2 opens. Please check your email (including spam folder) for updates and keep an eye out for our notification.');
        setWaitlistEmail('');
      }
    } catch (error) {
      console.error('Waitlist submission error:', error);
      setWaitlistStatus('error');
      setWaitlistMessage('Something went wrong. Please try again.');
    }
  };

  return (
    <section className="pt-32 pb-12 bg-gradient-to-r from-red-50 to-orange-50">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          ref={ref}
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="max-w-md mx-auto"
        >
          {/* Single Unified Box */}
          <div className="bg-white rounded-xl shadow-xl drop-shadow-xl p-6 border-3 border-red-500/50">
            {/* Header with Status Icon */}
            <div className="flex items-center justify-center mb-4">
              {isSpotAvailable ? (
                <AlertCircle className="text-red-600 w-5 h-5 mr-2" />
              ) : (
                <CheckCircle className="text-gray-600 w-5 h-5 mr-2" />
              )}
              <span className={`font-semibold text-base ${isSpotAvailable ? 'text-red-700' : 'text-gray-700'}`}>
                {isSpotAvailable ? 'Limited Beta Spots Available' : 'Batch 1 Full - Join Waitlist'}
              </span>
            </div>

            {/* Main Title */}
            <h2 className="text-2xl md:text-3xl font-bold text-charcoal mb-3 text-center">
              {isLoading ? (
                'Loading...'
              ) : isSpotAvailable ? (
                <>Only <span className="text-red-600">{spotsLeft}</span> Spots Left</>
              ) : (
                'Batch 1 Complete'
              )}
            </h2>

                          {/* Progress Section */}
             <div className="mb-6">
               <div className="flex justify-between text-base font-medium text-charcoal mb-2">
                <span>{isLoading ? 'Loading...' : `${currentUsers} / ${maxUsers} Users`}</span>
                <span className={`${isSpotAvailable ? 'text-red-600' : 'text-gray-600'}`}>
                  {isLoading ? '...' : isSpotAvailable ? `${spotsLeft} left` : 'Full'}
                </span>
              </div>
              
              <div className="w-full bg-gray-200 rounded-full h-3 mb-4">
                <div 
                  className={`h-3 rounded-full transition-all duration-300 ${
                    isSpotAvailable ? 'bg-gradient-to-r from-green-500 to-red-500' : 'bg-gray-500'
                  }`}
                  style={{ width: `${(currentUsers / maxUsers) * 100}%` }}
                ></div>
              </div>

              {/* Status Message */}
              <div className="text-center mb-4">
                {isSpotAvailable ? (
                  <p className="text-slate text-base">
                    <span className="font-semibold text-green-600">{currentUsers}</span> wedding professionals 
                    have already secured their spot in our exclusive beta program.
                  </p>
                ) : (
                  <p className="text-slate text-base">
                    Our first batch is now complete! Join the waitlist to be notified when 
                    <strong> Batch 2</strong> opens.
                  </p>
                )}
              </div>
            </div>

            {/* CTA Section */}
            <div className="text-center">
              {isSpotAvailable ? (
                <div className="bg-gradient-to-r from-red-600 to-orange-600 text-white rounded-lg p-4">
                  <h3 className="text-lg font-bold mb-2">
                    Secure Your Beta Access
                  </h3>
                  <p className="mb-3 opacity-90 text-sm">
                    Once we hit 150 users, you'll have to wait for the next batch. 
                    Don't miss your chance to be part of the exclusive first group.
                  </p>
                  <button 
                    onClick={() => window.location.href = '/payment?plan=lifetime'}
                    className="bg-white text-red-600 px-6 py-2 rounded-full font-semibold hover:shadow-lg transition-shadow text-sm"
                  >
                    Get Your Spot Now
                  </button>
                </div>
              ) : (
                <div className="bg-gradient-to-r from-gray-600 to-gray-700 text-white rounded-lg p-4">
                  <h3 className="text-lg font-bold mb-3 flex items-center justify-center">
                    <Mail className="w-4 h-4 mr-2" />
                    Join the Waitlist
                  </h3>
                  <p className="mb-3 opacity-90 text-sm">
                    Be the first to know when Batch 2 opens for beta access.
                  </p>
                  
                                     {/* Waitlist Email Form */}
                   <form onSubmit={handleWaitlistSubmit} className="max-w-sm mx-auto">
                     <div className="flex flex-col sm:flex-row gap-2">
                       <div className="flex-1">
                         <input
                           type="email"
                           placeholder="Enter your email address"
                           value={waitlistEmail}
                           onChange={(e) => setWaitlistEmail(e.target.value)}
                           className="w-full px-3 py-2 rounded-lg text-gray-800 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                           disabled={waitlistStatus === 'submitting' || waitlistStatus === 'success'}
                           required
                         />
                       </div>
                       <button
                         type="submit"
                         disabled={waitlistStatus === 'submitting' || waitlistStatus === 'success'}
                         className="px-4 py-2 bg-white text-gray-600 rounded-lg font-semibold hover:shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center min-w-[100px] text-sm"
                       >
                         {waitlistStatus === 'submitting' ? (
                           <>
                             <Loader className="animate-spin w-3 h-3 mr-1" />
                             Joining...
                           </>
                         ) : waitlistStatus === 'success' ? (
                           'Joined!'
                         ) : (
                           'Join Waitlist'
                         )}
                       </button>
                     </div>
                     
                     {/* Status Messages */}
                     {waitlistMessage && (
                       <div className={`mt-2 text-xs ${
                         waitlistStatus === 'success' 
                           ? 'text-green-300' 
                           : waitlistStatus === 'error' 
                             ? 'text-red-300' 
                             : 'text-white'
                       }`}>
                         {waitlistMessage}
                       </div>
                     )}
                   </form>
                </div>
              )}
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
};

export default CountdownSection; 
import { useState, useEffect, useRef } from 'react';
import { Menu, X, LogOut, ChevronDown, User } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../utils/supabase';

interface NavbarProps {
  showDashboard: boolean;
}

const Navbar = ({ showDashboard }: NavbarProps) => {
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();

  useEffect(() => {
    const handleScroll = () => {
      const offset = window.scrollY;
      if (offset > 50) {
        setScrolled(true);
      } else {
        setScrolled(false);
      }
    };

    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setDropdownOpen(false);
      }
    };

    window.addEventListener('scroll', handleScroll);
    document.addEventListener('mousedown', handleClickOutside);

    if (showDashboard) {
      getUserEmail();
    }

    return () => {
      window.removeEventListener('scroll', handleScroll);
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showDashboard]);

  const getUserEmail = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (session?.user?.email) {
      setUserEmail(session.user.email);
    }
  };

  const scrollToSection = (sectionId: string) => {
    const element = document.getElementById(sectionId);
    if (element) {
      const yOffset = -80;
      const y = element.getBoundingClientRect().top + window.pageYOffset + yOffset;
      window.scrollTo({ top: y, behavior: 'smooth' });
      setIsOpen(false);
    }
  };

  const handleManageAccount = () => {
    setDropdownOpen(false);
    navigate('/dashboard');
  };

  const handleSignOut = async () => {
    try {
      // Check if there's actually a session before trying to sign out
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session) {
        const { error } = await supabase.auth.signOut();
        if (error && error.message !== 'Auth session missing!') {
          throw error;
        }
      }
      
      // Clear any local storage items regardless of session state
      localStorage.removeItem('supabase.auth.token');
      sessionStorage.clear();
      
      // Reset states
      setDropdownOpen(false);
      setIsOpen(false);
      setUserEmail(null);
      
      // Navigate to home page
      navigate('/', { replace: true });
      
      // Force page reload to clear any cached states
      window.location.reload();
    } catch (error) {
      console.error('Error signing out:', error);
      
      // Even if there's an error, still clear local state and redirect
      localStorage.removeItem('supabase.auth.token');
      sessionStorage.clear();
      setDropdownOpen(false);
      setIsOpen(false);
      setUserEmail(null);
      navigate('/', { replace: true });
      window.location.reload();
    }
  };

  return (
    <nav 
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled ? 'bg-white shadow-md' : 'bg-transparent'
      }`}
    >
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center py-4">
          <div className="flex items-center">
            <div className="relative">
              <img 
                src="/dot-logo.png" 
                alt="DOT Logo" 
                className="h-8 w-8 mr-2 cursor-pointer rounded-full"
                onClick={() => navigate('/')}
                onError={(e) => {
                  console.error('Logo failed to load:', e);
                  e.currentTarget.style.display = 'none';
                  const fallback = e.currentTarget.nextElementSibling as HTMLElement;
                  if (fallback) fallback.style.display = 'flex';
                }}
              />
              {/* Fallback logo with gradient matching user's design */}
              <div 
                className="h-8 w-8 mr-2 cursor-pointer rounded-full flex items-center justify-center text-white font-bold text-sm"
                onClick={() => navigate('/')}
                style={{ 
                  display: 'none',
                  background: 'linear-gradient(135deg, #D2B48C 0%, #87CEEB 100%)'
                }}
              >
                t.
              </div>
            </div>
            <span 
              className="text-xl font-bold text-charcoal cursor-pointer" 
              onClick={() => navigate('/')}
            >
              Dot
            </span>
          </div>
          
          {/* Desktop Menu */}
          <div className="hidden md:flex items-center space-x-6">
            <button
              onClick={() => scrollToSection('features')}
              className="text-slate hover:text-sky transition-colors font-medium"
            >
              Features
            </button>
            <button
              onClick={() => scrollToSection('simulator')}
              className="text-slate hover:text-sky transition-colors font-medium"
            >
              How it Works
            </button>
            <button
              onClick={() => scrollToSection('contact')}
              className="text-slate hover:text-sky transition-colors font-medium"
            >
              Contact
            </button>
            
            {showDashboard ? (
              <div className="relative" ref={dropdownRef}>
                <button
                  onClick={() => setDropdownOpen(!dropdownOpen)}
                  className="flex items-center bg-sky text-slate px-6 py-2 rounded-full font-medium hover:shadow-lg transition-shadow"
                >
                  <User size={18} className="mr-2" />
                  Account
                  <ChevronDown size={16} className="ml-2" />
                </button>
                
                <AnimatePresence>
                  {dropdownOpen && (
                    <motion.div
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: 10 }}
                      transition={{ duration: 0.2 }}
                      className="absolute right-0 mt-2 w-64 bg-white rounded-lg shadow-lg py-2"
                    >
                      <div className="px-4 py-2 border-b border-gray-100">
                        <p className="text-sm text-slate font-medium truncate">
                          {userEmail}
                        </p>
                      </div>
                      <button
                        onClick={handleManageAccount}
                        className="w-full text-left px-4 py-2 text-slate hover:bg-sky hover:bg-opacity-10 transition-colors"
                      >
                        Manage Account
                      </button>
                      <button
                        onClick={handleSignOut}
                        className="w-full text-left px-4 py-2 text-red-600 hover:bg-red-50 transition-colors flex items-center"
                      >
                        <LogOut size={16} className="mr-2" />
                        Sign Out
                      </button>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            ) : (
              <button
                onClick={() => navigate('/signin')}
                className="bg-sky text-slate px-6 py-2 rounded-full font-medium hover:shadow-lg transition-shadow"
              >
                Log In
              </button>
            )}
          </div>
          
          {/* Mobile Menu Button */}
          <div className="md:hidden">
            <button
              onClick={() => setIsOpen(!isOpen)}
              className="text-slate hover:text-sky focus:outline-none p-2 border border-slate rounded-md flex items-center justify-center"
              aria-label={isOpen ? "Close menu" : "Open menu"}
            >
              {isOpen ? (
                <X size={24} className="text-slate" />
              ) : (
                <Menu size={24} className="text-slate" />
              )}
            </button>
          </div>
        </div>
      </div>
      
      {/* Mobile Menu */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="bg-white md:hidden shadow-lg overflow-hidden"
          >
            <div className="px-4 py-5 space-y-5">
              {showDashboard && userEmail && (
                <div className="px-4 py-2 bg-gray-50 rounded-lg mb-4">
                  <p className="text-sm text-slate font-medium truncate">
                    {userEmail}
                  </p>
                </div>
              )}
              <button
                onClick={() => scrollToSection('features')}
                className="block w-full text-left px-4 py-2 text-slate hover:text-sky hover:bg-gray-50 rounded-md transition-colors"
              >
                Features
              </button>
              <button
                onClick={() => scrollToSection('simulator')}
                className="block w-full text-left px-4 py-2 text-slate hover:text-sky hover:bg-gray-50 rounded-md transition-colors"
              >
                How it Works
              </button>
              <button
                onClick={() => scrollToSection('contact')}
                className="block w-full text-left px-4 py-2 text-slate hover:text-sky hover:bg-gray-50 rounded-md transition-colors"
              >
                Contact
              </button>
              {showDashboard ? (
                <>
                  <button
                    onClick={() => {
                      setIsOpen(false);
                      navigate('/dashboard');
                    }}
                    className="block w-full text-center bg-sky text-slate px-6 py-3 rounded-full font-medium hover:shadow-lg transition-shadow"
                  >
                    Manage Account
                  </button>
                  <button
                    onClick={handleSignOut}
                    className="flex items-center justify-center w-full text-red-600 hover:text-red-700 hover:bg-red-50 px-4 py-2 rounded-md transition-colors"
                  >
                    <LogOut size={18} className="mr-2" />
                    Sign Out
                  </button>
                </>
              ) : (
                <button
                  onClick={() => {
                    setIsOpen(false);
                    navigate('/signin');
                  }}
                  className="block w-full text-center bg-sky text-slate px-6 py-3 rounded-full font-medium hover:shadow-lg transition-shadow"
                >
                  Log In
                </button>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  );
};

export default Navbar;
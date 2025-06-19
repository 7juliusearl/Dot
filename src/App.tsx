import React, { useState, useEffect } from 'react';
import { createClient } from '@supabase/supabase-js';
import { Routes, Route, Navigate, useNavigate } from 'react-router-dom';
import Navbar from './components/Navbar';
import Hero from './components/Hero';

import CountdownSection from './components/CountdownSection';
import Partners from './components/Partners';
import Features from './components/Features';
import AppShowcase from './components/AppShowcase';
import FeatureTabs from './components/FeatureTabs';
import HowItWorks from './components/HowItWorks';
import Simulator from './components/Simulator';
import Testimonials from './components/Testimonials';
import Gallery from './components/Gallery';
import CTA from './components/CTA';
import Contact from './components/Contact';
import Footer from './components/Footer';
import PaymentPage from './components/PaymentPage';
import SignIn from './components/SignIn';
import Dashboard from './components/Dashboard';
import SuccessPage from './components/SuccessPage';
import PaymentVerification from './components/PaymentVerification';
import ErrorBoundary from './components/ErrorBoundary';
import LoadingSpinner from './components/LoadingSpinner';
import NotFound from './components/NotFound';

// Environment variable validation
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Missing required environment variables');
  throw new Error('Missing required environment variables: VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are required');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

function App() {
  const navigate = useNavigate();
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [authError, setAuthError] = useState<string | null>(null);

  useEffect(() => {
    checkSession();
    
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'TOKEN_REFRESHED' || event === 'SIGNED_IN') {
        setIsAuthenticated(true);
        setAuthError(null);
      } else if (event === 'SIGNED_OUT') {
        setIsAuthenticated(false);
        navigate('/');
      }
    });

    return () => {
      subscription.unsubscribe();
    };
  }, [navigate]);

  const checkSession = async () => {
    try {
      const { data: { session }, error } = await supabase.auth.getSession();
      
      if (error) {
        console.error('Session check error:', error.message);
        // Only sign out if it's an auth-related error, not a network error
        if (error.message.includes('invalid') || error.message.includes('expired')) {
          await supabase.auth.signOut();
          setIsAuthenticated(false);
        } else {
          setAuthError('Failed to verify session. Please try again.');
        }
      } else {
        setIsAuthenticated(!!session);
        setAuthError(null);
      }
    } catch (error: any) {
      console.error('Session check failed:', error);
      // Don't automatically sign out on network errors
      if (error.message?.includes('fetch')) {
        setAuthError('Network error. Please check your connection.');
      } else {
        setAuthError('Session verification failed.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleAuthFailure = async () => {
    await supabase.auth.signOut();
    setIsAuthenticated(false);
    navigate('/payment');
  };

  // Protected route wrapper with proper loading state
  const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
    if (isLoading) {
      return <LoadingSpinner />;
    }
    
    if (authError) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <div className="text-center">
            <p className="text-red-600 mb-4">{authError}</p>
            <button 
              onClick={checkSession}
              className="bg-sky text-slate px-4 py-2 rounded-lg hover:shadow-lg transition-shadow"
            >
              Retry
            </button>
          </div>
        </div>
      );
    }
    
    return isAuthenticated ? <>{children}</> : <Navigate to="/payment" />;
  };

  const HomePage = () => (
    <>
      <Hero />
      <CountdownSection />
      <Features />
      <Simulator />
      <HowItWorks />
      <Testimonials />
      <AppShowcase />
      <CTA onEmailSubmit={() => {}} />
      <Contact />
    </>
  );

  if (isLoading) {
    return <LoadingSpinner />;
  }

  return (
    <ErrorBoundary>
      <div className="min-h-screen bg-white">
        <Navbar showDashboard={isAuthenticated} />
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route 
            path="/payment" 
            element={<PaymentPage onAuthFailure={handleAuthFailure} />} 
          />
          <Route 
            path="/signin" 
            element={<SignIn onSuccess={() => setIsAuthenticated(true)} />} 
          />
          <Route 
            path="/payment/verify" 
            element={
              <ProtectedRoute>
                <PaymentVerification />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/dashboard" 
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/success" 
            element={
              <ProtectedRoute>
                <SuccessPage />
              </ProtectedRoute>
            } 
          />
          <Route path="/404" element={<NotFound />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
        <Footer />
      </div>
    </ErrorBoundary>
  );
}

export default App;
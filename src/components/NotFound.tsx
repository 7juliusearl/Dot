import { motion } from 'framer-motion';
import { AlertTriangle, ArrowLeft, Home } from 'lucide-react';
import { useNavigate, useLocation } from 'react-router-dom';

const NotFound = () => {
  const navigate = useNavigate();
  const location = useLocation();

  const handleGoBack = () => {
    // If there's history, go back; otherwise go to payment or home
    if (window.history.length > 1) {
      navigate(-1);
    } else if (location.pathname.includes('payment')) {
      navigate('/payment');
    } else {
      navigate('/');
    }
  };

  const handleGoHome = () => {
    navigate('/');
  };

  const handleGoToPayment = () => {
    navigate('/payment');
  };

  return (
    <div className="min-h-screen bg-gray-50 py-20">
      <div className="container mx-auto px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="max-w-md mx-auto text-center"
        >
          <div className="bg-white rounded-xl p-8 shadow-lg">
            <AlertTriangle className="w-16 h-16 text-amber-500 mx-auto mb-6" />
            
            <h1 className="text-2xl font-bold text-charcoal mb-4">
              Oops! Page Not Found
            </h1>
            
            <p className="text-slate mb-8">
              {location.pathname.includes('payment') 
                ? "It looks like you were trying to access a payment page. Let's get you back on track!"
                : "The page you're looking for doesn't exist or may have been moved."
              }
            </p>

            <div className="space-y-3">
              <button
                onClick={handleGoBack}
                className="w-full flex items-center justify-center bg-sky text-slate px-6 py-3 rounded-lg hover:shadow-md transition-shadow"
              >
                <ArrowLeft className="w-5 h-5 mr-2" />
                Go Back
              </button>

              {location.pathname.includes('payment') && (
                <button
                  onClick={handleGoToPayment}
                  className="w-full flex items-center justify-center bg-green-600 text-white px-6 py-3 rounded-lg hover:shadow-md transition-shadow"
                >
                  Go to Payment Page
                </button>
              )}

              <button
                onClick={handleGoHome}
                className="w-full flex items-center justify-center bg-gray-600 text-white px-6 py-3 rounded-lg hover:shadow-md transition-shadow"
              >
                <Home className="w-5 h-5 mr-2" />
                Go Home
              </button>
            </div>

            <p className="text-sm text-slate mt-6">
              If you continue to experience issues, please contact us at{' '}
              <a 
                href="mailto:hello@dayoftimeline.app" 
                className="text-sky hover:underline"
              >
                hello@dayoftimeline.app
              </a>
            </p>
          </div>
        </motion.div>
      </div>
    </div>
  );
};

export default NotFound; 
import { useState, useEffect } from 'react';
import { createClient } from '@supabase/supabase-js';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { Mail, Lock, AlertCircle, CheckCircle, ArrowLeft, Eye, EyeOff } from 'lucide-react';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

interface SignInProps {
  onSuccess: () => void;
  email?: string;
}

const SignIn = ({ onSuccess, email = '' }: SignInProps) => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const redirect = searchParams.get('redirect');
  const plan = searchParams.get('plan');

  const [formData, setFormData] = useState({
    email: email,
    password: '',
    confirmPassword: '',
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // Check if this is a password reset flow to set initial state correctly
  const isPasswordResetFlow = () => {
    const resetParam = searchParams.get('reset');
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const type = hashParams.get('type');
    return resetParam === 'true' || type === 'recovery';
  };
  
  const [isSignUp, setIsSignUp] = useState(!isPasswordResetFlow());
  const [showForgotPassword, setShowForgotPassword] = useState(false);
  const [resetEmail, setResetEmail] = useState('');
  const [resetEmailSent, setResetEmailSent] = useState(false);
  const [resetLoading, setResetLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  // Password reset completion states
  const [showPasswordReset, setShowPasswordReset] = useState(false);
  const [newPasswordData, setNewPasswordData] = useState({
    password: '',
    confirmPassword: ''
  });
  const [newPasswordLoading, setNewPasswordLoading] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmNewPassword, setShowConfirmNewPassword] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    console.log('Authentication attempt:', { isSignUp, email: formData.email });

    try {
      if (isSignUp) {
        // Validation for sign-up
        if (formData.password !== formData.confirmPassword) {
          setError('Passwords do not match. Please make sure both passwords are identical.');
          return;
        }

        const { data, error: signUpError } = await supabase.auth.signUp({
          email: formData.email,
          password: formData.password,
        });

        console.log('Sign up response:', { data, error: signUpError });

        if (signUpError) {
          if (signUpError.message.includes('User already registered')) {
            setError('An account with this email already exists. Please sign in instead.');
            setIsSignUp(false); // Auto-switch to sign in mode
          } else if (signUpError.message.includes('Password')) {
            setError('Password must be at least 6 characters long.');
          } else if (signUpError.message.includes('Email')) {
            setError('Please enter a valid email address.');
          } else {
            setError(signUpError.message);
          }
          return;
        }

        // Check if sign up was successful
        if (data.user) {
          // Call onSuccess first to update parent state
          onSuccess();
          
          // For immediate access, proceed with the flow even if no session yet
          setTimeout(() => {
            if (redirect) {
              const redirectUrl = plan ? `${redirect}?plan=${plan}` : redirect;
              navigate(redirectUrl);
            } else {
              // Default redirect to dashboard for successful signup
              navigate('/dashboard');
            }
          }, 100);
        } else {
          setError('Account creation failed. Please try again.');
        }
      } else {
        const { data, error: signInError } = await supabase.auth.signInWithPassword({
          email: formData.email.trim(),
          password: formData.password,
        });

        console.log('Sign in response:', { data, error: signInError });

        if (signInError) {
          if (signInError.message.includes('Invalid login credentials')) {
            setError('Invalid email or password. Please check your credentials and try again.');
          } else if (signInError.message.includes('Email not confirmed')) {
            setError('Please check your email and confirm your account before signing in.');
          } else if (signInError.message.includes('Too many requests')) {
            setError('Too many login attempts. Please wait a few minutes and try again.');
          } else {
            console.error('Sign in error details:', signInError);
            setError(`Sign in failed: ${signInError.message}`);
          }
          return;
        }

        // Successful sign in
        if (data.session) {
          // Call onSuccess first to update parent state
          onSuccess();
          
          // Then handle redirect after a brief delay to ensure state is updated
          setTimeout(() => {
            if (redirect) {
              const redirectUrl = plan ? `${redirect}?plan=${plan}` : redirect;
              navigate(redirectUrl);
            } else {
              // Default redirect to dashboard for successful login
              navigate('/dashboard');
            }
          }, 100);
        } else {
          setError('Authentication failed. Please try again.');
        }
      }
    } catch (err: any) {
      console.error('Authentication error:', err);
      setError('An unexpected error occurred. Please check your internet connection and try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handlePasswordReset = async (e: React.FormEvent) => {
    e.preventDefault();
    setResetLoading(true);
    setError(null);

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(resetEmail, {
        redirectTo: `${window.location.origin}/signin?reset=true`,
      });

      if (error) {
        if (error.message.includes('Email not found')) {
          setError('No account found with this email address.');
        } else {
          setError(error.message);
        }
        return;
      }

      setResetEmailSent(true);
    } catch (err: any) {
      console.error('Password reset error:', err);
      setError('Failed to send reset email. Please try again.');
    } finally {
      setResetLoading(false);
    }
  };

  const handleNewPasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setNewPasswordLoading(true);
    setError(null);

    try {
      // Validation
      if (newPasswordData.password.length < 6) {
        throw new Error('Password must be at least 6 characters long');
      }

      if (newPasswordData.password !== newPasswordData.confirmPassword) {
        throw new Error('Passwords do not match');
      }

      // Update the user's password using Supabase's updateUser method
      const { error } = await supabase.auth.updateUser({
        password: newPasswordData.password
      });

      if (error) {
        throw new Error(error.message);
      }

      // Success! The user is now logged in with their new password
      onSuccess();
      
      // Redirect based on original intent
      setTimeout(() => {
        if (redirect) {
          const redirectUrl = plan ? `${redirect}?plan=${plan}` : redirect;
          navigate(redirectUrl);
        } else {
          navigate('/dashboard');
        }
      }, 100);

    } catch (err: any) {
      console.error('Password update error:', err);
      setError(err.message);
    } finally {
      setNewPasswordLoading(false);
    }
  };

  // Handle password reset redirect
  useEffect(() => {
    const resetParam = searchParams.get('reset');
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const accessToken = hashParams.get('access_token');
    const refreshToken = hashParams.get('refresh_token');
    const type = hashParams.get('type');
    
    console.log('Password reset detection:', { 
      resetParam, 
      hasAccessToken: !!accessToken, 
      hasRefreshToken: !!refreshToken, 
      type,
      fullHash: window.location.hash,
      fullURL: window.location.href 
    });
    
    // Check for password reset flow - either with reset=true param or recovery type in hash
    if ((resetParam === 'true') || (type === 'recovery')) {
      console.log('Password reset flow detected!');
      setShowPasswordReset(true);
      setIsSignUp(false);
      setShowForgotPassword(false);
      setError(null);
      
      // Set the session with the tokens if they exist
      if (accessToken && refreshToken) {
        console.log('Setting session with tokens');
        supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken
        });
      }
    } else {
      console.log('Normal sign-in flow');
    }
  }, [searchParams]);

  return (
    <div className="min-h-screen bg-gray-50 py-20" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="max-w-md mx-auto"
        >
          <div className="bg-white rounded-xl p-8 shadow-lg">
            <h2 className="text-2xl font-bold text-center text-charcoal mb-4">
              {showPasswordReset ? 'Set Your New Password' : (isSignUp ? 'Create your account' : 'Sign in to continue')}
            </h2>
            {redirect && !showPasswordReset && (
              <div className="bg-purple-50 border border-purple-200 rounded-lg p-4 mb-6">
                <p className="text-sm text-purple-800 text-center">
                  🚀 Almost there! {isSignUp ? 'Create your account' : 'Sign in'} to secure your beta access{plan && ` (${plan} plan)`}
                </p>
              </div>
            )}

            {showPasswordReset && (
              <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
                <p className="text-sm text-green-800 text-center">
                  🔐 You can now set a new password for your account. Enter your new password below.
                </p>
              </div>
            )}

            {showPasswordReset ? (
              <form onSubmit={handleNewPasswordSubmit} className="space-y-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    New Password
                  </label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                    <input
                      type={showNewPassword ? 'text' : 'password'}
                      value={newPasswordData.password}
                      onChange={(e) => setNewPasswordData({ ...newPasswordData, password: e.target.value })}
                      className="pl-10 pr-10 w-full rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-sky focus:border-transparent"
                      required
                      minLength={6}
                      placeholder="Enter your new password"
                    />
                    <button
                      type="button"
                      onClick={() => setShowNewPassword(!showNewPassword)}
                      className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      {showNewPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                    </button>
                  </div>
                  <p className="mt-2 text-sm text-gray-500">
                    Password must be at least 6 characters long
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Confirm New Password
                  </label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                    <input
                      type={showConfirmNewPassword ? 'text' : 'password'}
                      value={newPasswordData.confirmPassword}
                      onChange={(e) => setNewPasswordData({ ...newPasswordData, confirmPassword: e.target.value })}
                      className="pl-10 pr-10 w-full rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-sky focus:border-transparent"
                      required
                      placeholder="Confirm your new password"
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmNewPassword(!showConfirmNewPassword)}
                      className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      {showConfirmNewPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                    </button>
                  </div>
                </div>

                {error && (
                  <div className="flex items-center gap-2 text-red-600 bg-red-50 p-3 rounded-lg">
                    <AlertCircle className="h-5 w-5 flex-shrink-0" />
                    <p className="text-sm">{error}</p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={newPasswordLoading}
                  className={`w-full bg-charcoal text-white py-3 rounded-lg font-medium transition-all ${
                    newPasswordLoading ? 'opacity-75 cursor-not-allowed' : 'hover:bg-opacity-90 hover:shadow-lg'
                  }`}
                >
                  {newPasswordLoading ? (
                    <span className="flex items-center justify-center gap-2">
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                      Updating Password...
                    </span>
                  ) : (
                    'Update Password'
                  )}
                </button>
              </form>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Email address
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                  <input
                    type="email"
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    className="pl-10 w-full rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-sky focus:border-transparent"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    className="pl-10 pr-10 w-full rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-sky focus:border-transparent"
                    required
                    minLength={6}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                  </button>
                </div>
                {isSignUp && (
                  <p className="mt-2 text-sm text-gray-500">
                    Password must be at least 6 characters long
                  </p>
                )}
              </div>

              {isSignUp && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Confirm Password
                  </label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      value={formData.confirmPassword}
                      onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
                      className="pl-10 pr-10 w-full rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-sky focus:border-transparent"
                      required
                      placeholder="Confirm your password"
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                      className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      {showConfirmPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                    </button>
                  </div>
                </div>
              )}

              {error && (
                <div className="flex items-center gap-2 text-red-600 bg-red-50 p-3 rounded-lg">
                  <AlertCircle className="h-5 w-5 flex-shrink-0" />
                  <p className="text-sm">{error}</p>
                </div>
              )}

              <button
                type="submit"
                disabled={isLoading}
                className={`w-full bg-charcoal text-white py-3 rounded-lg font-medium transition-all ${
                  isLoading ? 'opacity-75 cursor-not-allowed' : 'hover:bg-opacity-90 hover:shadow-lg'
                }`}
              >
                {isLoading ? (
                  <span className="flex items-center justify-center gap-2">
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    {isSignUp ? 'Creating Account...' : 'Signing In...'}
                  </span>
                ) : (
                  isSignUp ? 'Create Account' : 'Sign In'
                )}
              </button>
            </form>
            )}

            {!showPasswordReset && (
              <div className="mt-8 text-center space-y-3">
                <button
                  onClick={() => {
                    setIsSignUp(!isSignUp);
                    setError(null);
                    setShowForgotPassword(false);
                    setResetEmailSent(false);
                    // Clear form data when switching modes
                    setFormData({
                      email: formData.email,
                      password: '',
                      confirmPassword: ''
                    });
                    setShowPassword(false);
                    setShowConfirmPassword(false);
                  }}
                  className="text-charcoal hover:text-sky font-medium transition-colors text-base"
                >
                  {isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"}
                </button>
              
              {!isSignUp && !showForgotPassword && (
                <div>
                  <button
                    onClick={() => {
                      setShowForgotPassword(true);
                      setResetEmail(formData.email);
                      setResetEmailSent(false);
                      setError(null);
                    }}
                    className="text-sm text-gray-600 hover:text-sky transition-colors"
                  >
                    Forgot your password?
                  </button>
                </div>
              )}

              {showForgotPassword && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  className="mt-6 p-6 bg-blue-50 rounded-lg border border-blue-200"
                >
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-medium text-blue-900">Reset Password</h3>
                    <button
                      onClick={() => {
                        setShowForgotPassword(false);
                        setResetEmailSent(false);
                        setError(null);
                      }}
                      className="text-blue-600 hover:text-blue-800"
                    >
                      <ArrowLeft size={20} />
                    </button>
                  </div>

                  {!resetEmailSent ? (
                    <form onSubmit={handlePasswordReset} className="space-y-4">
                      <div>
                        <label className="block text-sm font-medium text-blue-800 mb-2">
                          Email address
                        </label>
                        <div className="relative">
                          <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 text-blue-400 h-5 w-5" />
                          <input
                            type="email"
                            value={resetEmail}
                            onChange={(e) => setResetEmail(e.target.value)}
                            className="pl-10 w-full rounded-lg border border-blue-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                            placeholder="Enter your email address"
                            required
                          />
                        </div>
                      </div>

                      <button
                        type="submit"
                        disabled={resetLoading}
                        className={`w-full bg-blue-600 text-white py-2 rounded-lg font-medium transition-all ${
                          resetLoading ? 'opacity-75 cursor-not-allowed' : 'hover:bg-blue-700'
                        }`}
                      >
                        {resetLoading ? (
                          <span className="flex items-center justify-center gap-2">
                            <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                            Sending Reset Link...
                          </span>
                        ) : (
                          'Send Reset Link'
                        )}
                      </button>

                      <p className="text-sm text-blue-700">
                        We'll send you a secure link to reset your password.
                      </p>
                    </form>
                  ) : (
                    <div className="text-center">
                      <CheckCircle className="w-12 h-12 text-green-500 mx-auto mb-4" />
                      <h4 className="text-lg font-medium text-green-800 mb-2">
                        Reset Link Sent!
                      </h4>
                      <p className="text-green-700 mb-4">
                        We've sent a password reset link to <strong>{resetEmail}</strong>
                      </p>
                      <p className="text-sm text-green-600 mb-4">
                        Check your email and click the link to reset your password. The link will expire in 1 hour.
                      </p>
                      <button
                        onClick={() => {
                          setShowForgotPassword(false);
                          setResetEmailSent(false);
                        }}
                        className="text-blue-600 hover:text-blue-800 font-medium"
                      >
                        Back to Sign In
                      </button>
                    </div>
                  )}
                </motion.div>
              )}
              </div>
            )}
          </div>
        </motion.div>
      </div>
    </div>
  );
};

export default SignIn;
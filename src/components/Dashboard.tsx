import { useState, useEffect } from 'react';
import { createClient } from '@supabase/supabase-js';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { CreditCard, Calendar, AlertCircle, Loader2, CheckCircle, ExternalLink, AlertTriangle, Mail, Lock, Eye, EyeOff } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

interface Subscription {
  customer_id: string;
  subscription_id: string | null;
  subscription_status: 'not_started' | 'incomplete' | 'incomplete_expired' | 'trialing' | 'active' | 'past_due' | 'canceled' | 'unpaid' | 'paused';
  price_id: string | null;
  current_period_start: number | null;
  current_period_end: number | null;
  cancel_at_period_end: boolean;
  payment_method_brand: string | null;
  payment_method_last4: string | null;
  beta_user: boolean;
  payment_type: 'monthly' | 'lifetime' | null;
}

const Dashboard = () => {
  const [ref, inView] = useInView({
    triggerOnce: true,
    threshold: 0.1,
  });

  const navigate = useNavigate();
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [cancelLoading, setCancelLoading] = useState(false);
  const [syncLoading, setSyncLoading] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Password change states
  const [showPasswordChange, setShowPasswordChange] = useState(false);
  const [passwordData, setPasswordData] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: ''
  });
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [passwordSuccess, setPasswordSuccess] = useState<string | null>(null);
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const testFlightLink = "https://testflight.apple.com/join/cGYTUPH1";
  const disclaimer = "This TestFlight link is for your personal use only. Sharing this public link is strictly prohibited. If we discover that this link has been shared, your beta access program will be immediately canceled without any refunds.";

  useEffect(() => {
    fetchSubscription();
  }, []);

  const fetchSubscription = async () => {
    try {
      // Get the current user first
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      if (userError) throw userError;
      if (!user) throw new Error('No authenticated user');

      // First get the customer_id for this user
      const { data: customerData, error: customerError } = await supabase
        .from('stripe_customers')
        .select('customer_id')
        .eq('user_id', user.id)
        .single();

      if (customerError || !customerData) {
        console.log('No customer record found for user');
        setSubscription(null);
        return;
      }

      // Then get orders for this customer
      const { data: ordersData, error: ordersError } = await supabase
        .from('stripe_orders')
        .select('*')
        .eq('customer_id', customerData.customer_id)
        .eq('status', 'completed')
        .order('created_at', { ascending: false })
        .limit(1);

      if (ordersError) throw ordersError;

      if (ordersData && ordersData.length > 0) {
        // Set subscription data based on the completed order
        const orders = ordersData[0];
        const isLifetime = orders.purchase_type === 'lifetime';
        
        setSubscription({
          customer_id: orders.customer_id,
          subscription_id: orders.subscription_id || null,
          subscription_status: (orders.subscription_status as any) || 'active',
          price_id: orders.price_id || (isLifetime ? 'price_1RW02UInTpoMSXouhnQLA7Jn' : 'price_1RW01zInTpoMSXoua1wZb9zY'),
          current_period_start: orders.current_period_start || Math.floor(new Date(orders.created_at).getTime() / 1000),
          current_period_end: orders.current_period_end || (isLifetime ? null : Math.floor(new Date(orders.created_at).getTime() / 1000) + (30 * 24 * 60 * 60)),
          cancel_at_period_end: orders.cancel_at_period_end || false,
          payment_method_brand: orders.payment_method_brand || 'card',
          payment_method_last4: orders.payment_method_last4 || '****',
          beta_user: true,
          payment_type: orders.purchase_type as 'monthly' | 'lifetime'
        });
      } else {
        setSubscription(null);
      }
    } catch (err: any) {
      console.error('Error fetching subscription:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleCancelSubscription = async () => {
    if (!subscription?.subscription_id) return;

    try {
      setCancelLoading(true);
      setError(null);
      setSuccessMessage(null);

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('No active session');

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/stripe-cancel`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          subscription_id: subscription.subscription_id
        })
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to cancel subscription');
      }

      // Show success message
      setSuccessMessage('Your subscription has been successfully cancelled. You will continue to have access until the end of your current billing period.');
      
      // Refresh subscription data to show updated status
      await fetchSubscription();
    } catch (err: any) {
      console.error('Error canceling subscription:', err);
      setError(err.message);
    } finally {
      setCancelLoading(false);
    }
  };

  const handleSyncSubscription = async () => {
    try {
      setSyncLoading(true);
      setError(null);
      setSuccessMessage(null);

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('No active session');

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/stripe-sync`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          customer_id: subscription?.customer_id || 'auto' // Let the function find the customer ID
        })
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to sync subscription data');
      }

      setSuccessMessage('Subscription data has been successfully synchronized.');
      await fetchSubscription();
    } catch (err: any) {
      console.error('Error syncing subscription:', err);
      setError(err.message);
    } finally {
      setSyncLoading(false);
    }
  };

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordLoading(true);
    setPasswordError(null);
    setPasswordSuccess(null);

    try {
      // Validation
      if (passwordData.newPassword.length < 6) {
        throw new Error('New password must be at least 6 characters long');
      }

      if (passwordData.newPassword !== passwordData.confirmPassword) {
        throw new Error('New passwords do not match');
      }

      // Verify current password by attempting to sign in
      const { data: { user } } = await supabase.auth.getUser();
      if (!user?.email) throw new Error('No user email found');

      const { error: verifyError } = await supabase.auth.signInWithPassword({
        email: user.email,
        password: passwordData.currentPassword,
      });

      if (verifyError) {
        throw new Error('Current password is incorrect');
      }

      // Update password
      const { error: updateError } = await supabase.auth.updateUser({
        password: passwordData.newPassword
      });

      if (updateError) {
        throw new Error(updateError.message);
      }

      setPasswordSuccess('Password changed successfully!');
      setPasswordData({
        currentPassword: '',
        newPassword: '',
        confirmPassword: ''
      });
      
      // Auto-hide the form after success
      setTimeout(() => {
        setShowPasswordChange(false);
        setPasswordSuccess(null);
      }, 3000);

    } catch (err: any) {
      console.error('Password change error:', err);
      setPasswordError(err.message);
    } finally {
      setPasswordLoading(false);
    }
  };

  const getStatusDisplay = (status: string) => {
    switch (status) {
      case 'active':
        return 'Active';
      case 'canceled':
        return 'Canceled';
      case 'incomplete':
        return 'Payment Incomplete';
      case 'incomplete_expired':
        return 'Payment Failed';
      case 'past_due':
        return 'Payment Past Due';
      case 'trialing':
        return 'Trial';
      case 'unpaid':
        return 'Unpaid';
      default:
        return 'Processing';
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 py-20">
        <div className="container mx-auto px-4 flex items-center justify-center">
          <Loader2 className="w-8 h-8 animate-spin text-sky" />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 py-20" ref={ref}>
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={{ duration: 0.6 }}
          className="max-w-3xl mx-auto space-y-6"
        >
          <div className="bg-white rounded-xl p-8 shadow-lg">
            <h1 className="text-2xl font-bold text-charcoal mb-6">Account Dashboard</h1>

            {successMessage && (
              <div className="mb-6 bg-green-50 border border-green-200 rounded-lg p-4 flex items-start">
                <CheckCircle className="text-green-600 w-5 h-5 mt-0.5 mr-3 flex-shrink-0" />
                <div className="flex-1">
                  <p className="text-green-600">{successMessage}</p>
                  <button
                    onClick={() => setSuccessMessage(null)}
                    className="text-green-700 hover:text-green-800 text-sm font-medium mt-2"
                  >
                    Dismiss
                  </button>
                </div>
              </div>
            )}

            {error && (
              <div className="mb-6 bg-red-50 border border-red-200 rounded-lg p-4 flex items-start">
                <AlertCircle className="text-red-600 w-5 h-5 mt-0.5 mr-3 flex-shrink-0" />
                <div className="flex-1">
                  <p className="text-red-600 mb-3">{error}</p>
                  {error.includes('No such subscription') && (
                    <button
                      onClick={handleSyncSubscription}
                      disabled={syncLoading}
                      className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium"
                    >
                      {syncLoading ? (
                        <span className="flex items-center">
                          <Loader2 className="w-4 h-4 animate-spin mr-2" />
                          Syncing...
                        </span>
                      ) : (
                        'Sync Subscription Data'
                      )}
                    </button>
                  )}
                </div>
              </div>
            )}

            {subscription ? (
              <div className="space-y-6">
                <div className="flex items-center justify-between pb-6 border-b border-gray-100">
                  <div className="flex items-center">
                    <div className={`p-3 rounded-lg mr-4 ${
                      subscription.cancel_at_period_end 
                        ? 'bg-orange-100' 
                        : 'bg-sky bg-opacity-10'
                    }`}>
                      {subscription.cancel_at_period_end ? (
                        <AlertTriangle className="text-orange-600 w-6 h-6" />
                      ) : (
                        <CheckCircle className="text-sky w-6 h-6" />
                      )}
                    </div>
                    <div>
                      <p className="font-medium text-charcoal">Subscription Status</p>
                      <p className="text-slate">{getStatusDisplay(subscription.subscription_status)}</p>
                      {subscription.current_period_end && subscription.payment_type === 'monthly' && subscription.subscription_status !== 'canceled' && (
                        <p className="text-sm text-slate">
                          {subscription.cancel_at_period_end 
                            ? `Access until ${new Date(subscription.current_period_end * 1000).toLocaleDateString()}`
                            : `Next billing date: ${new Date(subscription.current_period_end * 1000).toLocaleDateString()}`
                          }
                        </p>
                      )}
                      {subscription.subscription_status === 'canceled' && (
                        <p className="text-sm text-red-600">
                          Your subscription has been canceled
                        </p>
                      )}
                    </div>
                  </div>
                  <span className={`px-3 py-1 rounded-full text-sm font-medium ${
                    subscription.payment_type === 'lifetime' 
                      ? 'bg-purple-100 text-purple-800' 
                      : subscription.subscription_status === 'canceled'
                        ? 'bg-red-100 text-red-800'
                        : subscription.cancel_at_period_end 
                          ? 'bg-orange-100 text-orange-800' 
                          : 'bg-blue-100 text-blue-800'
                  }`}>
                    {subscription.payment_type === 'lifetime' 
                      ? 'Lifetime Access' 
                      : subscription.subscription_status === 'canceled'
                        ? 'Canceled'
                        : subscription.cancel_at_period_end 
                          ? 'Cancelling' 
                          : 'Monthly'}
                  </span>
                </div>

                {subscription.payment_method_brand && (
                  <div className="flex items-center justify-between pb-6 border-b border-gray-100">
                    <div className="flex items-center">
                      <div className="bg-sky bg-opacity-10 p-3 rounded-lg mr-4">
                        <CreditCard className="text-sky w-6 h-6" />
                      </div>
                      <div>
                        <p className="font-medium text-charcoal">Payment Method</p>
                        <p className="text-slate">
                          {subscription.payment_method_brand.charAt(0).toUpperCase() + 
                           subscription.payment_method_brand.slice(1)} •••• {subscription.payment_method_last4}
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                <div className="flex items-center justify-between pb-6 border-b border-gray-100">
                  <div className="flex items-center">
                    <div className="bg-sky bg-opacity-10 p-3 rounded-lg mr-4">
                      <Calendar className="text-sky w-6 h-6" />
                    </div>
                    <div>
                      <p className="font-medium text-charcoal">Beta Access</p>
                      <p className="text-slate">
                        {subscription.beta_user ? 'Early Access Member' : 'Regular Member'}
                      </p>
                    </div>
                  </div>
                  <span className={`px-3 py-1 rounded-full text-sm font-medium ${
                    subscription.beta_user ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                  }`}>
                    {subscription.beta_user ? 'Beta User' : 'Regular User'}
                  </span>
                </div>

                {/* Password Change Section */}
                <div className="border-b border-gray-100 pb-6">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center">
                      <div className="bg-sky bg-opacity-10 p-3 rounded-lg mr-4">
                        <Lock className="text-sky w-6 h-6" />
                      </div>
                      <div>
                        <p className="font-medium text-charcoal">Password & Security</p>
                        <p className="text-slate">Manage your account password</p>
                      </div>
                    </div>
                    <button
                      onClick={() => {
                        setShowPasswordChange(!showPasswordChange);
                        setPasswordError(null);
                        setPasswordSuccess(null);
                        setPasswordData({
                          currentPassword: '',
                          newPassword: '',
                          confirmPassword: ''
                        });
                      }}
                      className="text-sky hover:text-sky/80 font-medium transition-colors"
                    >
                      {showPasswordChange ? 'Cancel' : 'Change Password'}
                    </button>
                  </div>

                  {showPasswordChange && (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      exit={{ opacity: 0, height: 0 }}
                      className="mt-6 bg-gray-50 border border-gray-200 rounded-lg p-6"
                    >
                      <form onSubmit={handlePasswordChange} className="space-y-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">
                            Current Password
                          </label>
                          <div className="relative">
                            <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                            <input
                              type={showCurrentPassword ? 'text' : 'password'}
                              value={passwordData.currentPassword}
                              onChange={(e) => setPasswordData({ ...passwordData, currentPassword: e.target.value })}
                              className="pl-10 pr-10 w-full rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-sky focus:border-transparent"
                              required
                              placeholder="Enter your current password"
                            />
                            <button
                              type="button"
                              onClick={() => setShowCurrentPassword(!showCurrentPassword)}
                              className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                            >
                              {showCurrentPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                            </button>
                          </div>
                        </div>

                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">
                            New Password
                          </label>
                          <div className="relative">
                            <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                            <input
                              type={showNewPassword ? 'text' : 'password'}
                              value={passwordData.newPassword}
                              onChange={(e) => setPasswordData({ ...passwordData, newPassword: e.target.value })}
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
                          <p className="mt-1 text-sm text-gray-500">
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
                              type={showConfirmPassword ? 'text' : 'password'}
                              value={passwordData.confirmPassword}
                              onChange={(e) => setPasswordData({ ...passwordData, confirmPassword: e.target.value })}
                              className="pl-10 pr-10 w-full rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-sky focus:border-transparent"
                              required
                              placeholder="Confirm your new password"
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

                        {passwordError && (
                          <div className="flex items-center gap-2 text-red-600 bg-red-50 p-3 rounded-lg">
                            <AlertCircle className="h-5 w-5 flex-shrink-0" />
                            <p className="text-sm">{passwordError}</p>
                          </div>
                        )}

                        {passwordSuccess && (
                          <div className="flex items-center gap-2 text-green-600 bg-green-50 p-3 rounded-lg">
                            <CheckCircle className="h-5 w-5 flex-shrink-0" />
                            <p className="text-sm">{passwordSuccess}</p>
                          </div>
                        )}

                        <div className="flex gap-3 pt-2">
                          <button
                            type="submit"
                            disabled={passwordLoading}
                            className={`bg-sky text-slate px-6 py-2 rounded-lg font-medium transition-all ${
                              passwordLoading ? 'opacity-75 cursor-not-allowed' : 'hover:shadow-lg'
                            }`}
                          >
                            {passwordLoading ? (
                              <span className="flex items-center gap-2">
                                <Loader2 className="w-4 h-4 animate-spin" />
                                Updating...
                              </span>
                            ) : (
                              'Update Password'
                            )}
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              setShowPasswordChange(false);
                              setPasswordError(null);
                              setPasswordSuccess(null);
                            }}
                            className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
                          >
                            Cancel
                          </button>
                        </div>
                      </form>
                    </motion.div>
                  )}
                </div>

                <div className="bg-blue-50 border border-blue-100 rounded-xl p-8 mb-8">
                  <div className="flex items-center mb-4">
                    <div className="bg-blue-100 rounded-full p-3">
                      <Mail className="text-blue-600 w-6 h-6" />
                    </div>
                  </div>
                  <h2 className="text-xl font-semibold text-blue-900 mb-4">TestFlight Access</h2>
                  <p className="text-blue-800 mb-4">
                    Your beta access is ready! Click the link below to join the TestFlight beta and download the app immediately.
                  </p>
                  
                  <div className="bg-blue-100 border border-blue-200 rounded-lg p-4 mb-6">
                    <h3 className="font-semibold text-blue-900 mb-2">📱 Setting Up Your Account</h3>
                    <p className="text-blue-800 text-sm">
                      When you open the app for the first time, you'll need to create a new user account. 
                      <strong> Please use the same email and password you used here</strong> to ensure seamless access to your beta features.
                    </p>
                  </div>

                  <div className="text-center">
                    <a
                      href={testFlightLink}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center justify-center bg-sky text-slate px-6 py-3 rounded-full font-medium hover:shadow-lg transition-shadow"
                    >
                      Join TestFlight Beta <ExternalLink className="ml-2 w-5 h-5" />
                    </a>
                  </div>
                  <div className="mt-6 bg-red-50 border border-red-200 rounded-lg p-4">
                    <div className="flex items-start">
                      <AlertTriangle className="text-red-600 w-5 h-5 mt-1 mr-3 flex-shrink-0" />
                      <div>
                        <h3 className="text-md font-semibold text-red-800 mb-2">Important Disclaimer:</h3>
                        <p className="text-red-700 text-sm">{disclaimer}</p>
                      </div>
                    </div>
                  </div>
                </div>

                {subscription.subscription_status === 'active' && 
                 subscription.payment_type === 'monthly' && (
                  <div className="flex justify-end">
                    {subscription.subscription_id ? (
                      <button
                        onClick={handleCancelSubscription}
                        disabled={cancelLoading || subscription.cancel_at_period_end}
                        className={`text-red-600 hover:text-red-700 font-medium ${
                          (cancelLoading || subscription.cancel_at_period_end) ? 'opacity-50 cursor-not-allowed' : ''
                        }`}
                      >
                        {cancelLoading ? (
                          <span className="flex items-center">
                            <Loader2 className="w-4 h-4 animate-spin mr-2" />
                            Canceling...
                          </span>
                        ) : subscription.cancel_at_period_end ? (
                          'Subscription will end at current period'
                        ) : (
                          'Cancel Subscription'
                        )}
                      </button>
                    ) : (
                      <div className="text-center">
                        <p className="text-sm text-slate mb-2">
                          To cancel your subscription, please email us at:
                        </p>
                        <a 
                          href="mailto:hello@dayoftimeline.app" 
                          className="text-sky hover:text-sky/80 font-medium"
                        >
                          hello@dayoftimeline.app
                        </a>
                      </div>
                    )}
                  </div>
                )}
              </div>
            ) : (
              <div className="text-center py-6">
                <Calendar className="w-12 h-12 text-sky mx-auto mb-4" />
                <h3 className="text-xl font-semibold text-charcoal mb-2">No Active Subscription</h3>
                <p className="text-slate mb-8">
                  You currently don't have an active subscription.
                </p>
                <button
                  onClick={() => navigate('/payment')}
                  className="bg-sky text-slate px-6 py-3 rounded-lg hover:shadow-md transition-shadow"
                >
                  View Available Plans
                </button>
              </div>
            )}
          </div>
        </motion.div>
      </div>
    </div>
  );
};

export default Dashboard;
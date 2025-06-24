import { createClient } from '@supabase/supabase-js';
import { supabaseConfig } from './config';

// Create a single Supabase client instance that will be shared across the app
export const supabase = createClient(
  supabaseConfig.url,
  supabaseConfig.anonKey,
  {
    auth: {
      // Ensure consistent auth storage
      storageKey: 'dayoftimeline-auth',
      storage: window.localStorage,
      persistSession: true,
      detectSessionInUrl: true,
      autoRefreshToken: true,
    },
  }
);

// Export the client as default for convenience
export default supabase; 
// Environment configuration and validation utility

interface Config {
  supabase: {
    url: string;
    anonKey: string;
  };
  app: {
    baseUrl: string;
    environment: 'development' | 'production';
  };
}

function validateEnvironment(): Config {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
  
  if (!supabaseUrl) {
    throw new Error('VITE_SUPABASE_URL is required');
  }
  
  if (!supabaseAnonKey) {
    throw new Error('VITE_SUPABASE_ANON_KEY is required');
  }

  // Determine environment and base URL
  const isDevelopment = import.meta.env.DEV;
  const baseUrl = isDevelopment 
    ? 'http://localhost:5173'
    : 'https://dayoftimeline.app';

  return {
    supabase: {
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    },
    app: {
      baseUrl,
      environment: isDevelopment ? 'development' : 'production',
    },
  };
}

// Validate and export configuration
export const config = validateEnvironment();

// Utility function to check if origin is allowed
export function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return false;
  
  const allowedOrigins = [
    'https://dayoftimeline.app',
    'https://www.dayoftimeline.app',
    'http://localhost:5173',
    'http://localhost:3000',
    'http://127.0.0.1:5173',
  ];
  
  return allowedOrigins.includes(origin);
}

// Export individual config values for convenience
export const { supabase: supabaseConfig, app: appConfig } = config; 
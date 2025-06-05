import { Loader2 } from 'lucide-react';

const LoadingSpinner = () => {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="text-center">
        <Loader2 className="w-8 h-8 text-sky animate-spin mx-auto mb-4" />
        <p className="text-slate font-medium">Loading...</p>
      </div>
    </div>
  );
};

export default LoadingSpinner; 
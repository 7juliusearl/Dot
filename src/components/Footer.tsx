import { Instagram } from 'lucide-react';

const Footer = () => {
  return (
    <footer className="py-10 bg-white">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col items-center">
          <div className="flex items-center mb-6">
            <div className="relative">
              <img 
                src="/dot-logo.png" 
                alt="DOT Logo" 
                className="h-8 w-8 mr-3 rounded-full"
                onError={(e) => {
                  console.error('Footer logo failed to load:', e);
                  e.currentTarget.style.display = 'none';
                  const fallback = e.currentTarget.nextElementSibling as HTMLElement;
                  if (fallback) fallback.style.display = 'flex';
                }}
              />
              {/* Fallback logo with gradient matching user's design */}
              <div 
                className="h-8 w-8 mr-3 rounded-full flex items-center justify-center text-white font-bold text-sm"
                style={{ 
                  display: 'none',
                  background: 'linear-gradient(135deg, #D2B48C 0%, #87CEEB 100%)'
                }}
              >
                t.
              </div>
            </div>
            <span className="text-xl font-bold text-charcoal">Day of Timeline - Dot</span>
          </div>
          
          <div className="text-center mb-6">
            <p className="text-sm text-slate">
              &copy; {new Date().getFullYear()} Day of Timeline - Dot. All rights reserved.
            </p>
          </div>
          
          <div className="flex flex-wrap justify-center gap-4">
            <a href="#" className="text-sm text-slate hover:text-sky transition-colors">
              Privacy Policy
            </a>
            <a href="#" className="text-sm text-slate hover:text-sky transition-colors">
              Terms of Service
            </a>
            <a href="#" className="text-sm text-slate hover:text-sky transition-colors">
              Legal
            </a>
            <a href="#" className="text-sm text-slate hover:text-sky transition-colors">
              Sitemap
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer
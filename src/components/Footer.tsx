import { Instagram } from 'lucide-react';

const Footer = () => {
  return (
    <footer className="py-10 bg-white">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col items-center">
          <div className="flex items-center mb-6">
            <img 
              src="/dot-Icon.png" 
              alt="DOT Logo" 
              className="h-8 w-8 mr-3"
            />
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
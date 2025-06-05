import { Instagram } from 'lucide-react';

const Footer = () => {
  return (
    <footer className="py-10 bg-white">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col items-center">
          <div className="flex items-center mb-6">
            <img 
              src="/new-Icon.png" 
              alt="DOT Logo" 
              className="h-6 w-6 mr-2"
            />
            <span className="text-xl font-bold text-gray-900">Day of Timeline - Dot</span>
          </div>
          
          <div className="text-center mb-6">
            <p className="text-sm text-gray-500">
              &copy; {new Date().getFullYear()} Day of Timeline - Dot. All rights reserved.
            </p>
          </div>
          
          <div className="flex flex-wrap justify-center gap-4">
            <a href="#" className="text-sm text-gray-600 hover:text-teal-600 transition-colors">
              Privacy Policy
            </a>
            <a href="#" className="text-sm text-gray-600 hover:text-teal-600 transition-colors">
              Terms of Service
            </a>
            <a href="#" className="text-sm text-gray-600 hover:text-teal-600 transition-colors">
              Legal
            </a>
            <a href="#" className="text-sm text-gray-600 hover:text-teal-600 transition-colors">
              Sitemap
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer
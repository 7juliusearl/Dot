export interface Feature {
  id: number;
  title: string;
  description: string;
  icon: string;
}

export interface TabContent {
  id: string;
  title: string;
  heading: string;
  description: string;
  content: string;
  image: string;
  imagePosition: 'left' | 'right';
}

export interface Testimonial {
  id: number;
  name: string;
  location: string;
  quote: string;
  avatar: string;
}

export interface PricingPlan {
  id: number;
  name: string;
  price: string;
  popular?: boolean;
  features: {
    included: string[];
    excluded: string[];
  };
}

export interface FAQ {
  id: number;
  question: string;
  answer: string;
}

export interface Screenshot {
  id: number;
  image: string;
  alt: string;
}

export interface WaitlistEntry {
  id: string;
  email: string;
  created_at: string;
  status: 'pending' | 'notified' | 'converted';
}
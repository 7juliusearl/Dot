/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        'sand': '#E4DBC0',
        'silver': '#CBD5DE',
        'sky': '#D1DDF1',
        'slate': '#4A4B4C',
        'charcoal': '#2A2B2D',
      },
    },
  },
  plugins: [],
};
#!/bin/bash

# Day of Timeline Deployment Script
echo "🚀 Starting deployment process..."

# Build the project
echo "📦 Building project..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📁 Build output ready in ./dist/"
    echo ""
    echo "🌐 Next steps:"
    echo "1. Use VS Code Command Palette (Cmd+Shift+P)"
    echo "2. Run 'Netlify: Deploy to Netlify'"
    echo "3. Select the ./dist folder"
    echo ""
    echo "Or drag the ./dist folder to netlify.com"
    echo ""
    echo "⚠️  Don't forget to set environment variables in Netlify:"
    echo "   VITE_SUPABASE_URL"
    echo "   VITE_SUPABASE_ANON_KEY"
else
    echo "❌ Build failed. Please fix errors and try again."
    exit 1
fi 
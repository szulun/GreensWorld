#!/bin/bash

# Environment Setup Script for GreensWrld Flutter Frontend
echo "🔧 Setting up environment variables for Flutter Frontend..."

# Check if .env file exists
if [ -f ".env" ]; then
    echo "✅ .env file already exists"
    echo "📋 Current .env contents:"
    cat .env
else
    echo "📝 Creating .env file..."
    cat > .env << EOF
# Flutter Frontend Environment Configuration

# API Configuration
API_URL=http://localhost:3001/api

# Google Maps API Configuration
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIzaSyCKU4p-ODKvmZqEQH8sxxLrCv5auTEAQYE

# Environment
ENVIRONMENT=development
EOF
    echo "✅ .env file created successfully"
fi

echo ""
echo "🔍 Environment validation:"
echo "  - API_URL: $(grep API_URL .env | cut -d'=' -f2)"
echo "  - GOOGLE_MAPS_API_KEY: $(grep NEXT_PUBLIC_GOOGLE_MAPS_API_KEY .env | cut -d'=' -f2 | cut -c1-20)..."
echo "  - ENVIRONMENT: $(grep ENVIRONMENT .env | cut -d'=' -f2)"

echo ""
echo "🎯 Next steps:"
echo "  1. Make sure your backend is running on http://localhost:3001"
echo "  2. Run 'flutter run -d chrome' to test the app"
echo "  3. Check browser console for any environment-related errors"
echo ""
echo "💡 Note: .env file is gitignored for security reasons"

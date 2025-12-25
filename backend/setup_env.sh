#!/bin/bash

# Environment Setup Script for GreensWrld Backend
echo "🔧 Setting up environment variables for Backend..."

# Check if .env file exists
if [ -f ".env" ]; then
    echo "✅ .env file already exists"
    echo "📋 Current .env contents:"
    cat .env
else
    echo "📝 Creating .env file..."
    cat > .env << EOF
# Backend Environment Configuration

# Server Configuration
NODE_ENV=development
PORT=3001

# Firebase Configuration
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyDG03gfg0f-_qXQrHe8fGgL7freoRuQeqM
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=greensworld-c2918.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=greensworld-c2918
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=greensworld-c2918.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=118532775984
NEXT_PUBLIC_FIREBASE_APP_ID=1:118532775984:web:d2af930a8efcea15318df5

# Google AI API Key
GOOGLE_AI_API_KEY=AIzaSyDG03gfg0f-_qXQrHe8fGgL7freoRuQeqM

# Google Maps API Keys
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIzaSyCKU4p-ODKvmZqEQH8sxxLrCv5auTEAQYE
GENKIT_API_KEY=AIzaSyAyGJxgrCOq-rPMk_8CxJZcB2hgVWZOyjg

# API Configuration
API_URL=http://localhost:3001/api
EOF
    echo "✅ .env file created successfully"
fi

echo ""
echo "🔍 Environment validation:"
echo "  - NODE_ENV: $(grep NODE_ENV .env | cut -d'=' -f2)"
echo "  - PORT: $(grep PORT .env | cut -d'=' -f2)"
echo "  - FIREBASE_PROJECT_ID: $(grep NEXT_PUBLIC_FIREBASE_PROJECT_ID .env | cut -d'=' -f2)"
echo "  - GOOGLE_AI_API_KEY: $(grep GOOGLE_AI_API_KEY .env | cut -d'=' -f2 | cut -c1-20)..."
echo "  - GOOGLE_MAPS_API_KEY: $(grep NEXT_PUBLIC_GOOGLE_MAPS_API_KEY .env | cut -d'=' -f2 | cut -c1-20)..."

echo ""
echo "🎯 Next steps:"
echo "  1. Install dependencies: npm install"
echo "  2. Start the server: npm start"
echo "  3. Server will run on http://localhost:3001"
echo ""
echo "💡 Note: .env file is gitignored for security reasons"

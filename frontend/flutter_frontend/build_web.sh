#!/bin/bash

# Build script for Flutter Web with environment variable replacement
echo "🔧 Building Flutter Web with environment variables..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found!"
    echo "💡 Please run ./setup_env.sh first"
    exit 1
fi

# Load environment variables
export $(cat .env | xargs)

# Validate required variables
if [ -z "$NEXT_PUBLIC_GOOGLE_MAPS_API_KEY" ]; then
    echo "❌ Error: NEXT_PUBLIC_GOOGLE_MAPS_API_KEY not found in .env"
    exit 1
fi

if [ -z "$API_URL" ]; then
    echo "❌ Error: API_URL not found in .env"
    exit 1
fi

echo "✅ Environment variables loaded:"
echo "  - API_URL: $API_URL"
echo "  - GOOGLE_MAPS_API_KEY: ${NEXT_PUBLIC_GOOGLE_MAPS_API_KEY:0:20}..."

# Build Flutter web with environment variables
echo "🚀 Building Flutter web..."
flutter build web \
    --dart-define=NEXT_PUBLIC_GOOGLE_MAPS_API_KEY="$NEXT_PUBLIC_GOOGLE_MAPS_API_KEY" \
    --dart-define=API_URL="$API_URL" \
    --dart-define=ENVIRONMENT="$ENVIRONMENT"

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🌐 Your app is ready in build/web/"
    echo "💡 To serve locally: cd build/web && python3 -m http.server 8000"
else
    echo "❌ Build failed!"
    exit 1
fi

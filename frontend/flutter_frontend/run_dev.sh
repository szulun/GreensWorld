#!/bin/bash

# Development run script for Flutter Web with environment variables
echo "🚀 Running Flutter Web in development mode..."

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

# Run Flutter web with environment variables
echo "🌐 Starting Flutter web development server..."
flutter run -d chrome \
    --dart-define=NEXT_PUBLIC_GOOGLE_MAPS_API_KEY="$NEXT_PUBLIC_GOOGLE_MAPS_API_KEY" \
    --dart-define=API_URL="$API_URL" \
    --dart-define=ENVIRONMENT="$ENVIRONMENT"

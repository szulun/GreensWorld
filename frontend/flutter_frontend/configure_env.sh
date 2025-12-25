#!/bin/bash

# Environment configuration script for Flutter Web
echo "🔧 Configuring environment variables for Flutter Web..."

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

# Create a temporary HTML file with replaced variables
echo "📝 Updating web/index.html with environment variables..."

# Backup original file
cp web/index.html web/index.html.backup

# Replace environment variables in HTML
sed -i.bak "s|%NEXT_PUBLIC_GOOGLE_MAPS_API_KEY%|$NEXT_PUBLIC_GOOGLE_MAPS_API_KEY|g" web/index.html
sed -i.bak "s|%API_URL%|$API_URL|g" web/index.html

echo "✅ HTML file updated successfully"
echo "💡 Original file backed up as web/index.html.backup"

# Show the changes
echo ""
echo "🔍 Changes made to web/index.html:"
grep -n "AIzaSyCKU4p-ODKvmZqEQH8sxxLrCv5auTEAQYE" web/index.html || echo "No API key found in HTML"

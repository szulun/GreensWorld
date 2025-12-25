# 🌍 Environment Setup Guide

This guide explains how to set up environment variables for the GreensWrld project.

## 📁 Project Structure

```
GreensWrld_0812/
├── frontend/
│   └── flutter_frontend/
│       ├── .env                    # Flutter frontend environment variables
│       └── setup_env.sh            # Setup script for frontend
├── backend/
│   ├── .env                        # Backend environment variables
│   └── setup_env.sh                # Setup script for backend
└── ENVIRONMENT_SETUP.md            # This file
```

## 🚀 Quick Setup

### 1. Flutter Frontend Setup

```bash
cd frontend/flutter_frontend
./setup_env.sh
```

Or manually create `.env` file:
```env
# Flutter Frontend Environment Configuration
API_URL=http://localhost:3001/api
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIzaSyCKU4p-ODKvmZqEQH8sxxLrCv5auTEAQYE
ENVIRONMENT=development
```

### 2. Backend Setup

```bash
cd backend
./setup_env.sh
```

Or manually create `.env` file:
```env
# Backend Environment Configuration
NODE_ENV=development
PORT=3001
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyDG03gfg0f-_qXQrHe8fGgL7freoRuQeqM
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=greensworld-c2918.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=greensworld-c2918
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=greensworld-c2918.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=118532775984
NEXT_PUBLIC_FIREBASE_APP_ID=1:118532775984:web:d2af930a8efcea15318df5
GOOGLE_AI_API_KEY=AIzaSyDG03gfg0f-_qXQrHe8fGgL7freoRuQeqM
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIzaSyCKU4p-ODKvmZqEQH8sxxLrCv5auTEAQYE
GENKIT_API_KEY=AIzaSyAyGJxgrCOq-rPMk_8CxJZcB2hgVWZOyjg
API_URL=http://localhost:3001/api
```

## 🔑 API Keys Included

### Google Maps API
- **Key**: `AIzaSyCKU4p-ODKvmZqEQH8sxxLrCv5auTEAQYE`
- **Services**: Maps JavaScript API, Geocoding API, Places API
- **Usage**: Map display, location search, address geocoding

### Firebase Configuration
- **Project ID**: `greensworld-c2918`
- **Services**: Authentication, Firestore, Storage
- **Usage**: User management, data storage, file uploads

### Google AI API
- **Key**: `AIzaSyDG03gfg0f-_qXQrHe8fGgL7freoRuQeqM`
- **Service**: Google Generative AI
- **Usage**: AI-powered features

### Genkit API
- **Key**: `AIzaSyAyGJxgrCOq-rPMk_8CxJZcB2hgVWZOyjg`
- **Service**: Google Genkit
- **Usage**: AI model management

## 🛡️ Security Notes

- **`.env` files are gitignored** - They won't be committed to version control
- **API keys are sensitive** - Never share them publicly
- **Environment-specific** - Different values for development/production

## 🧪 Testing Environment

### Frontend Test
```bash
cd frontend/flutter_frontend
flutter run -d chrome
```

### Backend Test
```bash
cd backend
npm install
npm start
```

## 🔍 Troubleshooting

### Common Issues

1. **Environment variables not loading**
   - Check if `.env` files exist
   - Verify file permissions
   - Restart the application

2. **API key errors**
   - Verify API keys are correct
   - Check if services are enabled in Google Cloud Console
   - Ensure billing is set up for Google Cloud project

3. **CORS issues**
   - Check backend CORS configuration
   - Verify API_URL matches backend port

### Validation

Both setup scripts include validation to check if environment variables are properly loaded.

## 📚 Additional Resources

- [Flutter Environment Variables](https://docs.flutter.dev/deployment/environment-variables)
- [Node.js Environment Variables](https://nodejs.org/docs/latest/api/process.html#processenv)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Firebase Console](https://console.firebase.google.com/)

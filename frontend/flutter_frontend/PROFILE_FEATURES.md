# Profile Features Implementation

## Overview
This document describes the new profile functionality that has been added to the GreensWrld Flutter application.

## New Features

### 1. Profile Page (`/profile`)
- **Location**: `lib/pages/profile_page.dart`
- **Features**:
  - View and edit username
  - Add/edit bio
  - View account information (email, member since, last updated)
  - Profile picture placeholder with username initial
  - Edit mode with save/cancel functionality
  - Logout functionality

### 2. Updated Signup Page
- **Location**: `lib/pages/signup_page.dart`
- **Changes**:
  - Added username field
  - Added first name and last name fields
  - All fields are saved to Firestore during signup
  - Google Sign-In now creates user data in Firestore
  - Username validation and uniqueness checking

### 3. Updated Navbar
- **Location**: `lib/widgets/navbar_home.dart`
- **Changes**:
  - Shows first name with username (@username) underneath when logged in
  - Added "Profile" button for logged-in users
  - Added profile option to mobile menu
  - Fetches user data from Firestore

### 4. Backend Updates
- **Location**: `backend/controllers/userControllers.js`
- **Changes**:
  - Added username uniqueness validation
  - Enhanced user creation with username support
  - Updated user model to include username field

## Database Schema

### User Document Structure (Firestore)
```javascript
{
  username: "string",           // Required, unique
  firstName: "string",          // Required
  lastName: "string",           // Required
  email: "string",              // Required, unique
  bio: "string",                // Optional
  createdAt: "timestamp",       // Auto-generated
  updatedAt: "timestamp",       // Auto-updated
  // Note: password is handled by Firebase Auth
}
```

## Dependencies Added
- `cloud_firestore: ^5.6.2` - For Firestore database operations

## Routes Added
- `/profile` - Profile page route

## Usage

### For Users:
1. **Signup**: Enter username, first name, and last name during registration
2. **Login**: First name with username (@username) will be displayed in navbar
3. **Profile**: Click "Profile" button to view/edit profile
4. **Edit Profile**: Click edit icon to modify username, first name, last name, and bio

### For Developers:
1. **Access Profile**: Navigate to `/profile` route
2. **User Data**: Access via `FirebaseFirestore.instance.collection('users').doc(uid)`
3. **Username Display**: Navbar automatically fetches and displays username

## Error Handling
- Username uniqueness validation
- Firebase offline handling
- Graceful fallback to email if username not available
- Loading states for async operations

## Security
- Username validation (minimum 2 characters)
- Firestore security rules should be configured
- Password handling remains with Firebase Auth

## Future Enhancements
- Profile picture upload
- Username change history
- Social media links
- Plant collection display
- Activity feed 
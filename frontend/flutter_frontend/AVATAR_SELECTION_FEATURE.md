# Avatar Selection Feature Implementation

This document describes the implementation of the avatar selection feature for the GreensWrld Flutter app.

## Overview

The avatar selection feature allows users to:
1. Choose from 5 default avatars during signup
2. Change their avatar later through the profile page
3. Upload custom images from their device
4. Select from default avatars at any time

## Features Implemented

### 1. New User Avatar Selection
- **Location**: `lib/pages/avatar_selection_page.dart`
- **Trigger**: After successful signup (both email/password and Google Sign-In)
- **Flow**: 
  - User completes signup → Redirected to avatar selection page
  - User can choose from 5 default avatars or skip
  - Selection is saved to Firestore with `hasSelectedAvatar: true`

### 2. Profile Page Avatar Management
- **Location**: `lib/pages/profile_page.dart`
- **Features**:
  - Dropdown menu with "From Files" and "Choose Default Avatar" options
  - File format validation (.png, .jpg, .jpeg only)
  - Error handling for unsupported file types
  - Support for both local assets and network images

### 3. Default Avatars
The following 5 default avatars are available:
- **Dandelion** (`dandelionpfp.png`) - Free-spirited and resilient
- **Orchid** (`orchidpfp.png`) - Elegant and sophisticated  
- **Coconut** (`coconutonbeachpfp.png`) - Tropical and adventurous
- **Pumpkin** (`pumpkinpfp.png`) - Warm and welcoming
- **Cactus** (`cactusindessertpfp.png`) - Strong and independent

## Technical Implementation

### Database Schema Updates
- Added `hasSelectedAvatar` field to user documents
- Added `isLocalAsset` field to track local vs network images
- Maintains both `avatarUrl` and `profilePicture` fields for compatibility

### File Structure
```
lib/
├── pages/
│   ├── avatar_selection_page.dart    # New avatar selection page
│   ├── profile_page.dart             # Updated with avatar dropdown
│   ├── login_page.dart               # Updated to check avatar selection
│   └── signup_page.dart              # Updated to redirect to avatar selection
├── services/
│   └── profile_service.dart          # Updated to handle local assets
└── main.dart                         # Added avatar selection route
```

### Key Methods

#### Avatar Selection Page
- `_saveAvatar()` - Saves selected avatar to Firestore
- `_skipAvatarSelection()` - Allows users to skip avatar selection

#### Profile Page
- `_showDefaultAvatarSelection()` - Shows dialog with default avatars
- `_selectDefaultAvatar()` - Handles default avatar selection
- `_pickImage()` - Handles file upload with format validation

#### Profile Service
- `updateAvatarOnly()` - Updated to handle local asset paths
- `fetchCurrentUserProfile()` - Updated to handle `isLocalAsset` field

## User Flow

### New Users
1. User signs up (email/password or Google)
2. Redirected to avatar selection page
3. Can choose default avatar or skip
4. Redirected to home page

### Existing Users
1. User goes to profile page
2. Clicks "Change avatar" dropdown
3. Chooses "From Files" or "Choose Default Avatar"
4. If "From Files": File picker opens with format validation
5. If "Choose Default Avatar": Dialog shows available avatars
6. Avatar is updated and saved to Firestore

## Error Handling

### File Format Validation
- Only `.png`, `.jpg`, and `.jpeg` files are accepted
- Unsupported files show "Unsupported type!" error message
- File picker closes automatically on invalid selection

### Network Issues
- Graceful fallback to default avatar on network image load failure
- Error messages for upload failures
- Loading states during avatar updates

## Styling

### Avatar Selection Page
- Grid layout with 2 columns
- Card-based design with hover effects
- Selection indicators with checkmarks
- Consistent with app's green theme

### Profile Page Dropdown
- Material Design dropdown menu
- Icons for each option (folder for files, palette for defaults)
- Consistent button styling with app theme

## Future Enhancements

1. **Avatar Cropping**: Add image cropping functionality
2. **Avatar Categories**: Organize default avatars by themes
3. **Avatar History**: Keep track of previously used avatars
4. **Avatar Sharing**: Allow users to share custom avatars
5. **Avatar Animations**: Add subtle animations to avatar selection

## Testing

To test the feature:

1. **New User Flow**:
   - Create a new account
   - Verify redirect to avatar selection page
   - Test avatar selection and skip functionality

2. **Existing User Flow**:
   - Login with existing account
   - Go to profile page
   - Test dropdown functionality
   - Test file upload with valid/invalid formats
   - Test default avatar selection

3. **Error Handling**:
   - Try uploading unsupported file formats
   - Test network connectivity issues
   - Verify error messages display correctly

## Dependencies

The feature uses the following Flutter packages:
- `image_picker` - For file selection
- `firebase_storage` - For image upload
- `cloud_firestore` - For data storage
- `google_fonts` - For typography
- `http` - For API calls

## Assets

The default avatars are located in:
```
assets/images/
├── dandelionpfp.png
├── orchidpfp.png
├── coconutonbeachpfp.png
├── pumpkinpfp.png
└── cactusindessertpfp.png
```

All assets are registered in `pubspec.yaml` under the `assets/images/` path. 
# Comment Feature

## 🌟 Overview

The Comment feature allows users to interact with plant posts by leaving comments, creating a more engaging community experience. Users can view existing comments and add new ones to any post.

## 🚀 Features

### 1. **View Comments**
- **Comment Count Display**: Shows total number of comments on each post
- **Comment List**: Displays all comments with user avatars and timestamps
- **Real-time Updates**: Comments are loaded from Firestore in real-time

### 2. **Add Comments**
- **Comment Input Field**: Text input for writing new comments
- **Send Button**: Submit comments with a tap or Enter key
- **Character Validation**: Prevents empty comments from being submitted

### 3. **User Experience**
- **XP Rewards**: Users earn +3 XP for each comment posted
- **User Profiles**: Comments show user names and avatars
- **Time Stamps**: Relative time display (e.g., "2h ago", "1d ago")

## 📱 User Interface

### Comment Button
- **Location**: Below each post's like button
- **Icon**: Chat bubble icon with comment count
- **Action**: Taps to open comments dialog

### Comments Dialog
- **Header**: Shows post title and comment count
- **Comment List**: Scrollable list of existing comments
- **Input Section**: Text field and send button at bottom
- **Close Button**: X button to dismiss dialog

### Comment Items
- **User Avatar**: Circular profile picture
- **User Name**: Display name or email
- **Comment Text**: The actual comment content
- **Timestamp**: When the comment was posted

## 🗄️ Data Structure

### Comment Model
```dart
class Comment {
  final String id;           // Unique comment ID
  final String postId;       // Associated post ID
  final String userId;       // Commenter's user ID
  final String userName;     // Commenter's display name
  final String? userAvatar;  // Commenter's profile picture
  final String content;      // Comment text content
  final DateTime timestamp;  // When comment was posted
}
```

### Firestore Structure
```
plant_posts/{postId}/comments/{commentId}
├── userId: string
├── userName: string
├── userAvatar: string (optional)
├── content: string
└── timestamp: timestamp
```

## 🔧 Implementation Details

### Files Created/Modified
1. **`lib/models/comment.dart`** - Comment data model
2. **`lib/pages/social_feed_page.dart`** - Comment functionality integration
3. **`PlantPost` class** - Added `copyWith` method for updates

### Key Methods
- **`_showComments()`** - Opens comments dialog
- **`_loadComments()`** - Fetches comments from Firestore
- **`_addComment()`** - Posts new comment and updates post
- **`_buildCommentItem()`** - Renders individual comment widgets

## 🎯 Usage Instructions

### For Users
1. **View Comments**: Tap the comment button (💬) on any post
2. **Read Comments**: Scroll through existing comments
3. **Add Comment**: Type in the input field and tap send
4. **Earn XP**: Get +3 XP for each comment posted

### For Developers
1. **Load Comments**: Use `_loadComments(postId)` method
2. **Add Comment**: Use `_addComment(postId, content)` method
3. **Update UI**: Comments automatically refresh after posting
4. **XP Integration**: Comments automatically award XP points

## 🌈 Comment Flow

### 1. **Opening Comments**
```
User taps comment button → _showComments() called → Dialog opens
```

### 2. **Loading Comments**
```
Dialog opens → _loadComments() called → Firestore query → UI updates
```

### 3. **Adding Comment**
```
User types comment → Taps send → _addComment() called → 
Firestore update → Post count increment → XP awarded → UI refresh
```

## 📊 XP Integration

### Comment Rewards
- **Comment Posted**: +3 XP
- **Automatic Update**: XP added immediately after posting
- **User Feedback**: Success message shows XP earned

### XP History
- **Automatic Recording**: Comments are logged in XP history
- **Activity Type**: Marked as "Comment" activity
- **Description**: Shows comment content preview

## 🔮 Future Enhancements

### Planned Features
1. **Comment Editing**: Allow users to edit their comments
2. **Comment Replies**: Nested comment threading
3. **Comment Moderation**: Report inappropriate comments
4. **Comment Notifications**: Alert users to new comments
5. **Comment Search**: Find specific comments across posts

### Integration Opportunities
1. **Push Notifications**: Alert post owners to new comments
2. **Email Notifications**: Daily comment summaries
3. **Comment Analytics**: Track engagement metrics
4. **Spam Protection**: Filter automated comments

## 🐛 Troubleshooting

### Common Issues
1. **Comments Not Loading**: Check Firebase connection
2. **Comment Not Posting**: Verify user authentication
3. **XP Not Awarded**: Check XP system integration
4. **UI Not Updating**: Verify setState calls

### Debug Information
- Check console for Firestore errors
- Verify user authentication status
- Ensure Firestore rules allow comment access
- Check comment collection structure

## 📝 Notes

- Comments are stored in subcollections under each post
- Comment count is automatically updated on post documents
- XP is awarded immediately after successful comment posting
- Comments are sorted by timestamp (oldest first)
- Empty comments are prevented from being posted

## 🎉 Success Indicators

### User Experience
- ✅ Comments load quickly and smoothly
- ✅ New comments appear immediately
- ✅ XP rewards are clearly communicated
- ✅ Comment count updates in real-time

### Technical Performance
- ✅ Firestore queries are optimized
- ✅ UI updates are responsive
- ✅ Error handling is graceful
- ✅ Data consistency is maintained

---

**Last Updated**: December 2024  
**Version**: 1.0.0  
**Maintainer**: Development Team

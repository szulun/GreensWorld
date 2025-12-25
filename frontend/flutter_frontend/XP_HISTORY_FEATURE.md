# XP History Feature

## 🌟 Overview

The XP History feature provides users with a comprehensive view of their experience points (XP) earning history, including detailed tracking of activities, timestamps, and progress over time.

## 🚀 Features

### 1. **XP History Display**
- **Recent Activities**: Shows the last 5 XP-earning activities
- **Today's Progress**: Displays total XP earned today
- **Activity Details**: Each entry shows action type, description, XP earned, and time ago

### 2. **Detailed XP History Dialog**
- **Complete History**: View up to 100 XP history entries
- **Time-based Summaries**: Today, This Week, This Month XP totals
- **Chronological List**: All activities sorted by timestamp (newest first)

### 3. **Sample Data Generation**
- **Test Data**: Add sample XP history for testing purposes
- **Multiple Activity Types**: Posts, likes, comments, milestones, etc.
- **Realistic Timestamps**: Activities spread across different time periods

## 📱 User Interface

### Profile Page Integration
- **XP History Section**: Located below the XP & Level section
- **Quick Actions**: "View All" and "Add Sample Data" buttons
- **Visual Indicators**: Icons, colors, and progress indicators

### XP History Items
- **Action Icons**: Emoji-based visual representation (📝, ❤️, 💬, 🔥, 🏆, 🌱)
- **Color Coding**: Different colors for different activity types
- **Time Display**: Relative time format (e.g., "2h ago", "1d ago")

## 🗄️ Data Structure

### XPHistoryItem Model
```dart
class XPHistoryItem {
  final String id;           // Unique identifier
  final String action;       // Activity type (Post, Like, Comment, etc.)
  final int xpEarned;        // XP points earned
  final String description;  // Human-readable description
  final DateTime timestamp;  // When the activity occurred
  final String? relatedId;   // Related content ID
  final String? relatedType; // Content type
}
```

### Firestore Structure
```
users/{userId}/xp_history/{timestamp}
├── id: string
├── action: string
├── xpEarned: number
├── description: string
├── timestamp: timestamp
├── relatedId: string (optional)
└── relatedType: string (optional)
```

## 🔧 Implementation Details

### Files Created/Modified
1. **`lib/models/xp_history.dart`** - XP History data model and service
2. **`lib/services/xp_example_data.dart`** - Sample data generation service
3. **`lib/pages/profile_page.dart`** - Profile page integration
4. **`lib/widgets/theme.dart`** - Additional color definitions

### Key Methods
- **`_buildXPHistory()`** - Main XP History section builder
- **`_buildXPHistoryItem()`** - Individual history item builder
- **`_showFullXPHistory()`** - Detailed history dialog
- **`_addSampleXPData()`** - Sample data generation

## 🎯 Usage Instructions

### For Users
1. **View XP History**: Navigate to Profile page → XP History section
2. **See Recent Activities**: View last 5 XP-earning activities
3. **View Complete History**: Click "View All" for detailed history
4. **Add Sample Data**: Click "Add Sample Data" for testing (optional)

### For Developers
1. **Add XP History**: Use `XPHistoryService.addXPHistory()`
2. **Retrieve History**: Use `XPHistoryService.getUserXPHistory()`
3. **Time-based Queries**: Use date range methods for analytics
4. **Sample Data**: Use `XPExampleDataService` for testing

## 🌈 Activity Types & XP Values

| Activity | XP Earned | Icon | Description |
|----------|-----------|------|-------------|
| Post | +10 | 📝 | Sharing plant photos or tips |
| Like | +1 | ❤️ | Liking community content |
| Comment | +3 | 💬 | Leaving helpful comments |
| Login Streak | +5 | 🔥 | Daily login bonuses |
| Milestone | +15 | 🏆 | Achievement unlocks |
| Plant Collection | +15 | 🌱 | Adding plants to collection |

## 📊 Analytics Features

### Time-based Summaries
- **Today's XP**: Total XP earned today
- **This Week's XP**: Total XP earned this week
- **This Month's XP**: Total XP earned this month

### Progress Tracking
- **Visual Progress**: Progress bars and percentage indicators
- **Level Progression**: XP needed for next level
- **Activity Patterns**: Most effective XP-earning activities

## 🔮 Future Enhancements

### Planned Features
1. **XP Analytics Dashboard**: Charts and graphs
2. **Achievement System**: Badges and rewards
3. **Social Features**: XP leaderboards
4. **Custom Goals**: User-defined XP targets
5. **Export Functionality**: Download XP history

### Integration Opportunities
1. **Notification System**: XP milestone alerts
2. **Gamification**: Streaks and challenges
3. **Social Sharing**: Share achievements
4. **API Endpoints**: External XP tracking

## 🐛 Troubleshooting

### Common Issues
1. **No XP History**: Use "Add Sample Data" button
2. **Loading Errors**: Check Firebase connection
3. **Display Issues**: Verify theme colors are defined

### Debug Information
- Check console for Firebase errors
- Verify user authentication status
- Ensure Firestore rules allow access

## 📝 Notes

- All XP history is stored in Firestore
- Sample data can be cleared using `XPExampleDataService.clearSampleXPHistory()`
- XP calculations are real-time and cached for performance
- History items are automatically sorted by timestamp

---

**Last Updated**: December 2024  
**Version**: 1.0.0  
**Maintainer**: Development Team

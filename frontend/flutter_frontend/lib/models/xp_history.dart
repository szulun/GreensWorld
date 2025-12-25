import 'package:cloud_firestore/cloud_firestore.dart';

class XPHistoryItem {
  final String id;
  final String action;        // "Post", "Like", "Comment", "Login Streak"
  final int xpEarned;         // +10, +1, +3, +50
  final String description;   // "Shared a plant photo", "Liked a post"
  final DateTime timestamp;   // When it happened
  final String? relatedId;    // Post ID, comment ID, etc.
  final String? relatedType;  // "post", "comment", "like", "milestone"

  XPHistoryItem({
    required this.id,
    required this.action,
    required this.xpEarned,
    required this.description,
    required this.timestamp,
    this.relatedId,
    this.relatedType,
  });

  factory XPHistoryItem.fromJson(Map<String, dynamic> json) {
    return XPHistoryItem(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      xpEarned: json['xpEarned'] ?? 0,
      description: json['description']?.toString() ?? '',
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      relatedId: json['relatedId']?.toString(),
      relatedType: json['relatedType']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'xpEarned': xpEarned,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'relatedId': relatedId,
      'relatedType': relatedType,
    };
  }

  // Get formatted time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Get action icon
  String get actionIcon {
    switch (action.toLowerCase()) {
      case 'post':
        return '📝';
      case 'like':
        return '❤️';
      case 'comment':
        return '💬';
      case 'login streak':
        return '🔥';
      case 'milestone':
        return '🏆';
      case 'plant collection':
        return '🌱';
      default:
        return '✨';
    }
  }

  // Get action color (for UI)
  String get actionColor {
    switch (action.toLowerCase()) {
      case 'post':
        return 'primary';      // Green
      case 'like':
        return 'error';        // Red
      case 'comment':
        return 'info';         // Blue
      case 'login streak':
        return 'warning';      // Orange
      case 'milestone':
        return 'secondary';    // Purple
      case 'plant collection':
        return 'success';      // Light green
      default:
        return 'primary';
    }
  }
}

// XP History Service
class XPHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add XP history item
  static Future<void> addXPHistory(String userId, XPHistoryItem item) async {
    try {
      print('Adding XP history for user: $userId');
      print('XP history item: ${item.toJson()}');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('xp_history')
          .doc(item.id)
          .set(item.toJson());
      
      print('XP history saved to Firestore successfully');
    } catch (e) {
      print('Error adding XP history: $e');
      print('Error stack trace: ${StackTrace.current}');
    }
  }

  // Get user's XP history
  static Future<List<XPHistoryItem>> getUserXPHistory(String userId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('xp_history')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => XPHistoryItem.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting XP history: $e');
      return [];
    }
  }

  // Get XP history by date range
  static Future<List<XPHistoryItem>> getXPHistoryByDateRange(
    String userId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('xp_history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => XPHistoryItem.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting XP history by date range: $e');
      return [];
    }
  }

  // Get total XP earned today
  static Future<int> getTodayXP(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final history = await getXPHistoryByDateRange(userId, startOfDay, endOfDay);
      return history.fold<int>(0, (total, item) => total + item.xpEarned);
    } catch (e) {
      print('Error getting today XP: $e');
      return 0;
    }
  }

  // Get total XP earned this week
  static Future<int> getThisWeekXP(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final history = await getXPHistoryByDateRange(userId, startOfWeekDay, now);
      return history.fold<int>(0, (total, item) => total + item.xpEarned);
    } catch (e) {
      print('Error getting this week XP: $e');
      return 0;
    }
  }

  // Get total XP earned this month
  static Future<int> getThisMonthXP(String userId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final history = await getXPHistoryByDateRange(userId, startOfMonth, now);
      return history.fold<int>(0, (total, item) => total + item.xpEarned);
    } catch (e) {
      print('Error getting this month XP: $e');
      return 0;
    }
  }
}

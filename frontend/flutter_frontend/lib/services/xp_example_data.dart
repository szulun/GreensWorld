import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/xp_history.dart';

class XPExampleDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add sample XP history data for testing
  static Future<void> addSampleXPHistory(String userId) async {
    try {
      final now = DateTime.now();
      final sampleData = [
        XPHistoryItem(
          id: 'sample_1',
          action: 'Post',
          xpEarned: 10,
          description: 'Shared a beautiful plant photo',
          timestamp: now.subtract(const Duration(minutes: 30)),
          relatedId: 'post_123',
          relatedType: 'post',
        ),
        XPHistoryItem(
          id: 'sample_2',
          action: 'Like',
          xpEarned: 1,
          description: 'Liked a community post',
          timestamp: now.subtract(const Duration(hours: 2)),
          relatedId: 'post_456',
          relatedType: 'like',
        ),
        XPHistoryItem(
          id: 'sample_3',
          action: 'Comment',
          xpEarned: 3,
          description: 'Left a helpful comment',
          timestamp: now.subtract(const Duration(hours: 4)),
          relatedId: 'comment_789',
          relatedType: 'comment',
        ),
        XPHistoryItem(
          id: 'sample_4',
          action: 'Login Streak',
          xpEarned: 5,
          description: '7-day login streak bonus',
          timestamp: now.subtract(const Duration(days: 1)),
          relatedId: null,
          relatedType: 'milestone',
        ),
        XPHistoryItem(
          id: 'sample_5',
          action: 'Plant Collection',
          xpEarned: 15,
          description: 'Added 5th plant to collection',
          timestamp: now.subtract(const Duration(days: 2)),
          relatedId: 'plant_101',
          relatedType: 'milestone',
        ),
        XPHistoryItem(
          id: 'sample_6',
          action: 'Post',
          xpEarned: 10,
          description: 'Shared plant care tips',
          timestamp: now.subtract(const Duration(days: 3)),
          relatedId: 'post_202',
          relatedType: 'post',
        ),
        XPHistoryItem(
          id: 'sample_7',
          action: 'Like',
          xpEarned: 1,
          description: 'Liked a helpful guide',
          timestamp: now.subtract(const Duration(days: 4)),
          relatedId: 'post_303',
          relatedType: 'like',
        ),
        XPHistoryItem(
          id: 'sample_8',
          action: 'Comment',
          xpEarned: 3,
          description: 'Answered a plant question',
          timestamp: now.subtract(const Duration(days: 5)),
          relatedId: 'comment_404',
          relatedType: 'comment',
        ),
      ];

      // Add each sample item to Firestore
      for (final item in sampleData) {
        await XPHistoryService.addXPHistory(userId, item);
      }

      print('Sample XP history data added successfully for user: $userId');
    } catch (e) {
      print('Error adding sample XP history: $e');
    }
  }

  // Clear sample XP history data
  static Future<void> clearSampleXPHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('xp_history')
          .where('id', isGreaterThanOrEqualTo: 'sample_')
          .where('id', isLessThan: 'sample_\uf8ff')
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('Sample XP history data cleared successfully for user: $userId');
    } catch (e) {
      print('Error clearing sample XP history: $e');
    }
  }

  // Check if user has XP history data
  static Future<bool> hasXPHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('xp_history')
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking XP history: $e');
      return false;
    }
  }
}

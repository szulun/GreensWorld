import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ai_interaction.dart';

class AIInteractionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 獲取當前用戶 ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // 保存 AI 互動記錄
  static Future<String> saveAIInteraction({
    required InteractionType type,
    String? plantName,
    String? scientificName,
    String? userQuestion,
    List<String>? imageUrls,
    required Map<String, dynamic> aiResponse,
    bool isPublic = false,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final interaction = AIInteraction(
      id: '', // Firestore 會自動生成
      userId: userId,
      type: type,
      plantName: plantName,
      scientificName: scientificName,
      userQuestion: userQuestion,
      imageUrls: imageUrls,
      aiResponse: aiResponse,
      timestamp: DateTime.now(),
      isPublic: isPublic,
    );

    final docRef = await _firestore
        .collection('ai_interactions')
        .add(interaction.toFirestore());

    return docRef.id;
  }

  // 獲取用戶的 AI 互動歷史
  static Stream<List<AIInteraction>> getUserInteractions({
    InteractionType? type,
    int limit = 50,
  }) {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    Query query = _firestore
        .collection('ai_interactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (type != null) {
      query = query.where('type', isEqualTo: type.toString().split('.').last);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AIInteraction.fromFirestore(doc))
          .toList();
    });
  }

  // 獲取公開的 AI 互動（用於社交功能）
  static Stream<List<AIInteraction>> getPublicInteractions({
    InteractionType? type,
    int limit = 20,
  }) {
    Query query = _firestore
        .collection('ai_interactions')
        .where('isPublic', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (type != null) {
      query = query.where('type', isEqualTo: type.toString().split('.').last);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AIInteraction.fromFirestore(doc))
          .toList();
    });
  }

  // 更新互動記錄的公開狀態
  static Future<void> updateInteractionVisibility(
    String interactionId,
    bool isPublic,
  ) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('ai_interactions')
        .doc(interactionId)
        .update({'isPublic': isPublic});
  }

  // 刪除互動記錄
  static Future<void> deleteInteraction(String interactionId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // 確保只能刪除自己的記錄
    final doc = await _firestore
        .collection('ai_interactions')
        .doc(interactionId)
        .get();

    if (doc.exists && doc.data()?['userId'] == userId) {
      await doc.reference.delete();
    } else {
      throw Exception('Unauthorized or interaction not found');
    }
  }

  // 獲取用戶的植物互動統計
  static Future<Map<String, int>> getUserPlantStats() async {
    final userId = currentUserId;
    if (userId == null) {
      return {};
    }

    final snapshot = await _firestore
        .collection('ai_interactions')
        .where('userId', isEqualTo: userId)
        .where('plantName', isNull: false)
        .get();

    final Map<String, int> plantCounts = {};
    
    for (final doc in snapshot.docs) {
      final plantName = doc.data()['plantName'] as String?;
      if (plantName != null) {
        plantCounts[plantName] = (plantCounts[plantName] ?? 0) + 1;
      }
    }

    return plantCounts;
  }
}

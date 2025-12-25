import 'package:cloud_firestore/cloud_firestore.dart';

// AI 互動類型枚舉
enum InteractionType {
  diagnosis,      // 植物診斷
  identification, // 植物識別
  careTips,      // 護理建議
  generalChat,   // 一般聊天
}

// AI 互動記錄模型
class AIInteraction {
  final String id;
  final String userId;
  final InteractionType type;
  final String? plantName;
  final String? scientificName;
  final String? userQuestion;
  final List<String>? imageUrls;
  final Map<String, dynamic> aiResponse;
  final DateTime timestamp;
  final bool isPublic; // 是否公開分享

  AIInteraction({
    required this.id,
    required this.userId,
    required this.type,
    this.plantName,
    this.scientificName,
    this.userQuestion,
    this.imageUrls,
    required this.aiResponse,
    required this.timestamp,
    this.isPublic = false,
  });

  // 從 Firestore 文檔創建對象
  factory AIInteraction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIInteraction(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: InteractionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => InteractionType.generalChat,
      ),
      plantName: data['plantName'],
      scientificName: data['scientificName'],
      userQuestion: data['userQuestion'],
      imageUrls: data['imageUrls'] != null 
          ? List<String>.from(data['imageUrls']) 
          : null,
      aiResponse: data['aiResponse'] ?? {},
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isPublic: data['isPublic'] ?? false,
    );
  }

  // 轉換為 Firestore 文檔
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'plantName': plantName,
      'scientificName': scientificName,
      'userQuestion': userQuestion,
      'imageUrls': imageUrls,
      'aiResponse': aiResponse,
      'timestamp': Timestamp.fromDate(timestamp),
      'isPublic': isPublic,
    };
  }

  // 創建副本並更新某些字段
  AIInteraction copyWith({
    String? id,
    String? userId,
    InteractionType? type,
    String? plantName,
    String? scientificName,
    String? userQuestion,
    List<String>? imageUrls,
    Map<String, dynamic>? aiResponse,
    DateTime? timestamp,
    bool? isPublic,
  }) {
    return AIInteraction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      plantName: plantName ?? this.plantName,
      scientificName: scientificName ?? this.scientificName,
      userQuestion: userQuestion ?? this.userQuestion,
      imageUrls: imageUrls ?? this.imageUrls,
      aiResponse: aiResponse ?? this.aiResponse,
      timestamp: timestamp ?? this.timestamp,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

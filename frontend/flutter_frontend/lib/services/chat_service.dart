import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatLimitExceeded implements Exception {
  final int limit;
  ChatLimitExceeded(this.limit);
  @override
  String toString() => 'Chat limit exceeded ($limit)';
}

class ChatSession {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSession(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String? ?? 'Session',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatMessage {
  final String id;
  final String sessionId;
  final String role; // 'user' | 'assistant'
  final String content;
  final List<String> images; // URLs
  final String mode; // 'doctor' | 'id' | 'general'
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.images,
    required this.mode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'role': role,
        'content': content,
        'images': images,
        'mode': mode,
        'createdAt': createdAt,
      };

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      sessionId: data['sessionId'] as String,
      role: data['role'] as String? ?? 'user',
      content: data['content'] as String? ?? '',
      images: (data['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      mode: data['mode'] as String? ?? 'general',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FirebaseStorage.instance;

  // Sessions stream
  static Stream<List<ChatSession>> sessionsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    
    return _db
        .collection('ai_sessions')
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .handleError((error) {
          print('❌ ChatService: sessionsStream error: $error');
          return <ChatSession>[];
        })
        .map((s) {
          try {
            final sessions = s.docs.map(ChatSession.fromDoc).toList();
            return sessions;
          } catch (e) {
            print('❌ ChatService: Error parsing sessions: $e');
            return <ChatSession>[];
          }
        });
  }

  // Ensure user doc exists
  static Future<DocumentReference<Map<String, dynamic>>> _userRef() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Not authenticated');
    }
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({'chatCount': 0, 'createdAt': FieldValue.serverTimestamp()});
    }
    return ref;
  }

  // Create session with quota check (default limit=100)
  static Future<String> ensureSession({String? title, int maxChats = 100}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Not authenticated');
    }
    
    try {
      final userRef = await _userRef();
      final sessRef = _db.collection('ai_sessions').doc();

      await _db.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final count = (userSnap.data()?['chatCount'] ?? 0) as int;
        if (count >= maxChats) {
          throw ChatLimitExceeded(maxChats);
        }
        final now = DateTime.now();
        tx.set(sessRef, {
          'userId': uid,
          'title': title ?? 'New chat',
          'createdAt': now,
          'updatedAt': now,
        });
        tx.update(userRef, {
          'chatCount': count + 1,
          'lastChatAt': FieldValue.serverTimestamp(),
        });
      });

      return sessRef.id;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> renameSession(String sessionId, String title) async {
    print('🔍 ChatService: renameSession - ID: $sessionId, Title: $title');
    try {
      await _db.collection('ai_sessions').doc(sessionId).update({
        'title': title,
        'updatedAt': DateTime.now(),
      });
      print('✅ ChatService: Session renamed successfully');
    } catch (e) {
      print('❌ ChatService: Error renaming session: $e');
      rethrow;
    }
  }

  // Delete session and decrement user's chatCount
  static Future<void> deleteSession(String sessionId) async {
    print('🔍 ChatService: deleteSession - ID: $sessionId');
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    final userRef = _db.collection('users').doc(uid);
    final sessRef = _db.collection('ai_sessions').doc(sessionId);

    try {
      // Delete messages in batch
      final batch = _db.batch();
      final msgs = await sessRef.collection('messages').get();
      print('🗑️ ChatService: Deleting ${msgs.docs.length} messages');
      for (final m in msgs.docs) {
        batch.delete(m.reference);
      }
      batch.delete(sessRef);
      await batch.commit();

      // Decrement counter in transaction (tolerate missing doc)
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final count = (snap.data()?['chatCount'] ?? 0) as int;
        tx.set(userRef, {'chatCount': (count > 0 ? count - 1 : 0)}, SetOptions(merge: true));
      });
      print('✅ ChatService: Session deleted successfully');
    } catch (e) {
      print('❌ ChatService: Error deleting session: $e');
      rethrow;
    }
  }

  // Messages
  static Stream<List<ChatMessage>> messagesStream(String sessionId) {
    return _db
        .collection('ai_sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .handleError((error) {
          print('❌ ChatService: messagesStream error: $error');
          return <ChatMessage>[];
        })
        .map((s) {
          try {
            final messages = s.docs.map(ChatMessage.fromDoc).toList();
            return messages;
          } catch (e) {
            print('❌ ChatService: Error parsing messages: $e');
            return <ChatMessage>[];
          }
        });
  }

  // Load messages from a specific session
  static Future<List<ChatMessage>> loadMessages(String sessionId) async {
    try {
      final snapshot = await _db
          .collection('ai_sessions')
          .doc(sessionId)
          .collection('messages')
          .orderBy('createdAt')
          .get();
      
      return snapshot.docs.map(ChatMessage.fromDoc).toList();
    } catch (e) {
      print('❌ ChatService: Error loading messages: $e');
      return [];
    }
  }

  static Future<void> addMessage({
    required String sessionId,
    required String role,
    required String content,
    List<String> images = const [],
    String mode = 'general',
  }) async {
    try {
      final now = DateTime.now();
      final ref = _db.collection('ai_sessions').doc(sessionId);
      
      // Add message
      final messageRef = await ref.collection('messages').add({
        'sessionId': sessionId,
        'role': role,
        'content': content,
        'images': images,
        'mode': mode,
        'createdAt': now,
      });
      
      // Update session timestamp and potentially title
      final Map<String, dynamic> updateData = {'updatedAt': now};
      
      // If this is a user message and contains meaningful content, update the title
      if (role == 'user' && content.isNotEmpty && content != '[image]') {
        final shortContent = content.length > 30 ? '${content.substring(0, 30)}...' : content;
        updateData['title'] = shortContent;
      }
      
      await ref.update(updateData);
      
    } catch (e) {
      print('❌ ChatService: Error adding message: $e');
      rethrow;
    }
  }

  // Storage
  static Future<String> uploadImage(Uint8List bytes, {required String fileName}) async {
    print('🔍 ChatService: uploadImage - File: $fileName, Size: ${bytes.length} bytes');
    try {
      final uid = _auth.currentUser?.uid ?? 'anonymous';
      final path = 'ai_uploads/$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      print('📁 ChatService: Upload path: $path');
      
      final task = await _storage.ref(path).putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await task.ref.getDownloadURL();
      print('✅ ChatService: Image uploaded successfully: $url');
      return url;
    } catch (e) {
      print('❌ ChatService: Error uploading image: $e');
      rethrow;
    }
  }

  // Sync local messages into a new Firestore session (returns new sessionId)
  static Future<String> syncLocalMessages({required String title, required List<ChatMessage> localMessages, int maxChats = 100}) async {
    print('🔍 ChatService: syncLocalMessages - Title: $title, Messages: ${localMessages.length}');
    if (localMessages.isEmpty) throw Exception('No local messages');
    
    try {
      final sessionId = await ensureSession(title: title, maxChats: maxChats);
      final sessRef = _db.collection('ai_sessions').doc(sessionId);
      final batch = _db.batch();
      
      for (final m in localMessages) {
        final msgRef = sessRef.collection('messages').doc();
        batch.set(msgRef, m.toMap());
      }
      
      batch.update(sessRef, {'updatedAt': DateTime.now()});
      await batch.commit();
      print('✅ ChatService: Local messages synced successfully');
      return sessionId;
    } catch (e) {
      print('❌ ChatService: Error syncing local messages: $e');
      rethrow;
    }
  }

  // Test method to check Firebase connection
  static Future<void> testFirestoreConnection() async {
    print('🧪 ChatService: Testing Firestore connection...');
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        print('❌ ChatService: User not authenticated');
        return;
      }
      
      print('✅ ChatService: User authenticated, UID: $uid');
      
      // Test read permission
      final userDoc = await _db.collection('users').doc(uid).get();
      print('✅ ChatService: Read user document: ${userDoc.exists}');
      
      // Test sessions query
      print('🔍 ChatService: Testing sessions query...');
      final sessionsQuery = await _db
          .collection('ai_sessions')
          .where('userId', isEqualTo: uid)
          .get();
      print('🔍 ChatService: Found ${sessionsQuery.docs.length} sessions for user $uid');
      
      for (final doc in sessionsQuery.docs) {
        final data = doc.data();
        print('🔍 ChatService: Session ${doc.id}: ${data['title']} (${data['userId']})');
      }
      
      // Test write permission
      final testRef = _db.collection('ai_sessions').doc('test_${DateTime.now().millisecondsSinceEpoch}');
      await testRef.set({
        'userId': uid,
        'title': 'Test Session',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
      print('✅ ChatService: Write test successful');
      
      // Clean up test data
      await testRef.delete();
      print('✅ ChatService: Delete test successful');
      
      print('🎉 ChatService: All tests passed!');
      
    } catch (e) {
      print('❌ ChatService: Firestore test failed: $e');
      print('❌ ChatService: Error type: ${e.runtimeType}');
      print('❌ ChatService: Error details: ${e.toString()}');
    }
  }
} 
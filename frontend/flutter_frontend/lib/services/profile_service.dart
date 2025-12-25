import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env_config.dart';

class UserProfile {
  final String id;
  final String name;
  final String location;
  final String bio;
  final String? avatarUrl;
  final bool isLocalAsset;
  final double rating;
  final int successfulSwaps;
  final int communityHelps;
  final int activePlants;
  final int experience; // XP points for level system
  final List<PlantSummary> plants;
  final List<ActivityItem> recentActivities;
  final List<String> badges;
  final List<FavoriteShop> favoriteShops; // 新增：收藏的商店

  UserProfile({
    required this.id,
    required this.name,
    required this.location,
    required this.bio,
    this.avatarUrl,
    this.isLocalAsset = false,
    required this.rating,
    required this.successfulSwaps,
    required this.communityHelps,
    required this.activePlants,
    required this.experience,
    required this.plants,
    required this.recentActivities,
    required this.badges,
    required this.favoriteShops, // 新增
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>?;
    
    // 處理頭像URL，確保空字符串被轉換為null
    String? avatarUrl;
    final profilePicture = json['profilePicture']?.toString();
    final avatarUrlField = json['avatarUrl']?.toString();
    
    if (profilePicture != null && profilePicture.isNotEmpty) {
      avatarUrl = profilePicture;
    } else if (avatarUrlField != null && avatarUrlField.isNotEmpty) {
      avatarUrl = avatarUrlField;
    } else {
      avatarUrl = null;
    }
    
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['username']?.toString() ?? json['name']?.toString() ?? 'Plant Lover',
      location: json['location']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      avatarUrl: avatarUrl,
      isLocalAsset: json['isLocalAsset'] as bool? ?? avatarUrl?.startsWith('assets/') ?? false,
      rating: (stats?['rating'] ?? 0).toDouble(),
      successfulSwaps: (stats?['successfulSwaps'] ?? 0) as int,
      communityHelps: (stats?['communityHelps'] ?? 0) as int,
      activePlants: (stats?['activePlants'] ?? 0) as int,
      experience: (json['experience'] ?? 0) as int,
      badges: (json['badges'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      plants: (json['plants'] as List?)?.map((e) {
        final m = e as Map<String, dynamic>;
        return PlantSummary(
          name: m['name']?.toString() ?? '',
          emoji: m['emoji']?.toString() ?? '🌱',
          status: m['status']?.toString() ?? '',
        );
      }).toList() ?? const [],
      recentActivities: const [],
      favoriteShops: const [], // 新增：從JSON中讀取收藏的商店
    );
  }
}

class PlantSummary {
  final String name;
  final String emoji;
  final String status; // Available / Swapped / etc.

  PlantSummary({required this.name, required this.emoji, required this.status});
}

class ActivityItem {
  final String iconEmoji;
  final String text;
  final String timeAgo;

  ActivityItem({required this.iconEmoji, required this.text, required this.timeAgo});
}

// 新增：收藏的商店類
class FavoriteShop {
  final String id;
  final String name;
  final String address;
  final double? rating;
  final bool? isOpen;
  final int distanceMeters;
  final String? imageUrl;
  final DateTime? favoritedAt; // 新增：收藏日期

  FavoriteShop({
    required this.id,
    required this.name,
    required this.address,
    this.rating,
    this.isOpen,
    required this.distanceMeters,
    this.imageUrl,
    this.favoritedAt, // 新增
  });

  factory FavoriteShop.fromJson(Map<String, dynamic> json) {
    return FavoriteShop(
      id: json['shopId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      rating: json['rating']?.toDouble(),
      isOpen: json['isOpen'] as bool?,
      distanceMeters: json['distanceMeters'] as int? ?? 0,
      imageUrl: json['imageUrl']?.toString(),
      favoritedAt: json['favoritedAt'] != null ? DateTime.parse(json['favoritedAt'] as String) : null,
    );
  }
}

class UserProfileUpdate {
  final String displayName;
  final String location;
  final String bio;
  final String? avatarUrl;
  final List<String> badges;

  UserProfileUpdate({
    required this.displayName,
    required this.location,
    required this.bio,
    this.avatarUrl,
    this.badges = const [],
  });

  Map<String, dynamic> toJson(String email) => {
        'email': email,
        'displayName': displayName,
        'location': location,
        'bio': bio,
        'avatarUrl': avatarUrl,
        'badges': badges,
      };
}

class ProfileService {
  static Future<UserProfile> fetchCurrentUserProfile() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 ProfileService.fetchCurrentUserProfile debug info:');
      print('  - User ID: ${user.uid}');
      print('  - User email: ${user.email}');

      // Get user data from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        
        print('📋 Firestore data:');
        print('  - Document exists: ${doc.exists}');
        print('  - Raw data: $data');
        print('  - profilePicture field: ${data['profilePicture']}');
        print('  - avatarUrl field: ${data['avatarUrl']}');
        
        // 處理頭像URL，確保空字符串被轉換為null
        String? avatarUrl;
        final profilePicture = data['profilePicture']?.toString();
        final avatarUrlField = data['avatarUrl']?.toString();
        
        print('🔍 Avatar URL processing:');
        print('  - profilePicture: $profilePicture');
        print('  - avatarUrlField: $avatarUrlField');
        
        if (profilePicture != null && profilePicture.isNotEmpty) {
          avatarUrl = profilePicture;
          print('✅ Using profilePicture: $avatarUrl');
        } else if (avatarUrlField != null && avatarUrlField.isNotEmpty) {
          avatarUrl = avatarUrlField;
          print('✅ Using avatarUrl: $avatarUrl');
        } else {
          avatarUrl = null;
          print('📝 No valid avatar URL found');
        }
        
        final profile = UserProfile(
          id: user.uid,
          name: data['username']?.toString() ?? data['firstName']?.toString() ?? 'Plant Lover',
          location: data['location']?.toString() ?? 'Unknown Location',
          bio: data['bio']?.toString() ?? 'Plant enthusiast and community member',
          avatarUrl: avatarUrl,
          isLocalAsset: data['isLocalAsset'] as bool? ?? avatarUrl?.startsWith('assets/') ?? false,
          rating: (data['rating'] ?? 0).toDouble(),
          successfulSwaps: data['successfulSwaps'] ?? 0,
          communityHelps: data['communityHelps'] ?? 0,
          activePlants: data['activePlants'] ?? 0,
          experience: data['experience'] ?? 0,
          plants: (data['plants'] as List?)?.map((e) {
            final m = e as Map<String, dynamic>;
            return PlantSummary(
              name: m['name']?.toString() ?? '',
              emoji: m['emoji']?.toString() ?? '🌱',
              status: m['status']?.toString() ?? '',
            );
          }).toList() ?? const [],
          recentActivities: const [],
          badges: (data['badges'] as List?)?.map((e) => e.toString()).toList() ?? const [],
          favoriteShops: await _loadFavoriteShops(user.uid), // New: Load favorite shops
        );
        
        print('✅ Created UserProfile:');
        print('  - Name: ${profile.name}');
        print('  - Avatar URL: ${profile.avatarUrl}');
        
        return profile;
      } else {
        print('📝 User document does not exist, creating default profile');
        // Create default profile if user document doesn't exist
        final defaultProfile = UserProfile(
          id: user.uid,
          name: 'Plant Lover',
          location: 'Unknown Location',
          bio: 'Plant enthusiast and community member',
          avatarUrl: null,
          isLocalAsset: false,
          rating: 0.0,
          successfulSwaps: 0,
          communityHelps: 0,
          activePlants: 0,
          experience: 0,
          plants: const [],
          recentActivities: const [],
          badges: const [],
          favoriteShops: const [], // 新增：創建默認收藏的商店
        );

        // Save default profile to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'username': defaultProfile.name,
          'location': defaultProfile.location,
          'bio': defaultProfile.bio,
          'rating': defaultProfile.rating,
          'successfulSwaps': defaultProfile.successfulSwaps,
          'communityHelps': defaultProfile.communityHelps,
          'activePlants': defaultProfile.activePlants,
          'badges': defaultProfile.badges,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return defaultProfile;
      }
    } catch (e) {
      print('❌ ProfileService.fetchCurrentUserProfile error: $e');
      // Return a default profile on error
      return UserProfile(
        id: 'error',
        name: 'Plant Lover',
        location: 'Unknown Location',
        bio: 'Plant enthusiast and community member',
        avatarUrl: null,
        isLocalAsset: false,
        rating: 0.0,
        successfulSwaps: 0,
        communityHelps: 0,
        activePlants: 0,
        experience: 0,
        plants: const [],
        recentActivities: const [],
        badges: const [],
        favoriteShops: const [], // 新增：創建錯誤時的默認收藏商店
      );
    }
  }

  // New: Load user's favorite shops
  static Future<List<FavoriteShop>> _loadFavoriteShops(String userId) async {
    try {
      print('🔍 Loading user\'s favorite shops: $userId');
      
      // 獲取認證頭部
      final headers = await _authHeaders();
      
      final response = await http.get(
        Uri.parse('${EnvConfig.apiUrl}/users/$userId/favorites/plant-shops'),
        headers: headers,
      );
      
      print('📡 Favorite shop API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final favorites = (data['favorites'] as List?)
            ?.map((shop) => FavoriteShop.fromJson(shop))
            .toList() ?? [];
        
        print('✅ Successfully loaded ${favorites.length} favorite shops');
        return favorites;
      } else if (response.statusCode == 404) {
        // 用戶還沒有收藏 - 這是正常的
        print('📝 User has no favorite shops yet');
        return [];
      } else {
        print('⚠️ Failed to load favorite shops, status code: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Failed to load favorite shops: $e');
      return [];
    }
  }

  // 新增：獲取認證頭部
  static Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    final idToken = await user.getIdToken(true); // 強制刷新
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  static Future<void> updateProfile(UserProfileUpdate update) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'username': update.displayName,
        'location': update.location,
        'bio': update.bio,
        'avatarUrl': update.avatarUrl,
        'profilePicture': update.avatarUrl, // 同時保存到兩個字段
        'badges': update.badges,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  static Future<void> updateAvatarOnly(String avatarUrl) async {
    try {
      print('🔍 ProfileService.updateAvatarOnly called with URL: $avatarUrl');
      
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      print('✅ User authenticated: ${user.uid}');

      // Check if this is a local asset path (default avatar)
      final isLocalAsset = avatarUrl.startsWith('assets/');
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'avatarUrl': avatarUrl,
        'profilePicture': avatarUrl, // 同時保存到兩個字段
        'isLocalAsset': isLocalAsset, // Mark if it's a local asset
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Avatar URL saved to Firestore successfully');
    } catch (e) {
      print('❌ Error in updateAvatarOnly: $e');
      throw Exception('Failed to update avatar: $e');
    }
  }
}
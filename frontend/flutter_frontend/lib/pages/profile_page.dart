import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/theme.dart'; // Import the AppColors theme
import '../widgets/navbar_home.dart';
import '../services/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/profile_service.dart';
import '../widgets/theme.dart'; // 修復：AppColors 在這裡
import '../widgets/navbar_home.dart'; // 修復：NavbarHome 在這裡
import '../config/env_config.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../models/xp_system.dart';
import '../models/xp_history.dart';
import '../services/xp_example_data.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<UserProfile> _futureProfile;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _futureProfile = ProfileService.fetchCurrentUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NavbarHome(),
      body: FutureBuilder<UserProfile>(
        future: _futureProfile,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            );
          }
          final profile = snapshot.data!;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.deepGreen.withOpacity(0.1),
                  AppColors.surfaceLight,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(profile),
                  const SizedBox(height: 16),
                  _buildStats(profile),
                  const SizedBox(height: 16),
                  _buildXPHistory(profile),
                  const SizedBox(height: 16),
                  _buildMyPlants(profile),
                  const SizedBox(height: 16),
                  _buildFavoriteShops(profile), // 新增：顯示收藏的商店
                  const SizedBox(height: 16),
                  _buildRecentActivity(profile),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserProfile p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(p),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('📍 '),
                        Text(
                          p.location,
                          style: GoogleFonts.inter(
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      p.bio,
                      style: GoogleFonts.inter(
                        color: AppColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _buildBadges(p.badges),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: OutlinedButton(
              onPressed: () => _openEditDialog(p),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Edit Profile',
                style: GoogleFonts.inter(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserProfile p) {
    return Column(
      children: [
        GestureDetector(
          onTap: _isUploadingAvatar ? null : _pickImage,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGreen,
              border: Border.all(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _buildAvatarImage(p),
            ),
          ),
        ),
        if (_isUploadingAvatar)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        PopupMenuButton<String>(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'files',
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'From Files',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'default',
              child: Row(
                children: [
                  Icon(
                    Icons.palette,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Choose Default Avatar',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'files') {
              _pickImage();
            } else if (value == 'default') {
              _showDefaultAvatarSelection();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryGreen),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: _isUploadingAvatar ? AppColors.textMedium : AppColors.primaryGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  _isUploadingAvatar ? 'Uploading...' : 'Change avatar',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _isUploadingAvatar ? AppColors.textMedium : AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: _isUploadingAvatar ? AppColors.textMedium : AppColors.primaryGreen,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _isUploadingAvatar ? null : () {
            setState(() {
              _futureProfile = ProfileService.fetchCurrentUserProfile();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Profile refreshed!'),
                backgroundColor: AppColors.successGreen,
              ),
            );
          },
          icon: Icon(
            Icons.refresh,
            size: 16,
            color: _isUploadingAvatar ? AppColors.textMedium : AppColors.accentGreen,
          ),
          label: Text(
            'Refresh',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _isUploadingAvatar ? AppColors.textMedium : AppColors.accentGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage(UserProfile p) {
    // Add debug info
    print('🔍 _buildAvatarImage debug info:');
          print('  - User name: ${p.name}');
      print('  - Avatar URL: ${p.avatarUrl}');
      print('  - URL is empty: ${p.avatarUrl?.isEmpty}');
      print('  - URL is null: ${p.avatarUrl == null}');
          print('  - Is local asset: ${p.isLocalAsset}');
    
    // If no avatar URL, show first letter
    if (p.avatarUrl == null || p.avatarUrl!.isEmpty) {
              print('📝 No avatar URL, showing default avatar');
      return _buildFallbackAvatar(p.name);
    }

          print('📸 Trying to load avatar: ${p.avatarUrl}');
    
    // Check if this is a local asset (default avatar)
    if (p.isLocalAsset || p.avatarUrl!.startsWith('assets/')) {
              print('📦 Loading local asset avatar: ${p.avatarUrl}');
      return Image.asset(
        p.avatarUrl!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Local avatar loading failed: $error');
          return _buildFallbackAvatar(p.name);
        },
      );
    }
    
    // Check if this is a base64 data URL
    if (p.avatarUrl!.startsWith('data:image/')) {
              print('🔤 Loading Base64 avatar');
      return Image.memory(
        base64Decode(p.avatarUrl!.split(',')[1]),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Base64 avatar loading failed: $error');
          return _buildFallbackAvatar(p.name);
        },
      );
    }
    
    // Network image - use Firebase Storage SDK
            print('🌐 Trying to load network avatar: ${p.avatarUrl}');
    return FutureBuilder<String>(
      future: _getFirebaseStorageUrl(p.avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 80,
            height: 80,
            color: AppColors.primaryGreen.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          print('❌ Avatar loading failed: ${snapshot.error}');
                      print('❌ Attempted URL: ${p.avatarUrl}');
          return _buildFallbackAvatar(p.name);
        }
        
        return Image.network(
          snapshot.data!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Avatar loading failed: $error');
                          print('❌ Error details: $stackTrace');
            return _buildFallbackAvatar(p.name);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('✅ Avatar loaded successfully');
              return child;
            }
            return Container(
              width: 80,
              height: 80,
              color: AppColors.primaryGreen.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        );
      },
    );
  }

  // 移除複雜的URL驗證
  // 移除平台特定處理
  // 移除重試機制

  Widget _buildFallbackAvatar(String name) {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.primaryGreen,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.surfaceLight,
          ),
        ),
      ),
    );
  }

  Future<String> _getFirebaseStorageUrl(String url) async {
    try {
      // If it's already a Firebase Storage URL, try to get a fresh download URL
      if (url.contains('firebasestorage.googleapis.com')) {
        // Extract the path from the URL
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 4) {
          // Remove the first 3 segments (v0, b, bucket, o) and join the rest
          final storagePath = pathSegments.skip(3).join('/');
          final storageRef = FirebaseStorage.instance.ref().child(storagePath);
          return await storageRef.getDownloadURL();
        }
      }
      return url; // Return original URL if not a Firebase Storage URL
    } catch (e) {
      print('❌ Error getting Firebase Storage URL: $e');
      return url; // Return original URL as fallback
    }
  }

  // 其他方法保持不變...
  List<Widget> _buildBadges(List<String> badges) {
    if (badges.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'New Member',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.accentGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ];
    }
    return badges.map((badge) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badge,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.accentGreen,
          fontWeight: FontWeight.w500,
        ),
      ),
    )).toList();
  }

  Widget _buildStats(UserProfile p) {
    return Column(
      children: [
        // XP and Level Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Experience & Level',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showXPRulesDialog(context),
                    icon: Icon(
                      Icons.help_outline,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                    tooltip: 'How to earn XP',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildXPLevelCard(p),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Original Stats
        Row(
          children: [
            Expanded(child: _buildStatCard('${p.successfulSwaps}', 'Successful\nSwaps')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('${p.rating}', 'Rating')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('${p.communityHelps}', 'Community\nHelps')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('${p.activePlants}', 'Active\nPlants')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Build XP and Level Card
  Widget _buildXPLevelCard(UserProfile p) {
    // Get user's XP (for now, using a placeholder - you'll need to add this to UserProfile)
    int userXP = p.experience ?? 0;
    String currentLevel = XPSystem.getLevel(userXP);
    int nextLevelXP = XPSystem.getNextLevelXP(userXP);
    double progress = XPSystem.getProgressPercentage(userXP);
    
    return Row(
      children: [
        // Level Icon and Name
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: XPSystem.levelColors[currentLevel]?.withOpacity(0.1) ?? AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  XPSystem.levelIcons[currentLevel] ?? Icons.local_florist,
                  color: XPSystem.levelColors[currentLevel] ?? AppColors.primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLevel,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '$userXP XP',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Progress Bar
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to next level',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceMedium,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '${nextLevelXP - userXP} XP to next level',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Show XP Rules Dialog
  void _showXPRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'How to Earn XP & Level Up',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Level System Overview
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level System',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete activities to earn XP and unlock new levels. Each level brings new achievements and recognition in the plant community!',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // XP Rules List
                      Text(
                        'XP Earning Activities',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...XPSystem.getXPRulesDetails().map((rule) => _buildXPRuleItem(rule)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build XP Rule Item
  Widget _buildXPRuleItem(Map<String, dynamic> rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceMedium),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              rule['icon'] as IconData,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rule['action'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+${rule['xp']} XP',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rule['description'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build XP History Section
  Widget _buildXPHistory(UserProfile p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP History',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _showFullXPHistory(context, p.id),
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<XPHistoryItem>>(
            future: XPHistoryService.getUserXPHistory(p.id, limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  ),
                );
              }
              
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: AppColors.textMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No XP history yet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.textMedium,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start posting and interacting to earn XP!',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textMedium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final history = snapshot.data!;
              return Column(
                children: [
                  // Today's XP Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.today,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today\'s Progress',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                'Keep up the great work!',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FutureBuilder<int>(
                          future: XPHistoryService.getTodayXP(p.id),
                          builder: (context, todaySnapshot) {
                            if (todaySnapshot.hasData) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '+${todaySnapshot.data} XP',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Recent XP Activities
                  ...history.map((item) => _buildXPHistoryItem(item)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Build XP History Item
  Widget _buildXPHistoryItem(XPHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceMedium),
      ),
      child: Row(
        children: [
          // Action Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.actionIcon,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          // Action Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.action,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  item.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          // XP and Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${item.xpEarned} XP',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.timeAgo,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Show Full XP History Dialog
  void _showFullXPHistory(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Complete XP History',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: FutureBuilder<List<XPHistoryItem>>(
                  future: XPHistoryService.getUserXPHistory(userId, limit: 100),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                        ),
                      );
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: AppColors.textMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No XP history yet',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start posting and interacting to earn XP!',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textMedium,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final history = snapshot.data!;
                    return Column(
                      children: [
                        // XP Summary Cards
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: FutureBuilder<int>(
                                  future: XPHistoryService.getTodayXP(userId),
                                  builder: (context, todaySnapshot) {
                                    return _buildXPSummaryCard(
                                      'Today',
                                      todaySnapshot.data ?? 0,
                                      Icons.today,
                                      AppColors.primaryGreen,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FutureBuilder<int>(
                                  future: XPHistoryService.getThisWeekXP(userId),
                                  builder: (context, weekSnapshot) {
                                    return _buildXPSummaryCard(
                                      'This Week',
                                      weekSnapshot.data ?? 0,
                                      Icons.calendar_view_week,
                                      AppColors.info,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FutureBuilder<int>(
                                  future: XPHistoryService.getThisMonthXP(userId),
                                  builder: (context, monthSnapshot) {
                                    return _buildXPSummaryCard(
                                      'This Month',
                                      monthSnapshot.data ?? 0,
                                      Icons.calendar_month,
                                      AppColors.warning,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        // History List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              return _buildXPHistoryItem(history[index]);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build XP Summary Card
  Widget _buildXPSummaryCard(String title, int xp, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+$xp XP',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildMyPlants(UserProfile p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Plants',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All (${p.plants.length})',
                  style: GoogleFonts.inter(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (p.plants.isEmpty)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No plants yet',
                  style: GoogleFonts.inter(
                    color: AppColors.textMedium,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Plant list coming soon',
                  style: GoogleFonts.inter(
                    color: AppColors.textMedium,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoriteShops(UserProfile p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Favorite Shops',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All (${p.favoriteShops.length})',
                  style: GoogleFonts.inter(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (p.favoriteShops.isEmpty)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No favorite shops yet',
                  style: GoogleFonts.inter(
                    color: AppColors.textMedium,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            // 顯示收藏的商店列表
            Column(
              children: p.favoriteShops.take(3).map((shop) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMedium,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // 商店圖標
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.store,
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 商店信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shop.address,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textMedium,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (shop.rating != null) ...[
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shop.rating.toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                '${shop.distanceMeters}m away',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                          // New: Address display
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  // If address is generic description, show more useful info
                                  shop.address == 'Near your location' 
                                    ? '📍 Nearby location'
                                    : shop.address,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 狀態指示器
                    if (shop.isOpen != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: shop.isOpen! ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          shop.isOpen! ? 'Open' : 'Closed',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: shop.isOpen! ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    // remove from favorites
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeFavoriteShop(shop.id),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      tooltip: 'Remove from favorites',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(UserProfile p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceMedium,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No recent activity',
                style: GoogleFonts.inter(
                  color: AppColors.textMedium,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_isUploadingAvatar) return;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );
      
      if (image != null) {
        // Check file format
        final String fileName = image.name.toLowerCase();
        if (!fileName.endsWith('.png') && !fileName.endsWith('.jpg') && !fileName.endsWith('.jpeg')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Unsupported type!',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        
        setState(() {
          _isUploadingAvatar = true;
        });
        
        final bytes = await image.readAsBytes();
        
        try {
          final String imageUrl = await _uploadAvatarToStorage(bytes);
          await ProfileService.updateAvatarOnly(imageUrl);
          
          setState(() {
            _futureProfile = ProfileService.fetchCurrentUserProfile();
            _isUploadingAvatar = false;
          });
          
          // Force rebuild of the navbar to show updated avatar
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Avatar updated successfully!'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          
        } catch (uploadError) {
          setState(() {
            _isUploadingAvatar = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload avatar: $uploadError'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  // 移除重試機制，簡化為基本上傳
  Future<String> _uploadAvatarToStorage(Uint8List imageBytes) async {
    try {
      // Convert image bytes to base64 string
      final String base64String = base64Encode(imageBytes);
      
      // Create a data URL for the image
      final String dataUrl = 'data:image/jpeg;base64,$base64String';
      
      print('✅ Avatar converted to base64 successfully');
      return dataUrl;
    } catch (e) {
      print('❌ Avatar conversion failed: $e');
      throw Exception('Failed to convert avatar: $e');
    }
  }

  void _openEditDialog(UserProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    final locationController = TextEditingController(text: profile.location);
    final bioController = TextEditingController(text: profile.bio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: AppColors.textMedium),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: 'Location',
                labelStyle: TextStyle(color: AppColors.textMedium),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: AppColors.textMedium),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ProfileService.updateProfile(
                  UserProfileUpdate(
                    displayName: nameController.text,
                    location: locationController.text,
                    bio: bioController.text,
                    avatarUrl: null, // _pendingAvatarDataUrl is removed
                  ),
                );
                
                setState(() {
                  _futureProfile = ProfileService.fetchCurrentUserProfile();
                });
                
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Profile updated successfully!'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update profile: $e'),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.surfaceLight,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // remove from favorites
  Future<void> _removeFavoriteShop(String shopId) async {
    try {
      // show confirm dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Remove from Favorites',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            content: Text(
              'Are you sure you want to remove this shop from your favorites?',
              style: GoogleFonts.inter(
                color: AppColors.textMedium,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: AppColors.textMedium),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Remove',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      // get current user
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // call API to remove from favorites
      final response = await http.delete(
        Uri.parse('${EnvConfig.apiUrl}/users/${user.uid}/favorites/plant-shops/$shopId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // remove successfully, refresh page
        setState(() {
          _futureProfile = ProfileService.fetchCurrentUserProfile();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('💔 Shop removed from favorites'),
            backgroundColor: Colors.orange.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to remove favorite: ${response.statusCode}');
      }
    } catch (e) {
      print('Error removing favorite shop: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Failed to remove favorite: $e'),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showDefaultAvatarSelection() {
    // List of available avatar images
    final List<Map<String, String>> availableAvatars = [
      {
        'name': 'Dandelion',
        'path': 'assets/images/dandelionpfp.png',
        'description': 'Free-spirited and resilient'
      },
      {
        'name': 'Orchid',
        'path': 'assets/images/orchidpfp.png',
        'description': 'Elegant and sophisticated'
      },
      {
        'name': 'Coconut',
        'path': 'assets/images/coconutonbeachpfp.png',
        'description': 'Tropical and adventurous'
      },
      {
        'name': 'Pumpkin',
        'path': 'assets/images/pumpkinpfp.png',
        'description': 'Warm and welcoming'
      },
      {
        'name': 'Cactus',
        'path': 'assets/images/cactusindessertpfp.png',
        'description': 'Strong and independent'
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Default Avatar',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: availableAvatars.length,
            itemBuilder: (context, index) {
              final avatar = availableAvatars[index];
              return GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  await _selectDefaultAvatar(avatar['path']!);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen.withOpacity(0.1),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            avatar['path']!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        avatar['name']!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        avatar['description']!,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textMedium,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textMedium),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDefaultAvatar(String avatarPath) async {
    try {
      await ProfileService.updateAvatarOnly(avatarPath);
      
      setState(() {
        _futureProfile = ProfileService.fetchCurrentUserProfile();
      });
      
      // Force rebuild of the navbar to show updated avatar
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/profile');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avatar updated successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update avatar: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

} 
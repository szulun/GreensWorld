import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/navbar_home.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import '../models/comment.dart';
import '../models/xp_history.dart';

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 0;
  int _selectedTrendingPeriod = 0; // 0: Today, 1: This Week, 2: This Month
  List<PlantPost> _posts = [];
  bool _isLoading = true;
  User? _currentUser;
  int _userExperience = 0; // User experience points

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadPosts();
    _loadUserExperience();
    _fixOldPosts(); // Fix old posts that don't have userAvatar field
  }

  Future<void> _loadUserExperience() async {
    if (_currentUser != null) {
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userExperience = userData['experience'] ?? 0;
          });
        }
      } catch (e) {
        print('Error loading user experience: $e');
      }
    }
  }

  Future<void> _addExperience(int points) async {
    if (_currentUser != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({
          'experience': FieldValue.increment(points),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _userExperience += points;
        });
        
        // Add XP history record
        final now = DateTime.now();
        String action = 'Activity';
        String description = 'Earned XP';
        
        // Determine action type based on points
        if (points == 10) {
          action = 'Post';
          description = 'Shared a beautiful plant photo';
        } else if (points == 1) {
          action = 'Like';
          description = 'Liked a community post';
        } else if (points == 3) {
          action = 'Comment';
          description = 'Left a helpful comment';
        } else if (points == 5) {
          action = 'Help';
          description = 'Helped another user';
        } else if (points == -1) {
          action = 'Unlike';
          description = 'Removed a like';
        }
        
        print('Creating XP history item...');
        print('Action: $action, Description: $description, Points: $points');
        
        final xpHistoryItem = XPHistoryItem(
          id: 'xp_${DateTime.now().millisecondsSinceEpoch}',
          action: action,
          xpEarned: points,
          description: description,
          timestamp: now,
          relatedId: null,
          relatedType: 'activity',
        );
        
        print('XP history item created: ${xpHistoryItem.toJson()}');
        
        // Add to XP history
        print('Calling XPHistoryService.addXPHistory...');
        await XPHistoryService.addXPHistory(_currentUser!.uid, xpHistoryItem);
        print('XPHistoryService.addXPHistory completed');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 +$points XP! Total: $_userExperience XP'),
            backgroundColor: AppColors.successGreen,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        print('Error adding experience: $e');
      }
    }
  }

  // Fix old posts that don't have userAvatar field
  Future<void> _fixOldPosts() async {
    try {
      print('Checking for old posts without userAvatar field...');
      
      // Get all posts from Firestore
      final QuerySnapshot querySnapshot = await _firestore
          .collection('plant_posts')
          .get();

      int fixedCount = 0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if post has userAvatar field
        if (data['userAvatar'] == null || data['userAvatar'].toString().isEmpty) {
          print('Found old post without userAvatar: ${doc.id}');
          
          // Get user data to add userAvatar field
          final userDoc = await _firestore
              .collection('users')
              .doc(data['userId'])
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userAvatar = userData['avatarUrl'] ?? userData['profileImage'] ?? 'assets/images/dandelionpfp.png';
            
            // Update the post with userAvatar field
            await _firestore
                .collection('plant_posts')
                .doc(doc.id)
                .update({
              'userAvatar': userAvatar,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            print('Fixed post ${doc.id} with userAvatar: $userAvatar');
            fixedCount++;
          }
        }
      }
      
      if (fixedCount > 0) {
        print('Fixed $fixedCount old posts with userAvatar field');
        // Reload posts to show updated avatars
        _loadPosts();
      } else {
        print('No old posts found that need fixing');
      }
    } catch (e) {
      print('Error fixing old posts: $e');
    }
  }

  Future<void> _loadPosts() async {
    try {
      setState(() => _isLoading = true);
      
      // Get posts from Firestore
      final QuerySnapshot querySnapshot = await _firestore
          .collection('plant_posts')
          .orderBy('timestamp', descending: true)
          .get();

      print('Found ${querySnapshot.docs.length} posts in Firestore');
      
      final List<PlantPost> posts = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('Post data: $data');
        print('Images field: ${data['images']}');
        print('Images type: ${data['images'].runtimeType}');
        
        // Get user data
        final userDoc = await _firestore
            .collection('users')
            .doc(data['userId'])
            .get();
        
        final userData = userDoc.data() as Map<String, dynamic>?;
        print('User data for ${data['userId']}: $userData');
        print('User avatar URL: ${userData?['avatarUrl']}');
        print('User profile image: ${userData?['profileImage']}');
        
        // Check if current user has liked this post
        bool isLiked = false;
        if (_currentUser != null) {
          final likeDoc = await _firestore
              .collection('plant_posts')
              .doc(doc.id)
              .collection('likes')
              .doc(_currentUser!.uid)
              .get();
          isLiked = likeDoc.exists;
        }

        final images = List<String>.from(data['images'] ?? []);
        print('Processed images: $images');
        print('Images length: ${images.length}');
        
        // Debug image URLs
        for (int i = 0; i < images.length; i++) {
          print('Image $i: ${images[i]}');
          print('Image $i starts with http: ${images[i].startsWith('http')}');
          print('Image $i starts with assets: ${images[i].startsWith('assets')}');
        }

        // Get user avatar - prioritize userAvatar field, then user data, then default
        String userAvatar = 'assets/images/dandelionpfp.png';
        if (data['userAvatar'] != null && data['userAvatar'].isNotEmpty) {
          userAvatar = data['userAvatar'];
          print('Using post userAvatar field: $userAvatar');
        } else if (userData?['avatarUrl'] != null && userData!['avatarUrl'].isNotEmpty) {
          userAvatar = userData!['avatarUrl'];
          print('Using user avatarUrl: $userAvatar');
        } else if (userData?['profileImage'] != null && userData!['profileImage'].isNotEmpty) {
          userAvatar = userData!['profileImage'];
          print('Using user profileImage: $userAvatar');
        } else {
          print('Using default avatar: $userAvatar');
        }

        posts.add(PlantPost(
          id: doc.id,
          userId: data['userId'],
          username: userData?['username'] ?? 'Unknown User',
          userAvatar: userAvatar,
          plantName: data['plantName'] ?? '',
          description: data['description'] ?? '',
          images: images,
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          isLiked: isLiked,
        ));
      }

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
      
      print('Final posts list: ${_posts.map((p) => '${p.plantName}: ${p.images}').toList()}');
    } catch (e) {
      print('Error loading posts: $e');
      setState(() => _isLoading = false);
      
      // If loading fails, show sample data
      _posts = _getSamplePosts();
    }
  }

  List<PlantPost> _getSamplePosts() {
    return [
      PlantPost(
        id: '1',
        userId: 'user1',
        username: 'PlantLover_Jane',
        userAvatar: 'assets/images/dandelionpfp.png',
        plantName: 'Monstera Deliciosa',
        description: 'My beautiful Monstera is thriving! 🌿 The new leaves are getting bigger and more fenestrated. Plant care tip: They love bright indirect light and humidity.',
        images: ['assets/images/plant_sample/monstera.jpeg'],
        likes: 24,
        comments: 8,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isLiked: false,
      ),
      PlantPost(
        id: '2',
        userId: 'user2',
        username: 'GreenThumb_Mike',
        userAvatar: 'assets/images/orchidpfp.png',
        plantName: 'Fiddle Leaf Fig',
        description: 'Just repotted my Fiddle Leaf Fig and it\'s loving its new home! 🏡 Remember to use well-draining soil and don\'t overwater.',
        images: ['assets/images/plant_sample/rose.jpg'],
        likes: 31,
        comments: 12,
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        isLiked: true,
      ),
      PlantPost(
        id: '3',
        userId: 'user3',
        username: 'SucculentQueen',
        userAvatar: 'assets/images/cactusindessertpfp.png',
        plantName: 'Echeveria Collection',
        description: 'My succulent babies are blooming! 🌸 These little guys are so low maintenance but so rewarding. Perfect for beginners!',
        images: ['assets/images/plant_sample/succulents.jpg'],
        likes: 45,
        comments: 15,
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        isLiked: false,
      ),
      // Realistic plant post
      PlantPost(
        id: '4',
        userId: 'user4',
        username: 'GardenGuru_Sarah',
        userAvatar: 'assets/images/pumpkinpfp.png',
        plantName: 'Peace Lily',
        description: 'My Peace Lily is finally blooming after months of care! 🌸 The white flowers are so elegant. Remember to keep the soil moist but not soggy.',
        images: ['assets/images/plant_sample/daisy.jpg'],
        likes: 18,
        comments: 5,
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        isLiked: false,
      ),
      // Another realistic post
      PlantPost(
        id: '5',
        userId: 'user5',
        username: 'IndoorJungle_John',
        userAvatar: 'assets/images/orchidpfp.png',
        plantName: 'Snake Plant',
        description: 'Snake plants are perfect for beginners! 🌿 They\'re practically indestructible and help purify indoor air. Mine has grown so much this year!',
        images: ['assets/images/plant_sample/succulents.jpg'],
        likes: 22,
        comments: 7,
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        isLiked: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: NavbarHome(
        userExperience: _userExperience,
      ),
      body: Column(
        children: [
          // top navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildNavTab(0, 'Feed', Icons.home),
                const SizedBox(width: 16),
                _buildNavTab(1, 'Following', Icons.people),
                const SizedBox(width: 16),
                _buildNavTab(2, 'Trending', Icons.trending_up),
                const SizedBox(width: 16),
                _buildNavTab(3, 'My Posts', Icons.person),
              ],
            ),
          ),
          
          // content area
          Expanded(
            child: _selectedIndex == 0
                ? _buildFeed()
                : _selectedIndex == 1
                    ? _buildFollowing()
                    : _selectedIndex == 2
                        ? _buildTrending()
                        : _buildMyPosts(),
          ),
        ],
      ),
      floatingActionButton: _currentUser != null
          ? FloatingActionButton(
              onPressed: _showAddPostDialog,
              backgroundColor: AppColors.primaryGreen,
              child: const Icon(Icons.add_a_photo, color: Colors.white),
              tooltip: 'Add New Post',
            )
          : null,
    );
  }

  Widget _buildNavTab(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textMedium,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_florist,
              size: 64,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share your plants!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
            if (_currentUser != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showAddPostDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: Text('Share Your First Plant'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8, // Adjust card aspect ratio
        ),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return _buildGridPostCard(_posts[index]);
        },
      ),
    );
  }

  Widget _buildFollowing() {
    return FutureBuilder<List<PlantPost>>(
      future: _loadFollowingPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.errorRed,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorRed,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          );
        }
        
        final followingPosts = snapshot.data ?? [];
        
        print('📊 Following posts count: ${followingPosts.length}');
        
        // Always show following list and posts
        return SingleChildScrollView(
            child: Column(
            children: [
              // Header with discover users button
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Following',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showDiscoverUsers(),
                      icon: Icon(Icons.person_add, size: 18),
                      label: Text('Discover Users'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Following users list
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Following Users',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getFollowingUsers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                                  size: 48,
                  color: AppColors.textMedium,
                ),
                const SizedBox(height: 16),
                Text(
                                  'Not following anyone yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start following users to see their posts here',
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
                        
                        return Column(
                          children: snapshot.data!.map((user) => _buildFollowingUserCard(user)).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
                const SizedBox(height: 24),
              
              // Following posts section
              if (followingPosts.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Posts from Following',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...followingPosts.map((post) => _buildPostCard(post)).toList(),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Suggested users section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Suggested Users',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showUserSearchDialog(),
                          icon: Icon(Icons.search, size: 18),
                          label: Text('Search Users'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getSuggestedUsers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: AppColors.textMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No suggested users found',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _showUserSearchDialog(),
                                  icon: Icon(Icons.search, size: 18),
                                  label: Text('Search for Users'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return Column(
                          children: snapshot.data!.map((user) => _buildSuggestedUserCard(user)).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32), // Add bottom padding
              ],
            ),
          );
        
        print('📱 Building following posts list with ${followingPosts.length} posts');
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: followingPosts.length,
          itemBuilder: (context, index) {
            final post = followingPosts[index];
            print('📝 Building post card for: ${post.plantName} by ${post.username}');
            return _buildPostCard(post);
          },
        );
      },
    );
  }

  // Load posts from users that the current user is following
  Future<List<PlantPost>> _loadFollowingPosts() async {
    if (_currentUser == null) return [];
    
    try {
      print('🔍 Loading following posts for user: ${_currentUser!.uid}');
      
      // Get user's following list
      final followingDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('following')
          .get();
      
      print('📋 Found ${followingDoc.docs.length} following relationships');
      
      if (followingDoc.docs.isEmpty) {
        print('❌ No following relationships found');
        return [];
      }
      
      final followingIds = followingDoc.docs.map((doc) => doc.id).toList();
      print('👥 Following user IDs: $followingIds');
      
      // Get posts from followed users
      final postsQuery = await _firestore
          .collection('plant_posts')
          .where('userId', whereIn: followingIds)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      print('📝 Found ${postsQuery.docs.length} posts from followed users');
      
      final List<PlantPost> posts = [];
      
      for (final doc in postsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        posts.add(PlantPost(
          id: doc.id,
          userId: data['userId'] ?? '',
          username: data['username'] ?? 'Anonymous',
          userAvatar: data['userAvatar'] ?? 'assets/images/dandelionpfp.png',
          plantName: data['plantName'] ?? '',
          description: data['description'] ?? '',
          images: List<String>.from(data['images'] ?? []),
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          isLiked: false, // Will be updated later if needed
        ));
      }
      
      print('✅ Successfully loaded ${posts.length} following posts');
      return posts;
    } catch (e) {
      print('❌ Error loading following posts: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Load trending posts based on engagement metrics
  Future<List<PlantPost>> _loadTrendingPosts(int period) async {
    try {
      DateTime startDate;
      final now = DateTime.now();
      
      switch (period) {
        case 0: // Today
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 1: // This Week
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 2: // This Month
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }
      
      // Get posts from the specified period
      final postsQuery = await _firestore
          .collection('plant_posts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .get();
      
      final List<PlantPost> posts = [];
      
      for (final doc in postsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        posts.add(PlantPost(
          id: doc.id,
          userId: data['userId'] ?? '',
          username: data['username'] ?? 'Anonymous',
          userAvatar: data['userAvatar'] ?? 'assets/images/dandelionpfp.png',
          plantName: data['plantName'] ?? '',
          description: data['description'] ?? '',
          images: List<String>.from(data['images'] ?? []),
          likes: data['likes'] ?? 0,
          comments: data['comments'] ?? 0,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          isLiked: false,
        ));
      }
      
      // Sort by engagement score (likes + comments * 2 + recency bonus)
      posts.sort((a, b) {
        final aScore = _calculateEngagementScore(a);
        final bScore = _calculateEngagementScore(b);
        return bScore.compareTo(aScore);
      });
      
      return posts.take(20).toList(); // Return top 20 trending posts
    } catch (e) {
      print('Error loading trending posts: $e');
      return [];
    }
  }

  // Calculate engagement score for trending algorithm
  double _calculateEngagementScore(PlantPost post) {
    final likes = post.likes.toDouble();
    final comments = post.comments.toDouble();
    final hoursSincePosted = DateTime.now().difference(post.timestamp).inHours.toDouble();
    
    // Base score: likes + comments * 2
    double score = likes + (comments * 2);
    
    // Recency bonus: newer posts get a boost
    if (hoursSincePosted < 24) {
      score *= 1.5; // 50% boost for posts less than 24 hours old
    } else if (hoursSincePosted < 168) { // 1 week
      score *= 1.2; // 20% boost for posts less than 1 week old
    }
    
    return score;
  }

  // Show discover users dialog
  void _showDiscoverUsers() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
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
                      Icons.people,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Discover Plant Lovers',
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
              
              // Users list
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadDiscoverUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Text(
                          'Error loading users',
                          style: GoogleFonts.inter(color: AppColors.errorRed),
                        ),
                      );
                    }
                    
                    final users = snapshot.data!;
                    
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'No users found',
                          style: GoogleFonts.inter(color: AppColors.textMedium),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _buildUserCard(user);
                      },
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

  // Load users to discover
  Future<List<Map<String, dynamic>>> _loadDiscoverUsers() async {
    if (_currentUser == null) return [];
    
    try {
      // Get users that the current user is not following
      final followingDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('following')
          .get();
      
      final followingIds = followingDoc.docs.map((doc) => doc.id).toList();
      followingIds.add(_currentUser!.uid); // Exclude current user
      
      // Get all users except those already followed
      final usersQuery = await _firestore
          .collection('users')
          .limit(50)
          .get();
      
      final List<Map<String, dynamic>> users = [];
      
      for (final doc in usersQuery.docs) {
        if (!followingIds.contains(doc.id)) {
          final userData = doc.data();
          users.add({
            'id': doc.id,
            'displayName': userData['displayName'] ?? userData['email'] ?? 'Anonymous',
            'email': userData['email'] ?? '',
            'avatarUrl': userData['avatarUrl'] ?? userData['profileImage'],
            'bio': userData['bio'] ?? 'Plant lover',
            'postCount': userData['postCount'] ?? 0,
          });
        }
      }
      
      return users;
    } catch (e) {
      print('Error loading discover users: $e');
      return [];
    }
  }

  // Show user search dialog
  void _showUserSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    
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
                      Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search Users',
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
              
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by username, display name, or bio...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primaryGreen),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    // Trigger search as user types
                    setState(() {});
                  },
                ),
              ),
              
              // Search results
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _searchUsers(searchController.text),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: AppColors.errorRed,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error searching users',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.errorRed,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please try again later',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    final searchResults = snapshot.data ?? [];
                    
                    if (searchController.text.isEmpty && searchResults.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: AppColors.textMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Search for users',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Type a username or display name to find users',
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
                    
                    if (searchController.text.isNotEmpty && searchResults.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off,
                              size: 64,
                              color: AppColors.textMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
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
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final user = searchResults[index];
                        return _buildSuggestedUserCard(user);
                      },
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

  // Search users by username, display name, or bio
  Future<List<Map<String, dynamic>>> _searchUsers(String searchTerm) async {
    if (_currentUser == null || searchTerm.isEmpty) return [];
    
    try {
      // Search in users collection
      final usersQuery = await _firestore
          .collection('users')
          .get();
      
      final List<Map<String, dynamic>> searchResults = [];
      
      for (final doc in usersQuery.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        
        // Skip current user
        if (doc.id == _currentUser!.uid) continue;
        
        // Check if user is already being followed
        final followingDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('following')
            .doc(doc.id)
            .get();
        
        if (followingDoc.exists) continue; // Skip already following
        
        // Search in username, displayName, and bio
        final username = userData['username']?.toString().toLowerCase() ?? '';
        final displayName = userData['displayName']?.toString().toLowerCase() ?? '';
        final bio = userData['bio']?.toString().toLowerCase() ?? '';
        final searchLower = searchTerm.toLowerCase();
        
        if (username.contains(searchLower) || 
            displayName.contains(searchLower) || 
            bio.contains(searchLower)) {
          
          // Get user's post count
          final postsQuery = await _firestore
              .collection('plant_posts')
              .where('userId', isEqualTo: doc.id)
              .get();
          
          searchResults.add({
            'id': doc.id,
            'displayName': userData['username'] ?? userData['displayName'] ?? 'Unknown User',
            'avatarUrl': userData['avatarUrl'] ?? userData['profileImage'] ?? 'assets/images/dandelionpfp.png',
            'bio': userData['bio'] ?? 'Plant enthusiast 🌿',
            'postCount': postsQuery.docs.length,
            'isFollowing': false,
          });
        }
      }
      
      // Limit results to 20
      return searchResults.take(20).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Build user card for discover
  Widget _buildUserCard(Map<String, dynamic> user) {
    final isFollowing = false; // Will be updated when following system is implemented
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: user['avatarUrl'] != null
              ? NetworkImage(user['avatarUrl'])
              : AssetImage('assets/images/avatar/dandelionpfp.png') as ImageProvider,
        ),
        title: Text(
          user['displayName'],
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['bio'],
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
            ),
            Text(
              '${user['postCount']} posts',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _followUser(user['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? AppColors.surfaceMedium : AppColors.primaryGreen,
            foregroundColor: isFollowing ? AppColors.textDark : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            isFollowing ? 'Following' : 'Follow',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // Check if current user is following a specific user
  Future<bool> _isUserFollowing(String userId) async {
    if (_currentUser == null) return false;
    
    try {
      final followingDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('following')
          .doc(userId)
          .get();
      
      return followingDoc.exists;
    } catch (e) {
      print('Error checking following status: $e');
      return false;
    }
  }

  // Refresh following data after changes
  void _refreshFollowingData() {
    // Force refresh of following posts and suggested users
    setState(() {
      // This will trigger rebuild of FutureBuilder widgets
    });
  }

  // Follow a user
  Future<void> _followUser(String userId) async {
    if (_currentUser == null) return;
    
    try {
      print('🔗 Following user: $userId');
      
      // Add to following collection
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('following')
          .doc(userId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('✅ Added to following collection');
      
      // Add to followers collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(_currentUser!.uid)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('✅ Added to followers collection');
      
      // Show success message
      if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Now following user!'),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
      }
      
      // Refresh the UI to show updated following status
      setState(() {});
      
      // Refresh following posts and suggested users
      _refreshFollowingData();
      
      // If we're in the discover users dialog, close it
      if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      }
      
    } catch (e) {
      print('❌ Error following user: $e');
      print('Stack trace: ${StackTrace.current}');
      if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error following user: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      }
    }
  }

  Widget _buildTrending() {
    return Column(
      children: [
        // Trending filter tabs
        _buildTrendingTab(),
        
        // Trending posts
        Expanded(
          child: FutureBuilder<List<PlantPost>>(
            future: _loadTrendingPosts(_selectedTrendingPeriod),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.errorRed,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading trending posts',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.errorRed,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please try again later',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final trendingPosts = snapshot.data ?? [];
              
              if (trendingPosts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 64,
                        color: AppColors.textMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No trending posts yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to create a trending post!',
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
              
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: trendingPosts.length,
                itemBuilder: (context, index) {
                  final post = trendingPosts[index];
                  return _buildTrendingPostCard(post);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(PlantPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _getAvatarImageProvider(post.userAvatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _formatTimestamp(post.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentUser != null && post.userId == _currentUser!.uid)
                  IconButton(
                    onPressed: () => _showPostOptions(post),
                    icon: Icon(
                      Icons.more_horiz,
                      color: AppColors.textMedium,
                    ),
                  ),
              ],
            ),
          ),

          // Plant photos - support multiple images with carousel
          if (post.images.isNotEmpty)
            Container(
              width: double.infinity,
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    // Main image display
                    PageView.builder(
                      itemCount: post.images.length,
                      itemBuilder: (context, index) {
                        return Image(
                          image: _getImageProvider(post.images[index]),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $error');
                    return Container(
                      width: double.infinity,
                      height: 300,
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                            );
                          },
                    );
                  },
                ),
                    // Image count indicator (only show if multiple images)
                    if (post.images.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${post.images.length - 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // Page indicator dots (only show if multiple images)
                    if (post.images.length > 1)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            post.images.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == 0 ? Colors.white : Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Interaction buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _currentUser != null ? () => _toggleLike(post.id, post.isLiked) : null,
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : AppColors.textMedium,
                    size: 24,
                  ),
                ),
                IconButton(
                  onPressed: () => _showComments(post),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textMedium,
                    size: 24,
                  ),
                ),
                // Help button - only show if not the user's own post
                if (_currentUser != null && post.userId != _currentUser!.uid)
                  IconButton(
                    onPressed: () => _helpUser(post.id, post.userId),
                    icon: Icon(
                      Icons.help_outline,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                    tooltip: 'Help this user (+5 XP)',
                  ),
                const Spacer(),
                IconButton(
                  onPressed: () => _sharePost(post),
                  icon: Icon(
                    Icons.share,
                    color: AppColors.textMedium,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Like count
          if (post.likes > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${post.likes} likes',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),

          // Plant name and description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.plantName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  post.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // Comment preview
          if (post.comments > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show comment previews
                  FutureBuilder<List<Comment>>(
                    future: _loadComments(post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 20, child: Center(child: CircularProgressIndicator()));
                      }
                      
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      
                      final comments = snapshot.data!;
                      if (comments.isEmpty) return const SizedBox.shrink();
                      
                      // Show up to 3 comment previews
                      final previewComments = comments.take(3).toList();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...previewComments.map((comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: comment.userAvatar != null
                                      ? NetworkImage(comment.userAvatar!)
                                      : AssetImage('assets/images/avatar/dandelionpfp.png') as ImageProvider,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textDark,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: comment.userName,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const TextSpan(text: ' '),
                                        TextSpan(text: comment.content),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          // Show "View all comments" if there are more than 3
                          if (comments.length > 3)
                            GestureDetector(
                onTap: () => _showComments(post),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                child: Text(
                                  'View all ${comments.length} comments',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMedium,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddPostDialog() {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share plants')),
      );
      return;
    }

    final TextEditingController plantNameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    List<String> selectedImages = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_florist,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Share Your Plant',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: plantNameController,
                              decoration: InputDecoration(
                                labelText: 'Plant Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.eco, color: AppColors.primaryGreen),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.description, color: AppColors.primaryGreen),
                                hintText: 'Tell us about your plant...',
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Photo selection area
                            Text(
                              'Plant Photos',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.surfaceLight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (selectedImages.isEmpty)
                                    GestureDetector(
                                      onTap: () => _showImagePickerDialog(context, selectedImages, setDialogState),
                                      child: Container(
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceMedium,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.primaryGreen.withValues(alpha: 0.2),
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo,
                                              size: 40,
                                              color: AppColors.primaryGreen,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add Photo',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: AppColors.primaryGreen,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tap to select photos',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors.textMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                            childAspectRatio: 1.0,
                                          ),
                                          itemCount: selectedImages.length + 1,
                                          itemBuilder: (context, index) {
                                            if (index == selectedImages.length) {
                                              return GestureDetector(
                                                onTap: () => _showImagePickerDialog(context, selectedImages, setDialogState),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceMedium,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.add,
                                                    color: AppColors.primaryGreen,
                                                    size: 24,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Stack(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      selectedImages[index],
                                                      width: 80,
                                                      height: 80,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Container(
                                                          width: 80,
                                                          height: 80,
                                                          color: Colors.grey[200],
                                                          child: Icon(
                                                            Icons.error_outline,
                                                            color: Colors.grey[400],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setDialogState(() {
                                                        selectedImages.removeAt(index);
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '${selectedImages.length} photo(s) selected',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Actions
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                color: AppColors.textMedium,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: plantNameController.text.isNotEmpty && selectedImages.isNotEmpty
                                ? () {
                                    _addNewPost(
                                      plantNameController.text,
                                      descriptionController.text,
                                      selectedImages,
                                    );
                                    Navigator.of(context).pop();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Share Plant',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImagePickerDialog(BuildContext context, List<String> selectedImages, StateSetter setDialogState) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primaryGreen),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, selectedImages, setDialogState);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primaryGreen),
                title: Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, selectedImages, setDialogState);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, List<String> selectedImages, StateSetter setDialogState) async {
    try {
      print('Starting image picker with source: $source');
      print('Current platform: ${kIsWeb ? 'Web' : 'Mobile'}');
      print('SelectedImages before picking: $selectedImages');
      print('SelectedImages length before picking: ${selectedImages.length}');
      
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      print('Image picker result: ${image?.path ?? 'No image selected'}');
      
      if (image != null) {
        // Use base64 method like profile page (more reliable)
        print('Converting image to base64...');
        final bytes = await image.readAsBytes();
        final String base64String = base64Encode(bytes);
        final String dataUrl = 'data:image/jpeg;base64,$base64String';
        
        print('Image converted to base64 successfully');
        print('Data URL length: ${dataUrl.length}');
        
        // Add image to the list
        selectedImages.add(dataUrl);
        print('Added image to selectedImages: $dataUrl');
        print('SelectedImages after adding: $selectedImages');
        print('SelectedImages length after adding: ${selectedImages.length}');
        
        // Force a rebuild of the dialog
        setDialogState(() {});
        
        print('Image added successfully!');
        print('SelectedImages after setState: $selectedImages');
        print('SelectedImages length after setState: ${selectedImages.length}');
        } else {
        print('No image was selected by user');
      }
    } catch (e) {
      print('Error picking image: $e');
      print('Error stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<String> _uploadImageToStorage(XFile image) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final bytes = await image.readAsBytes();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'plant_posts/${user.uid}/post_$timestamp.jpg';
      
      final storage = FirebaseStorage.instance;
      final storageRef = storage.ref().child(fileName);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      
      final uploadTask = storageRef.putData(bytes, metadata);
      final snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _addNewPost(String plantName, String description, List<String> images) async {
    if (_currentUser == null) return;

    try {
      print('Starting to add new post...');
      print('Current user ID: ${_currentUser!.uid}');
      print('Plant name: $plantName');
      print('Description: $description');
      print('Images: $images');

      // Get user data
      print('Fetching user data...');
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      
      print('User document exists: ${userDoc.exists}');
      final userData = userDoc.data() as Map<String, dynamic>?;
      print('User data: $userData');
      
      final username = userData?['username'] ?? _currentUser!.email?.split('@')[0] ?? 'User';
      print('Username: $username');

      // Create new post document
      print('Creating post document...');
      final userAvatar = userData?['avatarUrl'] ?? 'assets/images/dandelionpfp.png';
      final postRef = await _firestore.collection('plant_posts').add({
        'userId': _currentUser!.uid,
        'username': username,
        'userAvatar': userAvatar, // Add userAvatar field
        'plantName': plantName,
        'description': description,
        'images': images,
        'likes': 0,
        'comments': 0,
        'timestamp': Timestamp.now(),
      });

      print('Post created with ID: ${postRef.id}');

      // Create new post object
      final newPost = PlantPost(
        id: postRef.id,
        userId: _currentUser!.uid,
        username: username,
        userAvatar: userData?['avatarUrl'] ?? 'assets/images/dandelionpfp.png',
        plantName: plantName,
        description: description,
        images: images,
        likes: 0,
        comments: 0,
        timestamp: DateTime.now(),
        isLiked: false,
      );

      setState(() {
        _posts.insert(0, newPost);
      });

      print('Post added to local state successfully');

      // Add XP for creating a post - reward based on number of photos
      final photoCount = images.length;
      final xpReward = photoCount * 10; // 10 XP per photo
      await _addExperience(xpReward);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post shared successfully! +$xpReward XP for $photoCount photo${photoCount > 1 ? 's' : ''}! 🎉'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e, stackTrace) {
      print('Error adding post: $e');
      print('Stack trace: $stackTrace');
      
      // Show detailed error message
      String errorMessage = 'Failed to share post';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check your account.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage = 'Service unavailable. Please try again later.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else {
        errorMessage = 'Error: $e';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Show post details
  void _showPostDetail(PlantPost post) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Post content
              Expanded(
                child: SingleChildScrollView(
                  child: _buildPostCard(post),
                ),
              ),
              // Close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(String postId, bool isLiked) async {
    if (_currentUser == null) return;

    try {
      final postRef = _firestore.collection('plant_posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(_currentUser!.uid);

      if (isLiked) {
        // Unlike
        await likeRef.delete();
        await postRef.update({
          'likes': FieldValue.increment(-1),
        });
        
        // Remove experience for unliking
        await _addExperience(-1);
      } else {
        // Like
        await likeRef.set({
          'userId': _currentUser!.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await postRef.update({
          'likes': FieldValue.increment(1),
        });
        
        // Add experience for liking
        await _addExperience(1);
      }

      // Update local post state immediately for better UX
      setState(() {
        final postIndex = _posts.indexWhere((post) => post.id == postId);
        if (postIndex != -1) {
          _posts[postIndex] = _posts[postIndex].copyWith(
            isLiked: !isLiked,
            likes: _posts[postIndex].likes + (isLiked ? -1 : 1),
          );
        }
      });

      // Also refresh posts from Firestore to ensure consistency
      _loadPosts();
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${isLiked ? 'unlike' : 'like'} post'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _helpUser(String postId, String userId) async {
    if (_currentUser == null) return;

    try {
      // Add experience for helping others
      await _addExperience(5);
      
      // Record the help action
      await _firestore
          .collection('plant_posts')
          .doc(postId)
          .collection('helps')
          .doc(_currentUser!.uid)
          .set({
        'helperId': _currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 +5 XP for helping others!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      print('Error recording help: $e');
    }
  }

  void _showComments(PlantPost post) {
    final TextEditingController commentController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments (${post.comments})',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Comments List
              Expanded(
                child: FutureBuilder<List<Comment>>(
                  future: _loadComments(post.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: AppColors.textMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final comments = snapshot.data!;
                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _buildCommentItem(comment);
                      },
                    );
                  },
                ),
              ),
              
              // Comment Input
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  border: Border(
                    top: BorderSide(color: AppColors.surfaceMedium),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: GoogleFonts.inter(
                            color: AppColors.textMedium,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.surfaceMedium),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _addComment(post.id, value.trim());
                            commentController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (commentController.text.trim().isNotEmpty) {
                          _addComment(post.id, commentController.text.trim());
                          commentController.clear();
                        }
                      },
                      icon: Icon(
                        Icons.send,
                        color: AppColors.primaryGreen,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build comment item
  Widget _buildCommentItem(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: comment.userAvatar != null
                ? NetworkImage(comment.userAvatar!)
                : AssetImage('assets/images/avatar/dandelionpfp.png') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeAgo(comment.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Get time ago string
  String _getTimeAgo(DateTime timestamp) {
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

  // Load comments for a post
  Future<List<Comment>> _loadComments(String postId) async {
    try {
      final querySnapshot = await _firestore
          .collection('plant_posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .get();

      final comments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Comment(
          id: doc.id,
          postId: postId,
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? 'Anonymous',
          userAvatar: data['userAvatar'],
          content: data['content'] ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();

      // If no comments in Firestore, return sample comments for demo
      if (comments.isEmpty) {
        return _getSampleComments(postId);
      }

      return comments;
    } catch (e) {
      print('Error loading comments: $e');
      // Return sample comments if Firestore fails
      return _getSampleComments(postId);
    }
  }

  // Get sample comments for demo purposes
  List<Comment> _getSampleComments(String postId) {
    final now = DateTime.now();
    
    switch (postId) {
      case '1': // Monstera post
        return [
          Comment(
            id: 'c1_1',
            postId: postId,
            userId: 'user2',
            userName: 'GreenThumb_Mike',
            userAvatar: 'assets/images/orchidpfp.png',
            content: 'Beautiful! How often do you water it?',
            timestamp: now.subtract(const Duration(hours: 1)),
          ),
          Comment(
            id: 'c1_2',
            postId: postId,
            userId: 'user3',
            userName: 'SucculentQueen',
            userAvatar: 'assets/images/cactusindessertpfp.png',
            content: 'Love the fenestrations! Mine is still young.',
            timestamp: now.subtract(const Duration(minutes: 30)),
          ),
          Comment(
            id: 'c1_3',
            postId: postId,
            userId: 'user4',
            userName: 'GardenGuru_Sarah',
            userAvatar: 'assets/images/pumpkinpfp.png',
            content: 'Great tip about indirect light! 🌿',
            timestamp: now.subtract(const Duration(minutes: 15)),
          ),
        ];
      case '2': // Fiddle Leaf Fig post
        return [
          Comment(
            id: 'c2_1',
            postId: postId,
            userId: 'user1',
            userName: 'PlantLover_Jane',
            userAvatar: 'assets/images/dandelionpfp.png',
            content: 'What soil mix did you use?',
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
          Comment(
            id: 'c2_2',
            postId: postId,
            userId: 'user3',
            userName: 'SucculentQueen',
            userAvatar: 'assets/images/cactusindessertpfp.png',
            content: 'Mine loves being near a window!',
            timestamp: now.subtract(const Duration(hours: 1)),
          ),
        ];
      case '3': // Succulent post
        return [
          Comment(
            id: 'c3_1',
            postId: postId,
            userId: 'user1',
            userName: 'PlantLover_Jane',
            userAvatar: 'assets/images/dandelionpfp.png',
            content: 'So pretty! What\'s your watering schedule?',
            timestamp: now.subtract(const Duration(hours: 3)),
          ),
          Comment(
            id: 'c3_2',
            postId: postId,
            userId: 'user2',
            userName: 'GreenThumb_Mike',
            userAvatar: 'assets/images/orchidpfp.png',
            content: 'Perfect for beginners indeed! 🌵',
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
        ];
      case '4': // Peace Lily post
        return [
          Comment(
            id: 'c4_1',
            postId: postId,
            userId: 'user1',
            userName: 'PlantLover_Jane',
            userAvatar: 'assets/images/dandelionpfp.png',
            content: 'Peace lilies are so elegant! 🌸',
            timestamp: now.subtract(const Duration(hours: 4)),
          ),
          Comment(
            id: 'c4_2',
            postId: postId,
            userId: 'user2',
            userName: 'GreenThumb_Mike',
            userAvatar: 'assets/images/orchidpfp.png',
            content: 'Mine blooms every spring!',
            timestamp: now.subtract(const Duration(hours: 3)),
          ),
        ];
      case '5': // Snake Plant post
        return [
          Comment(
            id: 'c5_1',
            postId: postId,
            userId: 'user1',
            userName: 'PlantLover_Jane',
            userAvatar: 'assets/images/dandelionpfp.png',
            content: 'Snake plants are my favorite! 🐍',
            timestamp: now.subtract(const Duration(hours: 5)),
          ),
          Comment(
            id: 'c5_2',
            postId: postId,
            userId: 'user3',
            userName: 'SucculentQueen',
            userAvatar: 'assets/images/cactusindessertpfp.png',
            content: 'They\'re so low maintenance!',
            timestamp: now.subtract(const Duration(hours: 4)),
          ),
          Comment(
            id: 'c5_3',
            postId: postId,
            userId: 'user4',
            userName: 'GardenGuru_Sarah',
            userAvatar: 'assets/images/pumpkinpfp.png',
            content: 'Great air purifier! 🌱',
            timestamp: now.subtract(const Duration(hours: 3)),
          ),
        ];
      default:
      return [];
    }
  }

  // Get users that the current user is following
  Future<List<Map<String, dynamic>>> _getFollowingUsers() async {
    if (_currentUser == null) return [];
    
    try {
      print('🔍 Getting following users for: ${_currentUser!.uid}');
      
      // Get user's following list
      final followingDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('following')
          .get();
      
      if (followingDoc.docs.isEmpty) {
        print('❌ No following relationships found');
        return [];
      }
      
      final followingIds = followingDoc.docs.map((doc) => doc.id).toList();
      print('👥 Following user IDs: $followingIds');
      
      final List<Map<String, dynamic>> followingUsers = [];
      
      for (final userId in followingIds) {
        // Get user profile data
        final userDoc = await _firestore
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          // Get user's post count
          final postsQuery = await _firestore
              .collection('plant_posts')
              .where('userId', isEqualTo: userId)
              .get();
          
          followingUsers.add({
            'id': userId,
            'displayName': userData['username'] ?? userData['displayName'] ?? 'Unknown User',
            'avatarUrl': userData['avatarUrl'] ?? userData['profileImage'] ?? 'assets/images/dandelionpfp.png',
            'bio': userData['bio'] ?? 'Plant enthusiast 🌿',
            'postCount': postsQuery.docs.length,
            'isFollowing': true,
          });
        }
      }
      
      print('✅ Found ${followingUsers.length} following users');
      return followingUsers;
    } catch (e) {
      print('❌ Error getting following users: $e');
      return [];
    }
  }

  // Get suggested users for following - real users from Firestore
  Future<List<Map<String, dynamic>>> _getSuggestedUsers() async {
    if (_currentUser == null) return [];
    
    try {
      // Get users that the current user is not following
      final followingDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('following')
          .get();
      
      final followingIds = followingDoc.docs.map((doc) => doc.id).toList();
      
      // Get all users except current user and already following
      final usersQuery = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereNotIn: [...followingIds, _currentUser!.uid])
          .limit(10)
          .get();
      
      final List<Map<String, dynamic>> suggestedUsers = [];
      
      for (final doc in usersQuery.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        
        // Get user's post count
        final postsQuery = await _firestore
            .collection('plant_posts')
            .where('userId', isEqualTo: doc.id)
            .get();
        
        suggestedUsers.add({
          'id': doc.id,
          'displayName': userData['username'] ?? userData['displayName'] ?? 'Unknown User',
          'avatarUrl': userData['avatarUrl'] ?? userData['profileImage'] ?? 'assets/images/dandelionpfp.png',
          'bio': userData['bio'] ?? 'Plant enthusiast 🌿',
          'postCount': postsQuery.docs.length,
          'isFollowing': false,
        });
      }
      
      print('Found ${suggestedUsers.length} suggested users (excluding ${followingIds.length} already following)');
      return suggestedUsers;
    } catch (e) {
      print('Error getting suggested users: $e');
      return [];
    }
  }

  // Build following user card (already following)
  Widget _buildFollowingUserCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: _getAvatarImageProvider(user['avatarUrl']),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['displayName'],
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['bio'],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textMedium,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user['postCount']} posts',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _unfollowUser(user['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Unfollow',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Unfollow a user
  Future<void> _unfollowUser(String userId) async {
    if (_currentUser == null) return;
    
    try {
      print('🔗 Unfollowing user: $userId');
      
      // Remove from following collection
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('following')
          .doc(userId)
          .delete();
      
      print('✅ Removed from following collection');
      
      // Remove from followers collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(_currentUser!.uid)
          .delete();
      
      print('✅ Removed from followers collection');
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Unfollowed user successfully'),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Refresh the UI
      setState(() {});
      _refreshFollowingData();
      
    } catch (e) {
      print('❌ Error unfollowing user: $e');
      print('Stack trace: ${StackTrace.current}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unfollowing user: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // Build suggested user card with dynamic following status
  Widget _buildSuggestedUserCard(Map<String, dynamic> user) {
    return FutureBuilder<bool>(
      future: _isUserFollowing(user['id']),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: _getAvatarImageProvider(user['avatarUrl']),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['displayName'],
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['bio'],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textMedium,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user['postCount']} posts',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isFollowing ? null : () => _followUser(user['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? AppColors.surfaceMedium : AppColors.primaryGreen,
                    foregroundColor: isFollowing ? AppColors.textDark : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add comment to a post
  Future<void> _addComment(String postId, String content) async {
    if (_currentUser == null) return;

    try {
      // Get user profile data
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      
      String userName = 'Anonymous';
      String? userAvatar;
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        userName = userData['displayName'] ?? userData['email'] ?? 'Anonymous';
        userAvatar = userData['avatarUrl'] ?? userData['profileImage'];
      }

      // Add comment to Firestore
      final commentRef = await _firestore
          .collection('plant_posts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': _currentUser!.uid,
        'userName': userName,
        'userAvatar': userAvatar,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update post comment count
      await _firestore
          .collection('plant_posts')
          .doc(postId)
          .update({
        'comments': FieldValue.increment(1),
      });

      // Add XP for commenting
      await _addExperience(3);

      // Refresh the comments
      setState(() {
        // Update local post data
        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          _posts[postIndex] = _posts[postIndex].copyWith(
            comments: _posts[postIndex].comments + 1,
          );
        }
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💬 Comment added! +3 XP'),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );

    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding comment: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _sharePost(PlantPost post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing ${post.plantName}...')),
    );
  }

  void _showPostOptions(PlantPost post) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: AppColors.primaryGreen),
                title: Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditPostDialog(post);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Post'),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost(post);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditPostDialog(PlantPost post) {
    final TextEditingController plantNameController = TextEditingController(text: post.plantName);
    final TextEditingController descriptionController = TextEditingController(text: post.description);
    List<String> selectedImages = List.from(post.images);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Edit Your Plant Post',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: plantNameController,
                              decoration: InputDecoration(
                                labelText: 'Plant Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.eco, color: AppColors.primaryGreen),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.description, color: AppColors.primaryGreen),
                                hintText: 'Tell us about your plant...',
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Photo management area
                            Text(
                              'Plant Photos',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.surfaceLight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (selectedImages.isEmpty)
                                    GestureDetector(
                                      onTap: () => _showImagePickerDialog(context, selectedImages, setDialogState),
                                      child: Container(
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceMedium,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.primaryGreen.withValues(alpha: 0.2),
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo,
                                              size: 40,
                                              color: AppColors.primaryGreen,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add Photo',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: AppColors.primaryGreen,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                            childAspectRatio: 1.0,
                                          ),
                                          itemCount: selectedImages.length + 1,
                                          itemBuilder: (context, index) {
                                            if (index == selectedImages.length) {
                                              return GestureDetector(
                                                onTap: () => _showImagePickerDialog(context, selectedImages, setDialogState),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceMedium,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.add,
                                                    color: AppColors.primaryGreen,
                                                    size: 24,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Stack(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      selectedImages[index],
                                                      width: 80,
                                                      height: 80,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Container(
                                                          width: 80,
                                                          height: 80,
                                                          color: Colors.grey[200],
                                                          child: Icon(
                                                            Icons.error_outline,
                                                            color: Colors.grey[400],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setDialogState(() {
                                                        selectedImages.removeAt(index);
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '${selectedImages.length} photo(s) selected',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Actions
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                color: AppColors.textMedium,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: plantNameController.text.isNotEmpty && selectedImages.isNotEmpty
                                ? () {
                                    _updatePost(
                                      post.id,
                                      plantNameController.text,
                                      descriptionController.text,
                                      selectedImages,
                                    );
                                    Navigator.of(context).pop();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Update Post',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updatePost(String postId, String plantName, String description, List<String> images) async {
    try {
      // Update post in Firestore
      await _firestore.collection('plant_posts').doc(postId).update({
        'plantName': plantName,
        'description': description,
        'images': images,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local post data
      setState(() {
        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          _posts[postIndex] = _posts[postIndex].copyWith(
            plantName: plantName,
            description: description,
            images: images,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post updated successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      print('Error updating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update post: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _deletePost(PlantPost post) async {
    try {
      // show confirm dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Delete Post'),
            content: Text('Are you sure you want to delete this post? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      // delete post from Firestore
      await _firestore.collection('plant_posts').doc(post.id).delete();

      // remove from local list
      setState(() {
        _posts.removeWhere((p) => p.id == post.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      print('Error deleting post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  ImageProvider _getImageProvider(String imageUrl) {
    print('Getting image provider for: $imageUrl');
    
    if (imageUrl.startsWith('http') || imageUrl.startsWith('https')) {
      // Firebase Storage URL or other network image
      print('Using NetworkImage for: $imageUrl');
      return NetworkImage(imageUrl);
    } else if (imageUrl.startsWith('assets/')) {
      // Local asset image
      print('Using AssetImage for: $imageUrl');
      return AssetImage(imageUrl);
    } else if (kIsWeb && imageUrl.startsWith('blob:')) {
      // Blob URL (fallback for web)
      print('Using NetworkImage for blob: $imageUrl');
      return NetworkImage(imageUrl);
    } else {
      // Default to network image
      print('Using default NetworkImage for: $imageUrl');
      return NetworkImage(imageUrl);
    }
  }

  // ImageProvider specifically for avatar images
  ImageProvider _getAvatarImageProvider(String avatarUrl) {
    print('Getting avatar image provider for: $avatarUrl');
    
    if (avatarUrl.startsWith('http') || avatarUrl.startsWith('https')) {
      // Firebase Storage URL or other network image
      print('Using NetworkImage for avatar: $avatarUrl');
      return NetworkImage(avatarUrl);
    } else if (avatarUrl.startsWith('assets/')) {
      // Local asset image
      print('Using AssetImage for avatar: $avatarUrl');
      return AssetImage(avatarUrl);
    } else if (avatarUrl.startsWith('data:image/')) {
      // Base64 data URL
      print('Using MemoryImage for base64 avatar');
      return MemoryImage(base64Decode(avatarUrl.split(',')[1]));
    } else {
      // Default to local asset (fallback avatar)
      print('Using default AssetImage for avatar: assets/images/dandelionpfp.png');
      return const AssetImage('assets/images/dandelionpfp.png');
    }
  }

  // Grid layout post card
  Widget _buildGridPostCard(PlantPost post) {
    return GestureDetector(
      onTap: () => _showPostDetail(post),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  children: [
                    // Main image
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: post.images.isNotEmpty
                          ? Image(
                              image: _getImageProvider(post.images.first),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.surfaceMedium,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: AppColors.textMedium,
                                    size: 32,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: AppColors.surfaceMedium,
                              child: Icon(
                                Icons.image_not_supported,
                                color: AppColors.textMedium,
                                size: 32,
                              ),
                            ),
                    ),
                    // Image count indicator
                    if (post.images.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${post.images.length - 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Content area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: _getAvatarImageProvider(post.userAvatar),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            post.username,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Plant name
                    Text(
                      post.plantName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    // Description
                    Expanded(
                      child: Text(
                        post.description,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textMedium,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Interaction info
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: post.isLiked ? AppColors.errorRed : AppColors.textMedium,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.likes}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textMedium,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.comments}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                    // Comment preview (show only first comment if exists)
                    if (post.comments > 0)
                      FutureBuilder<List<Comment>>(
                        future: _loadComments(post.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(height: 16, child: Center(child: CircularProgressIndicator()));
                          }
                          
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          
                          final firstComment = snapshot.data!.first;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 8,
                                  backgroundImage: firstComment.userAvatar != null
                                      ? NetworkImage(firstComment.userAvatar!)
                                      : AssetImage('assets/images/avatar/dandelionpfp.png') as ImageProvider,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        color: AppColors.textMedium,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: firstComment.userName,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const TextSpan(text: ' '),
                                        TextSpan(
                                          text: firstComment.content.length > 20 
                                              ? '${firstComment.content.substring(0, 20)}...'
                                              : firstComment.content,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build my posts page
  Widget _buildMyPosts() {
    if (_currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Please log in to view your posts',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      );
    }

    final myPosts = _posts.where((post) => post.userId == _currentUser!.uid).toList();

    if (myPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.post_add,
              size: 64,
              color: AppColors.textMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'You haven\'t posted anything yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your first plant with the community!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddPostDialog,
              icon: Icon(Icons.add_a_photo),
              label: Text('Create Your First Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'My Posts (${myPosts.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddPostDialog,
                icon: Icon(Icons.add_a_photo, size: 18),
                label: Text('New Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Posts list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: myPosts.length,
            itemBuilder: (context, index) {
              return _buildMyPostCard(myPosts[index]);
            },
          ),
        ),
      ],
    );
  }

  // Build my post card with edit/delete options
  Widget _buildMyPostCard(PlantPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info header with edit/delete options
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _getAvatarImageProvider(post.userAvatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _formatTimestamp(post.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit and delete options
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.textMedium),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditPostDialog(post);
                        break;
                      case 'delete':
                        _deletePost(post);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppColors.primaryGreen, size: 18),
                          const SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Plant photos - support multiple images with carousel
          if (post.images.isNotEmpty)
            Container(
              width: double.infinity,
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    // Main image display
                    PageView.builder(
                      itemCount: post.images.length,
                      itemBuilder: (context, index) {
                        return Image(
                          image: _getImageProvider(post.images[index]),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 300,
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    // Image count indicator (only show if multiple images)
                    if (post.images.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${post.images.length - 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // Page indicator dots (only show if multiple images)
                    if (post.images.length > 1)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            post.images.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == 0 ? Colors.white : Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Interaction buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _toggleLike(post.id, post.isLiked),
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : AppColors.textMedium,
                    size: 24,
                  ),
                ),
                IconButton(
                  onPressed: () => _showComments(post),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textMedium,
                    size: 24,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _sharePost(post),
                  icon: Icon(
                    Icons.share,
                    color: AppColors.textMedium,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Like count
          if (post.likes > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${post.likes} likes',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),

          // Plant name and description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.plantName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  post.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // Comment preview
          if (post.comments > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show comment previews
                  FutureBuilder<List<Comment>>(
                    future: _loadComments(post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 20, child: Center(child: CircularProgressIndicator()));
                      }
                      
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      
                      final comments = snapshot.data!;
                      final previewComments = comments.take(3).toList();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...previewComments.map((comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: comment.userAvatar != null
                                      ? NetworkImage(comment.userAvatar!)
                                      : AssetImage('assets/images/avatar/dandelionpfp.png') as ImageProvider,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textDark,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: comment.userName,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const TextSpan(text: ' '),
                                        TextSpan(text: comment.content),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          // Show "View all comments" if there are more than 3
                          if (comments.length > 3)
                            GestureDetector(
                              onTap: () => _showComments(post),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'View all ${comments.length} comments',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Build trending tab with filter buttons
  Widget _buildTrendingTab() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _selectedTrendingPeriod = 0),
                style: TextButton.styleFrom(
                  backgroundColor: _selectedTrendingPeriod == 0 
                      ? AppColors.primaryGreen 
                      : Colors.transparent,
                  foregroundColor: _selectedTrendingPeriod == 0 
                      ? Colors.white 
                      : AppColors.textMedium,
                ),
                child: Text('Today'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _selectedTrendingPeriod = 1),
                style: TextButton.styleFrom(
                  backgroundColor: _selectedTrendingPeriod == 1 
                      ? AppColors.primaryGreen 
                      : Colors.transparent,
                  foregroundColor: _selectedTrendingPeriod == 1 
                      ? Colors.white 
                      : AppColors.textMedium,
                ),
                child: Text('This Week'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _selectedTrendingPeriod = 2),
                style: TextButton.styleFrom(
                  backgroundColor: _selectedTrendingPeriod == 2 
                      ? AppColors.primaryGreen 
                      : Colors.transparent,
                  foregroundColor: _selectedTrendingPeriod == 2 
                      ? Colors.white 
                      : AppColors.textMedium,
                ),
                child: Text('This Month'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Build trending post card
  Widget _buildTrendingPostCard(PlantPost post) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: _getAvatarImageProvider(post.userAvatar),
        ),
        title: Text(
          post.plantName,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.favorite, size: 16, color: AppColors.errorRed),
                Text(' ${post.likes}'),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textMedium),
                Text(' ${post.comments}'),
              ],
            ),
          ],
        ),
        onTap: () => _showPostDetail(post),
      ),
    );
  }
}

class PlantPost {
  final String id;
  final String userId;
  final String username;
  final String userAvatar;
  final String plantName;
  final String description;
  final List<String> images;
  int likes;
  final int comments;
  final DateTime timestamp;
  bool isLiked;

  PlantPost({
    required this.id,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.plantName,
    required this.description,
    required this.images,
    required this.likes,
    required this.comments,
    required this.timestamp,
    required this.isLiked,
  });

  PlantPost copyWith({
    String? id,
    String? userId,
    String? username,
    String? userAvatar,
    String? plantName,
    String? description,
    List<String>? images,
    int? likes,
    int? comments,
    DateTime? timestamp,
    bool? isLiked,
  }) {
    return PlantPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      plantName: plantName ?? this.plantName,
      description: description ?? this.description,
      images: images ?? this.images,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      timestamp: timestamp ?? this.timestamp,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

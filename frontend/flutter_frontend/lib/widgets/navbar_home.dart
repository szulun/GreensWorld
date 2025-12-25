import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/theme.dart'; // Import the AppColors theme
import '../models/xp_system.dart';
import 'dart:convert';

// 旋轉的 Logo 組件
class RotatingLogo extends StatefulWidget {
  final double size;
  
  const RotatingLogo({
    super.key,
    this.size = 80,
  });

  @override
  State<RotatingLogo> createState() => _RotatingLogoState();
}

class _RotatingLogoState extends State<RotatingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8), 
      vsync: this,
    )..repeat(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159, // 完整旋轉
          child: Image.asset(
            'assets/images/logo_00.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}

class NavbarHome extends StatefulWidget implements PreferredSizeWidget {
  final String? title;
  final int? userExperience;
  final List<Widget>? actions;

  const NavbarHome({
    super.key,
    this.title,
    this.userExperience,
    this.actions,
  });

  @override
  State<NavbarHome> createState() => _NavbarHomeState();

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

class _NavbarHomeState extends State<NavbarHome> {
  String? _username;
  String? _firstName;
  String? _avatarUrl;
  bool _isLocalAsset = false;
  bool _isLoading = true;
  int _userExperience = 0;
  String _userLevel = 'Seedling';

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadUserExperience();
  }

  Future<void> _loadUsername() async {
    final User? user = FirebaseAuth.instance.currentUser;
    print('Navbar: Loading user data for ${user?.email}');
    
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        print('Navbar: Firestore document exists: ${doc.exists}');
        
        if (doc.exists) {
          final data = doc.data()!;
          print('Navbar: User data from Firestore: $data');
          setState(() {
            _username = data['username']?.toString();
            _firstName = data['firstName']?.toString();
            _avatarUrl = data['avatarUrl']?.toString() ?? data['profilePicture']?.toString();
            _isLocalAsset = data['isLocalAsset'] as bool? ?? false;
            _isLoading = false;
          });
          print('Navbar: Set username to $_username, firstName to $_firstName');
        } else {
          // If no Firestore document exists, create one with basic info
          final basicUserData = {
            'username': user.email?.split('@')[0] ?? 'User',
            'firstName': user.displayName?.split(' ')[0] ?? 'User',
            'lastName': user.displayName != null && user.displayName!.split(' ').length > 1 
                ? user.displayName!.split(' ').sublist(1).join(' ') 
                : '',
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          
          print('Navbar: Creating new user document with data: $basicUserData');
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(basicUserData);
          
          setState(() {
            _username = basicUserData['username']?.toString();
            _firstName = basicUserData['firstName']?.toString();
            _avatarUrl = null;
            _isLocalAsset = false;
            _isLoading = false;
          });
          print('Navbar: Set username to $_username, firstName to $_firstName');
        }
      } catch (e) {
        print('Navbar: Error loading user data: $e');
        setState(() {
          _username = user.email?.split('@')[0] ?? 'User';
          _firstName = user.displayName?.split(' ')[0] ?? 'User';
          _avatarUrl = null;
          _isLocalAsset = false;
          _isLoading = false;
        });
        print('Navbar: Set username to $_username, firstName to $_firstName');
      }
    } else {
      print('Navbar: No user logged in');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserExperience() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final userData = doc.data() as Map<String, dynamic>;
          setState(() {
            _userExperience = userData['experience'] ?? 0;
            _userLevel = XPSystem.getLevel(_userExperience);
          });
        }
      } catch (e) {
        print('Error loading user experience: $e');
      }
    }
  }

  void _showXPDetails(BuildContext context) {
    final nextLevelXP = XPSystem.getNextLevelXP(_userExperience);
    final currentLevelXP = XPSystem.getCurrentLevelXP(_userExperience);
    final progress = XPSystem.getProgressPercentage(_userExperience);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.4,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    XPSystem.levelIcons[_userLevel] ?? Icons.star,
                    color: AppColors.primaryGreen,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Progress',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Level $_userLevel',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // XP Progress
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceMedium),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current XP',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textMedium,
                          ),
                        ),
                        Text(
                          '$_userExperience XP',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surfaceMedium,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${nextLevelXP - _userExperience} XP to next level',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushNamed(context, '/profile');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'View Full Profile',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    bool isWide = MediaQuery.of(context).size.width > 700;
    
    return AppBar(
      backgroundColor: AppColors.surfaceMedium, // Using AppColors
      elevation: 3, 
      shadowColor: Colors.black26,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // logo and name - clickable to go home
              GestureDetector(
                onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        // logo
                        const RotatingLogo(
                          size: 120, 
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Greens',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryGreen, // Using AppColors
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          'Wrld',
                          style: GoogleFonts.poppins(
                            color: AppColors.accentGreen, // Using AppColors
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
              if (isWide) Row(children: _navLinks(context)),
            ],
          ),

          // Custom title and experience points
          if (widget.title != null || widget.userExperience != null)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.title != null) 
                    Flexible(
                      child: Text(
                        widget.title!,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  if (widget.title != null && widget.userExperience != null)
                    const SizedBox(width: 16),
                  // XP Display - Always show for logged in users
                  if (FirebaseAuth.instance.currentUser != null)
                    GestureDetector(
                      onTap: () => _showXPDetails(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              XPSystem.levelIcons[_userLevel] ?? Icons.star,
                              color: AppColors.primaryGreen,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _userLevel,
                                    style: GoogleFonts.inter(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  Text(
                                    '$_userExperience XP',
                                    style: GoogleFonts.inter(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          Row(
            children: [
              // Custom actions
              if (widget.actions != null) ...widget.actions!,
              
              // User authentication buttons
              if (user == null) ...[
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen, // Using AppColors
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 3, 
                  ),
                  child: Text(
                    'Login',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen, // Using AppColors
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 3, 
                  ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: _buildAvatarImage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // User info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isLoading 
                                ? 'Loading...' 
                                : 'Hi, ${_firstName ?? 'User'}',
                            style: GoogleFonts.inter(
                              color: AppColors.primaryGreen, // Using AppColors
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          if (!_isLoading && _username != null)
                            Text(
                              '@$_username',
                              style: GoogleFonts.inter(
                                color: AppColors.primaryGreen.withOpacity(0.7), // Using AppColors
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen, // Using AppColors
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Profile',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed, // Using AppColors
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                  child: Text(
                    'Logout',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.primaryGreen.withOpacity(0.2), // Using AppColors
        ),
      ),
      actions: [
        if (!isWide)
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: AppColors.surfaceLight, // Using AppColors
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.menu,
                color: AppColors.primaryGreen, // Using AppColors
                size: 24,
              ),
              onSelected: (value) {
                // Check current route to prevent duplicate navigation
                final currentRoute = ModalRoute.of(context)?.settings.name;
                
                switch (value) {
                  case 'Plant Hub':
                    if (currentRoute != '/plant-hub') {
                      Navigator.pushNamed(context, '/plant-hub');
                    }
                    break;
                  case 'Community':
                    if (currentRoute != '/social-feed') {
                      Navigator.pushNamed(context, '/social-feed');
                    }
                    break;
                  case 'Ask GAIA':
                    if (currentRoute != '/ai-assistant') {
                      Navigator.pushNamed(context, '/ai-assistant');
                    }
                    break;
                  case 'Plant Shops Map':
                    if (currentRoute != '/plant-shops-map') {
                      Navigator.pushNamed(context, '/plant-shops-map');
                    }
                    break;
                  case 'Profile':
                    if (currentRoute != '/profile') {
                      Navigator.pushNamed(context, '/profile');
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                _buildPopupMenuItem('Plant Hub', Icons.hub),
                _buildPopupMenuItem('Community', Icons.people),
                _buildPopupMenuItem('Ask GAIA', Icons.smart_toy),
                _buildPopupMenuItem('Plant Shops Map', Icons.map),
                _buildPopupMenuItem('Profile', Icons.person),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    // If no avatar URL, show fallback
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      return Container(
        width: 32,
        height: 32,
        color: AppColors.primaryGreen,
        child: Center(
          child: Text(
            _firstName?.isNotEmpty == true ? _firstName![0].toUpperCase() : 'U',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Check if this is a base64 data URL
    if (_avatarUrl!.startsWith('data:image/')) {
      return Image.memory(
        base64Decode(_avatarUrl!.split(',')[1]),
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackAvatar();
        },
      );
    }
    
    // Check if this is a local asset (default avatar)
    if (_isLocalAsset || _avatarUrl!.startsWith('assets/')) {
      return Image.asset(
        _avatarUrl!,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackAvatar();
        },
      );
    }
    
    // Network image - use Firebase Storage SDK
    return FutureBuilder<String>(
      future: _getFirebaseStorageUrl(_avatarUrl!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 32,
            height: 32,
            color: AppColors.primaryGreen.withOpacity(0.3),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildFallbackAvatar();
        }
        
        return Image.network(
          snapshot.data!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackAvatar();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Container(
              width: 32,
              height: 32,
              color: AppColors.primaryGreen.withOpacity(0.3),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 32,
      height: 32,
      color: AppColors.primaryGreen,
      child: Center(
        child: Text(
          _firstName?.isNotEmpty == true ? _firstName![0].toUpperCase() : 'U',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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

  PopupMenuItem<String> _buildPopupMenuItem(String title, IconData icon) {
    return PopupMenuItem(
      value: title,
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryGreen, // Using AppColors
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.textDark, // Using AppColors
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _navLinks(BuildContext context) {
    return [
      _buildNavLink(context, 'Plant Hub', Icons.hub, '/plant-hub', null),
      _buildNavLink(context, 'Community', Icons.people, '/social-feed', null),
      _buildNavLink(context, 'Ask GAIA', Icons.smart_toy, '/ai-assistant', null),
      _buildNavLink(context, 'Plant Shops Map', Icons.map, '/plant-shops-map', null),
    ];
  }

  Widget _buildNavLink(BuildContext context, String title, IconData icon, String? route, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton.icon(
        onPressed: () {
          if (route != null) {
            // Check if we're already on this route to prevent duplicate navigation
            final currentRoute = ModalRoute.of(context)?.settings.name;
            if (currentRoute != route) {
              Navigator.pushNamed(context, route);
            }
          } else if (onTap != null) {
            onTap();
          }
        },
        icon: Icon(
          icon,
          color: AppColors.forestGreen, // Using AppColors
          size: 20, 
        ),
        label: Text(
          title,
          style: GoogleFonts.inter(
            color: AppColors.forestGreen, // Using AppColors
            fontWeight: FontWeight.w600, 
            fontSize: 15, 
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: Colors.transparent, 
        ),
      ),
    );
  }
} 
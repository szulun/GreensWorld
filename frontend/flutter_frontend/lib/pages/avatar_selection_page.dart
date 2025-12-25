import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/theme.dart';

class AvatarSelectionPage extends StatefulWidget {
  const AvatarSelectionPage({super.key});

  @override
  State<AvatarSelectionPage> createState() => _AvatarSelectionPageState();
}

class _AvatarSelectionPageState extends State<AvatarSelectionPage> {
  String? selectedAvatar;
  bool _isLoading = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Header
              Text(
                'Choose Your Avatar',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Select an avatar that represents your plant-loving personality!',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Avatar Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: availableAvatars.length,
                  itemBuilder: (context, index) {
                    final avatar = availableAvatars[index];
                    final isSelected = selectedAvatar == avatar['path'];
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedAvatar = avatar['path'];
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.textDark.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Avatar Image
                            Container(
                              width: 80,
                              height: 80,
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
                            
                            const SizedBox(height: 12),
                            
                            // Avatar Name
                            Text(
                              avatar['name']!,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            
                            const SizedBox(height: 4),
                            
                            // Avatar Description
                            Text(
                              avatar['description']!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMedium,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Selection Indicator
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Selected',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
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
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedAvatar != null && !_isLoading ? _saveAvatar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Skip Button
              TextButton(
                onPressed: !_isLoading ? _skipAvatarSelection : null,
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAvatar() async {
    if (selectedAvatar == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Save the selected avatar to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'avatarUrl': selectedAvatar,
        'profilePicture': selectedAvatar,
        'hasSelectedAvatar': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Navigate to home page
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avatar selected successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save avatar: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _skipAvatarSelection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Mark that user has completed avatar selection (even if skipped)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'hasSelectedAvatar': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Navigate to home page
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to continue: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 
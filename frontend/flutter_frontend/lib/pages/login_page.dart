import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import '../widgets/theme.dart'; // Import the AppColors theme


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late VideoPlayerController _controller;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/images/flow_pond01.mp4')
      ..setLooping(true)
      ..setVolume(0.0)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // New method to save user data to SharedPreferences
  Future<void> _saveUserToSharedPreferences(User user, Map<String, dynamic>? additionalData) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('userId', user.uid);
      await prefs.setString('userEmail', user.email ?? '');
      await prefs.setString('userName', user.displayName ?? additionalData?['username'] ?? '');
      await prefs.setBool('isLoggedIn', true);
      
      // Save additional user data if available
      if (additionalData != null) {
        await prefs.setString('firstName', additionalData['firstName'] ?? '');
        await prefs.setString('lastName', additionalData['lastName'] ?? '');
        await prefs.setString('username', additionalData['username'] ?? '');
      }
      
      print('User data saved to SharedPreferences: ${user.uid} (${user.email})');
    } catch (e) {
      print('Error saving user data to SharedPreferences: $e');
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (emailController.text.isEmpty || passwordController.text.isEmpty) {
        throw 'Email and password cannot be empty.';
      }

      // Sign in with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      if (userCredential.user != null) {
        // Get additional user data from Firestore
        Map<String, dynamic>? userData;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();
          
          if (doc.exists) {
            userData = doc.data();
          }
        } catch (e) {
          print('Error fetching user data from Firestore: $e');
          // Continue without additional data
        }

        // Save user data to SharedPreferences for the map page
        await _saveUserToSharedPreferences(userCredential.user!, userData);

        // Check if user has selected an avatar
        final hasSelectedAvatar = userData?['hasSelectedAvatar'] ?? false;
        if (hasSelectedAvatar) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/avatar-selection', (r) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = e.message ?? 'An unknown authentication error occurred.';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      
      // Check if user data already exists in Firestore
      Map<String, dynamic>? existingUserData;
      
      if (userCredential.user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        
        if (!doc.exists) {
          // Create user data in Firestore for Google Sign-In users
          final displayName = userCredential.user!.displayName ?? '';
          final nameParts = displayName.split(' ');
          final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
          final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          
          final newUserData = {
            'username': userCredential.user!.displayName?.split(' ')[0] ?? 
                       userCredential.user!.email?.split('@')[0] ?? 'User',
            'firstName': firstName,
            'lastName': lastName,
            'email': userCredential.user!.email,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'favoritePlantShops': [], // Initialize empty favorites array
            'hasSelectedAvatar': false, // Mark that user hasn't selected avatar yet
          };

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(newUserData);
          
          existingUserData = newUserData;
        } else {
          existingUserData = doc.data();
        }

        // Save user data to SharedPreferences
        await _saveUserToSharedPreferences(userCredential.user!, existingUserData);
      }

      // Check if user has selected an avatar
      final hasSelectedAvatar = existingUserData?['hasSelectedAvatar'] ?? false;
      if (hasSelectedAvatar) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/avatar-selection', (r) => false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showResetPasswordDialog(String prefillEmail) async {
    final controller = TextEditingController(text: prefillEmail);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Reset Password',
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: TextStyle(color: AppColors.textMedium),
            hintText: 'Enter your email address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primaryGreen),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.surfaceLight,
            ),
            child: Text(
              'Send',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final email = controller.text.trim();
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-redirect if already logged in
    if (FirebaseAuth.instance.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.deepGreen,
        elevation: 0,
        title: Text(
          'Login',
          style: GoogleFonts.inter(
            color: AppColors.surfaceLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.surfaceLight,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Video background
          if (_controller.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          
          // Dark overlay for text readability
          Positioned.fill(
            child: Container(
              color: AppColors.deepGreen.withOpacity(0.6),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textDark.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to continue your journey.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppColors.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Email field
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: AppColors.textMedium),
                        hintText: 'Enter your email',
                        filled: true,
                        fillColor: AppColors.surfaceMedium,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: AppColors.textDark),
                    ),
                    const SizedBox(height: 16),
                    
                    // Password field
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: AppColors.textMedium),
                        hintText: 'Enter your password',
                        filled: true,
                        fillColor: AppColors.surfaceMedium,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: AppColors.textDark),
                    ),
                    // Forgot password button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showResetPasswordDialog(emailController.text),
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.inter(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Login button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.surfaceLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.surfaceLight),
                              )
                            : Text(
                                'Login',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Separator
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppColors.textMedium.withOpacity(0.5),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR',
                            style: GoogleFonts.inter(
                              color: AppColors.textMedium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppColors.textMedium.withOpacity(0.5),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Google Sign-Up button
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => _signInWithGoogle(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: BorderSide(color: AppColors.primaryGreen, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.g_mobiledata, color: AppColors.primaryGreen),
                        label: Text(
                          'Continue with Google',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Sign Up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: GoogleFonts.inter(
                            color: AppColors.textMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/signup'),
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.inter(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
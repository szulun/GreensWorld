import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/theme.dart'; // Import the AppColors theme



class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  late VideoPlayerController _controller;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
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
    usernameController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (emailController.text.isEmpty || passwordController.text.isEmpty) {
        throw 'Email and password cannot be empty.';
      }
      
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      // Save user profile to Firestore
      if (userCredential.user != null) {
        final displayName = nameController.text.trim();
        final nameParts = displayName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        
        final userData = {
          'username': usernameController.text.trim().isNotEmpty 
              ? usernameController.text.trim() 
              : emailController.text.split('@')[0],
          'firstName': firstName,
          'lastName': lastName,
          'email': emailController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'hasSelectedAvatar': false, // Mark that user hasn't selected avatar yet
        };
        
        print('Signup: Creating user document with data: $userData');
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData);
            
        print('Signup: User document created successfully');
      }

      // After successful signup, redirect to avatar selection
      Navigator.pushNamedAndRemoveUntil(context, '/avatar-selection', (r) => false);
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
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
      
      if (userCredential.user != null) {
        // Check if user data already exists in Firestore
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
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'username': userCredential.user!.displayName?.split(' ')[0] ?? 
                       userCredential.user!.email?.split('@')[0] ?? 'User',
            'firstName': firstName,
            'lastName': lastName,
            'email': userCredential.user!.email,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'hasSelectedAvatar': false, // Mark that user hasn't selected avatar yet
          });
        }
      }

      // Redirect to avatar selection for new users
      Navigator.pushNamedAndRemoveUntil(context, '/avatar-selection', (r) => false);
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
          'Sign Up',
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
                      'Welcome to GreensWrld',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join a community of plant lovers and cultivators.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppColors.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Username field
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: AppColors.textMedium),
                        hintText: 'Choose a username',
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
                    
                    // Name field
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: AppColors.textMedium),
                        hintText: 'Enter your name',
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
                    
                    // Sign Up button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          foregroundColor: AppColors.surfaceLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : Text(
                                'Sign Up',
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
                        icon: Icon(
                          Icons.g_mobiledata, // Replaced FaIcon with a Material Icon
                          color: AppColors.primaryGreen,
                        ),
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
                    
                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.inter(
                            color: AppColors.textMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/login'),
                          child: Text(
                            'Login',
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
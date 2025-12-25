import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../widgets/navbar_home.dart';
import '../widgets/answer_card.dart';
import '../widgets/theme.dart';

// Environment configuration
class AppConfig {
  static const String _baseUrlDev = 'http://localhost:3001';
  
  static String get baseUrl {
    const customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) return customUrl;
    return _baseUrlDev;
  }
}

// Enhanced mode enum
enum GaiaMode {
  diagnosis,       // Plant Doctor
  identification,  // Plant ID
  general          // Ask anything
}

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  // Controllers and state
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  List<Uint8List> _images = [];
  List<String> _imageNames = [];
  
  // Response state
  Map<String, dynamic>? _diagnosisResult;
  String _errorMessage = '';
  bool _isLoading = false;
  
  // Current mode
  GaiaMode _currentMode = GaiaMode.diagnosis;

  String? _currentSessionId;
  final List<ChatMessage> _localMessages = [];

  // Smart intent recognition state
  Map<String, dynamic>? _intentAnalysis;
  bool _showIntentOptions = false;
  
  // Welcome animation state
  bool _showWelcomeAnimation = true;
  bool _hasInteracted = false;

  bool get _guestMode {
    final user = FirebaseAuth.instance.currentUser;
    return user == null;
  }

  @override
  void initState() {
    super.initState();
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  // Enhanced image picker
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> picks = await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (picks.isEmpty) return;
      final remain = 3 - _images.length;
      final use = picks.take(remain);
      for (final img in use) {
        final bytes = await img.readAsBytes();
        _images.add(bytes);
        _imageNames.add(img.name);
      }
      setState(() { 
        _errorMessage = '';
        _showIntentOptions = false;
        _intentAnalysis = null;
      });
      
      // Analyze image intent if this is the first image
      if (_images.length == 1) {
        await _analyzeImageIntent();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: ${e.toString()}';
      });
    }
  }

  // Analyze image intent
  Future<void> _analyzeImageIntent() async {
    if (_images.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/api/ai/analyze-intent');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'base64Image': 'data:image/jpeg;base64,${base64Encode(_images.first)}',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _intentAnalysis = decoded;
          _showIntentOptions = true;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to analyze image intent';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to analyze image: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle intent selection
  void _selectIntent(String intentId) {
    switch (intentId) {
      case 'identify':
        _switchMode(GaiaMode.identification);
        break;
      case 'diagnose':
        _switchMode(GaiaMode.diagnosis);
        break;
      case 'general':
        _switchMode(GaiaMode.general);
        break;
    }
    
    setState(() {
      _showIntentOptions = false;
      _intentAnalysis = null;
    });
  }

  // Handle user interaction to hide welcome animation
  void _onUserInteraction() {
    if (!_hasInteracted) {
      setState(() {
        _hasInteracted = true;
        _showWelcomeAnimation = false;
      });
    }
  }

  // Show help tips
  void _showHelpTips() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.help_outline, color: const Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              Text('Quick Help', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Simple 3-step guide
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE9ECEF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🌱 How to use GAIA:',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSimpleStep('1', 'Choose a mode'),
                        _buildSimpleStep('2', 'Upload photo or type question'),
                        _buildSimpleStep('3', 'Get plant care advice!'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // One key tip
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB74D)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb, size: 20, color: const Color(0xFFFF9800)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Clear photos + specific questions = better answers!',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFE65100),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mode descriptions - simplified layout to avoid overflow
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4CAF50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔧 Available Modes:',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCompactHelpModeItem(
                          Icons.medical_services,
                          'Plant Doctor',
                          'Diagnose plant problems and get treatment advice',
                          const Color(0xFF2196F3),
                        ),
                        const SizedBox(height: 8),
                        _buildCompactHelpModeItem(
                          Icons.camera_alt,
                          'Plant ID',
                          'Identify unknown plants and learn care tips',
                          const Color(0xFF9C27B0),
                        ),
                        const SizedBox(height: 8),
                        _buildCompactHelpModeItem(
                          Icons.psychology,
                          'Ask anything',
                          'General gardening questions and advice',
                          const Color(0xFFFF9800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimpleStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHelpModeItem(IconData icon, String title, String description, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textDark,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Main API call
  Future<void> _sendToAIBackend() async {
    // Add debug information
    print('🔍 _sendToAIBackend Debug:');
    print('  - Current Mode: $_currentMode');
    print('  - _descriptionController.text: "${_descriptionController.text}"');
    print('  - _chatController.text: "${_chatController.text}"');
    print('  - Images count: ${_images.length}');
    
    // Additional security check before API call
    final inputText = _descriptionController.text.trim();
    if (inputText.isNotEmpty && _isContentBlocked(inputText)) {
      print('🚫 API call blocked: Input contains blocked content');
      setState(() {
        _errorMessage = 'Security check failed: Content not allowed.';
      });
      return;
    }
    
    if (_currentMode == GaiaMode.diagnosis) {
      if (_images.isEmpty && inputText.isEmpty) {
        setState(() {
          _errorMessage = 'Please provide a description or upload an image of your plant.';
        });
        return;
      }
    } else if (_currentMode == GaiaMode.identification) {
      if (inputText.isEmpty && _images.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a plant name/keywords or upload an image to identify.';
        });
        return;
      }
    } else if (_currentMode == GaiaMode.general) {
      // Ask anything mode: check if there's text or image
      if (_images.isEmpty && inputText.isEmpty) {
        print('  ❌ Ask anything mode validation failed: no text or image');
        setState(() {
          _errorMessage = 'Please type a question or upload an image.';
        });
        return;
      }
      
      // Additional security check for Ask anything mode
      if (inputText.isNotEmpty) {
        // Simple validation: just check if it's not completely empty or too short
        if (inputText.trim().length < 3) {
          print('  ⚠️ Question too short: $inputText');
          setState(() {
            _errorMessage = 'Please ask a more specific question.';
          });
          return;
        }
        
        // Let the AI backend decide if the question is appropriate
        // We only do basic security checks here, not content validation
        print('  ✅ Ask anything mode validation passed - letting AI judge content');
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _diagnosisResult = null;
    });

    try {
      String endpoint;
      Map<String, dynamic> requestBody = {};
      
      if (_currentMode == GaiaMode.identification) {
        if (_images.isNotEmpty) {
          endpoint = '/api/ai/photo';
          requestBody['base64Image'] = 'data:image/jpeg;base64,${base64Encode(_images.first)}';
        } else {
          endpoint = '/api/ai/keyword';
          requestBody['keyword'] = _descriptionController.text.trim();
        }
      } else if (_currentMode == GaiaMode.diagnosis) {
        endpoint = '/api/ai/diagnose';
        
        if (_descriptionController.text.trim().isNotEmpty) {
          requestBody['description'] = _descriptionController.text.trim();
        }
        
        if (_images.isNotEmpty) {
          requestBody['base64Image'] = 'data:image/jpeg;base64,${base64Encode(_images.first)}';
        }
      } else {
        // Ask anything mode - use Gemini or other AI service
        endpoint = '/api/ai/general-chat'; // Changed to more explicit endpoint name
        
        // Build request body, including user's question and context
        if (_images.isNotEmpty && _descriptionController.text.trim().isNotEmpty) {
          // Both image and text
          requestBody = {
            'message': _descriptionController.text.trim(),
            'base64Image': 'data:image/jpeg;base64,${base64Encode(_images.first)}',
            'mode': 'general_chat',
            'hasImage': true,
            'hasText': true,
          };
        } else if (_images.isNotEmpty) {
          // Image only
          requestBody = {
            'message': 'Please analyze this image and provide helpful information.',
            'base64Image': 'data:image/jpeg;base64,${base64Encode(_images.first)}',
            'mode': 'general_chat',
            'hasImage': true,
            'hasText': false,
          };
        } else {
          // Text only
          requestBody = {
            'message': _descriptionController.text.trim(),
            'mode': 'general_chat',
            'hasImage': false,
            'hasText': true,
          };
        }
      }
      
      final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        Map<String, dynamic> transformedResult;
        
        if (_currentMode == GaiaMode.identification) {
          // Check if backend already returns the correct format
          if (decoded.containsKey('plantInfo') && decoded.containsKey('careInstructions')) {
            // Backend already returns the correct format, use it directly
            transformedResult = decoded;
            print('✅ Backend returned correct format, using directly');
          } else {
            // Backend returns old format, transform it
            transformedResult = _transformCareTipsResponse(decoded);
            print('🔄 Backend returned old format, transforming...');
          }
        } else if (_currentMode == GaiaMode.diagnosis) {
          transformedResult = decoded;
        } else {
          transformedResult = decoded is Map<String, dynamic> ? decoded : {'text': decoded.toString()};
        }
        
          setState(() {
          _diagnosisResult = transformedResult;
        });
      } else {
        String errorMsg;
        switch (response.statusCode) {
          case 400:
            errorMsg = 'Invalid request. Please check your input and try again.';
            break;
          case 404:
            errorMsg = 'API endpoint not found. The backend service may not be running or the endpoint is incorrect. Please check if your backend server is running on ${AppConfig.baseUrl}';
            break;
          case 429:
            errorMsg = 'Too many requests. Please wait a moment and try again.';
            break;
          case 500:
            errorMsg = 'Server error. Please try again later.';
            break;
          default:
            errorMsg = 'Unexpected error (${response.statusCode}). Please try again.';
        }
        setState(() {
          _errorMessage = errorMsg;
        });
        
        // Add debug information
        print('❌ API Error: ${response.statusCode}');
        print('  - Endpoint: $endpoint');
        print('  - Base URL: ${AppConfig.baseUrl}');
        print('  - Full URL: ${uri.toString()}');
        print('  - Response body: ${response.body}');
        
        // If it's a 404 error and it's Ask anything mode, provide useful error information
        if (response.statusCode == 404 && _currentMode == GaiaMode.general) {
          print('❌ Ask anything endpoint not found: ${AppConfig.baseUrl}/api/ai/general-chat');
          setState(() {
            _errorMessage = 'Ask anything mode is not available. Please ensure your backend has the /api/ai/general-chat endpoint configured with Gemini or another AI service.';
          });
        }
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('TimeoutException')) {
          _errorMessage = 'Request timed out. Please check your connection and try again.';
        } else if (e.toString().contains('SocketException')) {
          _errorMessage = 'Cannot connect to server. Please check your internet connection.';
        } else {
          _errorMessage = 'Something went wrong. Please try again later.';
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Generate offline response for Ask anything mode when API is unavailable
  String _generateOfflineResponse(String userQuestion) {
    final lowerQuestion = userQuestion.toLowerCase();
    
    // Simple offline responses based on common gardening questions
    if (lowerQuestion.contains('water')) {
      return 'For watering plants, the general rule is to water when the top inch of soil feels dry. Most plants prefer thorough watering followed by allowing the soil to dry out slightly. Overwatering is a common mistake - it\'s better to underwater than overwater. Check your plant\'s specific needs as some plants like succulents need very little water, while others like ferns prefer consistently moist soil.';
    } else if (lowerQuestion.contains('sunlight') || lowerQuestion.contains('light')) {
      return 'Sunlight requirements vary by plant type. Most houseplants prefer bright, indirect light near a window. Full sun plants need 6+ hours of direct sunlight daily. Shade plants thrive with minimal direct light. Signs of too much sun include scorched leaves, while too little sun results in leggy growth and pale leaves. Rotate your plants regularly for even growth.';
    } else if (lowerQuestion.contains('fertiliz')) {
      return 'Fertilizing provides essential nutrients for plant growth. Use a balanced fertilizer (like 10-10-10) during the growing season (spring and summer). Most plants benefit from monthly feeding. Reduce or stop fertilizing in fall and winter when growth slows. Always follow package instructions and never over-fertilize, as this can burn roots and damage plants.';
    } else if (lowerQuestion.contains('soil')) {
      return 'Good soil is crucial for plant health. Most plants prefer well-draining soil rich in organic matter. You can improve soil by adding compost, perlite, or vermiculite. Different plants have different soil needs - succulents need sandy, well-draining soil, while tropical plants prefer rich, moisture-retaining soil. Consider repotting when roots become crowded.';
    } else if (lowerQuestion.contains('pest')) {
      return 'Common plant pests include aphids, spider mites, and mealybugs. Early detection is key - check plants regularly for signs of infestation. Natural remedies include neem oil, insecticidal soap, or a strong water spray. Isolate affected plants to prevent spread. Maintain good plant health as healthy plants are more resistant to pests.';
    } else if (lowerQuestion.contains('disease')) {
      return 'Plant diseases often result from poor growing conditions. Common issues include root rot (from overwatering), powdery mildew (from poor air circulation), and leaf spots. Prevention is best: ensure proper watering, good air flow, and clean growing conditions. Remove affected leaves and avoid overhead watering.';
    } else if (lowerQuestion.contains('prune')) {
      return 'Pruning helps maintain plant shape and health. Remove dead, damaged, or diseased growth. For flowering plants, prune after blooming. Use clean, sharp tools and make clean cuts. Don\'t remove more than 1/3 of the plant at once. Regular light pruning is better than occasional heavy pruning.';
    } else if (lowerQuestion.contains('repot')) {
      return 'Repot when roots become crowded or plants outgrow their containers. Signs include roots growing through drainage holes or plants becoming top-heavy. Choose a pot only slightly larger than the current one. Use fresh, appropriate soil mix. Spring is usually the best time to repot, when plants are actively growing.';
    } else {
      return 'I\'m sorry, but I\'m currently unable to connect to my full knowledge base. However, I can help with basic plant care questions! Try asking about watering, sunlight, fertilizing, soil, pests, diseases, pruning, or repotting. For more detailed or specific advice, please check back later when the connection is restored.';
    }
  }

  // Transform care tips response
  Map<String, dynamic> _transformCareTipsResponse(Map<String, dynamic> response) {
    // Debug: Print the raw response to see what we're working with
    print('🔍 _transformCareTipsResponse Debug:');
    print('  - Raw response: $response');
    print('  - Response keys: ${response.keys.toList()}');
    
    // Handle both old and new response formats
    final plantName = response['plantName'] as String? ?? response['commonName'] as String? ?? 'Unknown Plant';
    final scientificName = response['scientificName'] as String? ?? 'Unknown';
    
    String displayName = plantName;
    if (displayName == 'Unknown Plant' && _chatController.text.trim().isNotEmpty) {
      displayName = _chatController.text.trim();
    }
    
    // Ensure scientific name is not empty or "Unknown"
    final validScientificName = (scientificName.isNotEmpty && 
                                scientificName != 'Unknown' && 
                                scientificName != 'Unknown Plant') 
                                ? scientificName : null;
    
    print('  - Plant name: $plantName');
    print('  - Scientific name: $scientificName');
    print('  - Display name: $displayName');
    
    Map<String, dynamic> careInstructions = {};
    List<String> recommendations = [];
    
    final careTips = response['careTips'] as List? ?? [];
    print('  - Care tips count: ${careTips.length}');
    
    for (var tip in careTips) {
      if (tip is Map<String, dynamic>) {
        final topic = (tip['topic'] as String? ?? '').toLowerCase();
        final description = tip['description'] as String? ?? '';
        
        print('  - Processing tip: $topic -> ${description.length} chars');
        
        // Map topics to careInstructions keys
        if (topic.contains('watering') || topic.contains('water')) {
          careInstructions['watering'] = description;
        } else if (topic.contains('sunlight') || topic.contains('light') || topic.contains('sun')) {
          careInstructions['light'] = description;
        } else if (topic.contains('soil')) {
          careInstructions['soil'] = description;
        } else if (topic.contains('temperature') || topic.contains('temp')) {
          careInstructions['temperature'] = description;
        } else if (topic.contains('fertiliz') || topic.contains('fertilizer')) {
          careInstructions['fertilizing'] = description;
        } else if (topic.contains('humidity')) {
          careInstructions['humidity'] = description;
        } else {
          // For any other topics, add to recommendations
          recommendations.add('${tip['topic']}: $description');
        }
      }
    }
    
    print('  - Care instructions keys: ${careInstructions.keys.toList()}');
    print('  - Recommendations count: ${recommendations.length}');
    
    return {
      'plantInfo': {
        'name': displayName,
        'scientificName': validScientificName,
      },
      'careInstructions': careInstructions,
      'recommendations': recommendations,
    };
  }

  // Clear all inputs and results
  void _clearAll() {
    setState(() {
      _descriptionController.clear();
      _chatController.clear();
      _images = [];
      _imageNames = [];
      _diagnosisResult = null;
      _errorMessage = '';
    });
  }

  Future<void> _ensureSessionIfNeeded() async {
    if (_currentSessionId != null) return;
    if (_guestMode) {
      setState(() => _currentSessionId = 'local');
    } else {
      try {
        String title;
        if (_currentMode == GaiaMode.diagnosis) {
          title = 'Plant Doctor';
        } else if (_currentMode == GaiaMode.identification) {
          title = 'Plant ID';
        } else {
          title = 'Ask anything';
        }
        
        // If there's text content, include it in the title
        final text = _chatController.text.trim();
        if (text.isNotEmpty) {
          final shortText = text.length > 20 ? '${text.substring(0, 20)}...' : text;
          title = '$title: $shortText';
        }
        
        final id = await ChatService.ensureSession(title: title);
        setState(() => _currentSessionId = id);
      } catch (e) {
        setState(() => _currentSessionId = 'local');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Firestore unavailable, using local session')), 
          );
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim(); // Use trim() to remove line breaks and spaces
    
    // Security check: Block inappropriate content
    if (text.isNotEmpty && _isContentBlocked(text)) {
      setState(() {
        _errorMessage = 'Your message contains inappropriate content and cannot be processed. Please ensure your question is related to plant care and gardening.';
      });
      
      // Log the blocked attempt
      print('🚫 Blocked message attempt: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');
      
      // Show warning to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Message blocked: Contains inappropriate content'),
            backgroundColor: AppColors.errorRed,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    
    // Sanitize input text
    final sanitizedText = _sanitizeInput(text);
    
    if (sanitizedText.isEmpty && _images.isEmpty) {
      setState(() => _errorMessage = 'Type a message or add an image.');
      return;
    }
    
    // Hide welcome animation when user starts chatting
    _onUserInteraction();
    
    await _ensureSessionIfNeeded();
    if (_currentSessionId == null) return;

    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      // Save text message first to avoid lag due to upload or analysis delay
      _localMessages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: _currentSessionId!,
        role: 'user',
        content: sanitizedText, // Use sanitized text
        images: _images.map((img) => 'data:image/jpeg;base64,${base64Encode(img)}').toList(),
        mode: _currentMode == GaiaMode.diagnosis ? 'doctor' : _currentMode == GaiaMode.identification ? 'id' : 'general',
        createdAt: DateTime.now(),
      ));
      setState(() {});
      if (!_guestMode) {
        try {
          await ChatService.addMessage(
            sessionId: _currentSessionId!,
            role: 'user',
            content: sanitizedText, // Use sanitized text
            images: _images.map((img) => 'data:image/jpeg;base64,${base64Encode(img)}').toList(),
            mode: _currentMode == GaiaMode.diagnosis
                ? 'doctor'
                : _currentMode == GaiaMode.identification
                    ? 'id'
                    : 'general',
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Save to history failed (user): $e')),
            );
          }
        }
      }

      // Set _descriptionController before calling API to ensure Ask anything mode works properly
      // Use trim() to ensure no line breaks
      _descriptionController.text = sanitizedText.trim(); // Use sanitized text
      await _sendToAIBackend();

      final reply = _diagnosisResult != null
          ? jsonEncode(_diagnosisResult)
          : (_errorMessage.isNotEmpty ? _errorMessage : '');
      
      _localMessages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: _currentSessionId!,
        role: 'assistant',
        content: reply,
        images: const [],
        mode: _currentMode == GaiaMode.diagnosis ? 'doctor' : _currentMode == GaiaMode.identification ? 'id' : 'general',
        createdAt: DateTime.now(),
      ));
      setState(() {});
      if (!_guestMode) {
        try {
          await ChatService.addMessage(
            sessionId: _currentSessionId!,
            role: 'assistant',
            content: reply,
            images: const [],
            mode: _currentMode == GaiaMode.diagnosis
                ? 'doctor'
                : _currentMode == GaiaMode.identification
                    ? 'id'
                    : 'general',
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Save to history failed (assistant): $e')),
            );
          }
        }
      }

      // Clear input box after sending message to allow new questions
      _chatController.clear();
      
      final picked = List<Uint8List>.from(_images);
      final names = List<String>.from(_imageNames);
      setState(() { _images = []; _imageNames = []; });
      if (!_guestMode && picked.isNotEmpty && _currentSessionId != null) {
        for (var i = 0; i < picked.length; i++) {
          final b = picked[i];
          final n = (i < names.length ? names[i] : 'image_$i.jpg');
          ChatService
              .uploadImage(b, fileName: n)
              .timeout(const Duration(seconds: 10))
              .then((url) => ChatService.addMessage(
                    sessionId: _currentSessionId!,
                    role: 'user',
                    content: '[image]',
                    images: [url],
                    mode: _currentMode == GaiaMode.diagnosis
                        ? 'doctor'
                        : _currentMode == GaiaMode.identification
                            ? 'id'
                            : 'general',
                  ))
              .catchError((e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image upload failed: $e'))); } });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Debug: Print user information
    print('🔍 User Debug:');
    print('  - User: $user');
    print('  - displayName: ${user?.displayName}');
    print('  - email: ${user?.email}');
    print('  - uid: ${user?.uid}');
    print('  - displayName is empty: ${user?.displayName?.trim().isEmpty}');
    print('  - displayName is null: ${user?.displayName == null}');
    
    // Fix: Better name logic - prioritize displayName, then email first part
    String name;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      name = user.displayName!.trim();
      print('  ✅ Using displayName: $name');
    } else if (user?.email != null) {
      // Extract first part of email (before @)
      name = user!.email!.split('@')[0];
      print('  📧 Using email first part: $name');
    } else {
      name = 'there';
      print('  👤 Using default name: $name');
    }
    
    print('  - Final name: $name');

    return Scaffold(
      appBar: const NavbarHome(),
      body: LayoutBuilder(
        builder: (ctx, c) {
          final wide = c.maxWidth > 980;
          final main = _buildMainChat(name, wide);
          if (!wide) return main;
          return Row(
            children: [
              SizedBox(width: 280, child: _buildSidebar()),
              const VerticalDivider(width: 1),
              Expanded(child: main),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    if (_guestMode) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.account_circle,
                  size: 48,
                  color: AppColors.surfaceLight,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please Sign In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to access chat history',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // User status indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person,
                color: Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed in as:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                setState(() {
                  _currentSessionId = null;
                  _localMessages.clear();
                  _diagnosisResult = null;
                  _errorMessage = '';
                  _images.clear();
                  _imageNames.clear();
                  _chatController.clear();
                  _descriptionController.clear();
                });
                
                if (!_guestMode) {
                  try {
                final id = await ChatService.ensureSession(title: 'New chat');
                setState(() => _currentSessionId = id);
                  } catch (e) {
                    setState(() => _currentSessionId = 'local');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create new session: $e')),
                      );
                    }
                  }
                } else {
                  setState(() => _currentSessionId = 'local');
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New chat'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatSession>>(
            stream: ChatService.sessionsStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Loading chats...'),
                    ],
                  ),
                );
              }
              
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.surfaceLight),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load chats',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              
              final sessions = snap.data ?? const [];
              
              if (sessions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.surfaceLight),
                      const SizedBox(height: 8),
                      const Text('No chats yet'),
                      const SizedBox(height: 4),
                      const Text(
                        'Start a conversation to see it here',
                        style: TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, i) {
                  final s = sessions[i];
                  final selected = s.id == _currentSessionId;
                  return ListTile(
                    selected: selected,
                    title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      s.updatedAt.toLocal().toString().substring(0, 16),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      setState(() {
                        _currentSessionId = s.id;
                        _diagnosisResult = null;
                        _errorMessage = '';
                        _images.clear();
                        _imageNames.clear();
                        _chatController.clear();
                        _descriptionController.clear();
                        _localMessages.clear();
                      });
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ChatService.deleteSession(s.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainChat(String name, bool wide) {
    final hasSession = _currentSessionId != null;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceCream, AppColors.surfaceLight],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: hasSession
                ? (_guestMode
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _localMessages.length + (_showIntentOptions ? 1 : 0),
                        itemBuilder: (context, i) {
                          // Show intent options as the first item if available
                          if (_showIntentOptions && i == 0) {
                            return _buildIntentOptions();
                          }
                          
                          // Adjust index for messages
                          final messageIndex = _showIntentOptions ? i - 1 : i;
                          final m = _localMessages[messageIndex];
                          final isUser = m.role == 'user';
                          final raw = m.content.trim();
                          
                          Widget bubbleChild;
                                                        if (isUser) {
                                // User message: Display text and images
                            bubbleChild = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (raw.isNotEmpty)
                                  SelectableText(raw, style: const TextStyle(color: AppColors.textLight)),
                                if (m.images.isNotEmpty) ...[
                                  if (raw.isNotEmpty) const SizedBox(height: 8),
                                  ...m.images.map((imageUrl) => 
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: imageUrl.startsWith('http')
                                            ? Image.network(
                                                imageUrl,
                                                height: 120,
                                                width: 120,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    Container(
                                                      height: 120,
                                                      width: 120,
                                                      color: AppColors.surfaceLight,
                                                      child: const Icon(Icons.image_not_supported, color: AppColors.textLight),
                                                    ),
                                              )
                                            : Image.memory(
                                                base64Decode(imageUrl.split(',')[1]),
                                                height: 120,
                                                width: 120,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          } else {
                            // 助手消息：根據消息的原始模式來顯示
                            final raw = m.content.trim();
                            Widget responseWidget;
                            
                            try {
                              // Try to parse JSON content
                              if (raw.startsWith('{') && raw.endsWith('}')) {
                                final data = jsonDecode(raw) as Map<String, dynamic>;
                                // 根據消息的原始模式來顯示
                                if (m.mode == 'doctor') {
                                  responseWidget = _buildDiagnosisResponse(data);
                                } else if (m.mode == 'id') {
                                  responseWidget = _buildPlantInfoResponse(data);
                                } else {
                                  // Find the user question from previous messages
                                  String userQuestion = "";
                                  for (int j = messageIndex - 1; j >= 0; j--) {
                                    if (j < _localMessages.length && _localMessages[j].role == 'user') {
                                      userQuestion = _localMessages[j].content.trim();
                                      break;
                                    }
                                  }
                                  responseWidget = _buildGeneralResponse(data, userQuestion: userQuestion);
                                }
                              } else {
                                // If not JSON, display text directly
                                responseWidget = SelectableText(raw, style: const TextStyle(color: Colors.black87));
                              }
                            } catch (e) {
                              // If parsing fails, display text directly
                              responseWidget = SelectableText(raw, style: const TextStyle(color: Colors.black87));
                            }
                            
                            bubbleChild = responseWidget;
                          }
                          
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              constraints: const BoxConstraints(maxWidth: 720),
                              decoration: BoxDecoration(
                                color: isUser ? AppColors.forestGreen : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: isUser ? null : Border.all(
                                  color: AppColors.surfaceLight,
                                  width: 1,
                                ),
                              ),
                              child: bubbleChild,
                            ),
                          );
                        },
                      )
                    : StreamBuilder<List<ChatMessage>>(
                        stream: ChatService.messagesStream(_currentSessionId!),
                    builder: (context, snap) {
                      final msgs = snap.data ?? const [];
                          final list = msgs.isNotEmpty ? msgs : _localMessages;
                          if (list.isEmpty) {
                            // If no messages, show welcome page but maintain session state
                            return _buildHero(name);
                          }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length + (_showIntentOptions ? 1 : 0),
                        itemBuilder: (context, i) {
                          // Show intent options as the first item if available
                          if (_showIntentOptions && i == 0) {
                            return _buildIntentOptions();
                          }
                          
                          // Adjust index for messages
                          final messageIndex = _showIntentOptions ? i - 1 : i;
                          final m = list[messageIndex];
                          final isUser = m.role == 'user';
                              
                          Widget bubbleChild;
                              if (isUser) {
                                // User message: Display text and images
                            final raw = m.content.trim();
                                bubbleChild = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (raw.isNotEmpty && raw != '[image]')
                                      SelectableText(raw, style: const TextStyle(color: Colors.white)),
                                    if (m.images.isNotEmpty) ...[
                                      if (raw.isNotEmpty && raw != '[image]') const SizedBox(height: 8),
                                      ...m.images.map((imageUrl) => 
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: imageUrl.startsWith('http')
                                                ? Image.network(
                                                    imageUrl,
                                                    height: 120,
                                                    width: 120,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        Container(
                                                          height: 120,
                                                          width: 120,
                                                          color: AppColors.surfaceLight,
                                                          child: const Icon(Icons.image_not_supported, color: AppColors.textLight),
                                                        ),
                                                      )
                                                : Image.memory(
                                                    base64Decode(imageUrl.split(',')[1]),
                                                    height: 120,
                                                    width: 120,
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                            } else {
                                // Assistant message: Display based on message's original mode
                                final raw = m.content.trim();
                                Widget responseWidget;
                                
                                try {
                                  // Try to parse JSON content
                                  if (raw.startsWith('{') && raw.endsWith('}')) {
                                    final data = jsonDecode(raw) as Map<String, dynamic>;
                                    // Display based on message's original mode
                                    if (m.mode == 'doctor') {
                                      responseWidget = _buildDiagnosisResponse(data);
                                    } else if (m.mode == 'id') {
                                      responseWidget = _buildPlantInfoResponse(data);
                                    } else {
                                      // Find the user question from previous messages
                                      String userQuestion = "";
                                      for (int j = messageIndex - 1; j >= 0; j--) {
                                        if (j < list.length && list[j].role == 'user') {
                                          userQuestion = list[j].content.trim();
                                          break;
                                        }
                                      }
                                      responseWidget = _buildGeneralResponse(data, userQuestion: userQuestion);
                            }
                          } else {
                                    // If not JSON, display text directly
                                    responseWidget = SelectableText(raw, style: const TextStyle(color: AppColors.textDark));
                                  }
                                } catch (e) {
                                  // If parsing fails, display text directly
                                  responseWidget = SelectableText(raw, style: const TextStyle(color: AppColors.textDark));
                                }
                                
                                bubbleChild = responseWidget;
                              }
                              
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              constraints: const BoxConstraints(maxWidth: 720),
                              decoration: BoxDecoration(
                                color: isUser ? AppColors.forestGreen : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: isUser ? null : Border.all(
                                  color: AppColors.surfaceLight,
                                  width: 1,
                                ),
                              ),
                              child: bubbleChild,
                            ),
                          );
                        },
                      );
                    },
                  ))
                : _buildHero(name),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildHero(String name) {
    final hasSession = _currentSessionId != null;
    
    return Container(
      decoration: _currentMode == GaiaMode.general
          ? const BoxDecoration(color: Colors.white)
          : const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceCream, AppColors.surfaceCream],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28), // Reduced from 40 to 28 to make page more compact
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                      // Fun Welcome Animation
                      if (_showWelcomeAnimation && !hasSession) ...[
                        // Simplified welcome content - removed caterpillar animation to make page cleaner
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1200),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(value * 0.1)
                                ..rotateX(value * 0.05),
                              child: Transform.scale(
                                scale: 0.7 + (0.3 * Curves.elasticOut.transform(value)),
                                child: Opacity(
                                  opacity: value,
                                  child: Column(
                                    children: [
                                      // Bouncing plant icon - keep logo size, no spacing with title
                                      TweenAnimationBuilder<double>(
                                        duration: const Duration(milliseconds: 2000),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        builder: (context, bounceValue, child) {
                                          return Transform.translate(
                                            offset: Offset(0, -5 * Curves.elasticOut.transform(bounceValue)),
                                            child: const RotatingLogo(
                                              size: 280, // Keep logo size
                                            ),
                                          );
                                        },
                                      ),
                                      // Remove spacing to keep logo and title close together
                                      const SizedBox(height: 6), // Keep spacing between title and subtitle
                                      // Typing effect for title
                                      _buildTypingText(
                                        'Welcome to GAIA! 🌱',
                                        style: GoogleFonts.inter(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 6), // 標題和副標題的間距保持
                                      // Fade in subtitle
                                      TweenAnimationBuilder<double>(
                                        duration: const Duration(milliseconds: 800),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        builder: (context, fadeValue, child) {
                                          return Opacity(
                                            opacity: fadeValue,
                                            child: Transform.translate(
                                              offset: Offset(0, 20 * (1 - fadeValue)),
                                              child: Text(
                                                'Your AI Plant Assistant',
                                                style: GoogleFonts.inter(
                                                  fontSize: 18,
                                                  color: AppColors.textMedium,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24), // Keep overall spacing
                      ],
                      
                Text(
                  hasSession 
                      ? 'Continue your conversation with $name' 
                      : 'Hello, $name. What will you do today?', 
                  style: GoogleFonts.inter(fontSize: 18, color: AppColors.textMedium)
                ),
                      const SizedBox(height: 16), // Reduced from 18 to 16, reduce spacing
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.medical_services, size: 20, color: _currentMode == GaiaMode.diagnosis ? AppColors.surfaceLight : AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Plant Doctor'),
                        ],
                      ),
                      selected: _currentMode == GaiaMode.diagnosis,
                            onSelected: (_) {
                              _onUserInteraction();
                              _switchMode(GaiaMode.diagnosis);
                            },
                    ),
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, size: 20, color: _currentMode == GaiaMode.identification ? AppColors.surfaceLight : AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Plant ID'),
                        ],
                      ),
                      selected: _currentMode == GaiaMode.identification,
                            onSelected: (_) {
                              _onUserInteraction();
                              _switchMode(GaiaMode.identification);
                            },
                    ),
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.psychology, size: 20, color: _currentMode == GaiaMode.general ? AppColors.surfaceLight : AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Ask anything'),
                        ],
                      ),
                      selected: _currentMode == GaiaMode.general,
                            onSelected: (_) {
                              _onUserInteraction();
                              _switchMode(GaiaMode.general);
                            },
                    ),
                  ],
                ),
                      
                      // Mode descriptions - removed detailed explanations to make main page cleaner
                      // const SizedBox(height: 16),
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildModeDescription(
                      //         Icons.medical_services,
                      //         'Plant Doctor',
                      //         'Diagnose plant problems and get treatment advice',
                      //         _currentMode == GaiaMode.diagnosis,
                      //       ),
                      //     ),
                      //     const SizedBox(width: 12),
                      //     Expanded(
                      //       child: _buildModeDescription(
                      //         Icons.camera_alt,
                      //         'Plant ID',
                      //         'Identify unknown plants and learn care tips',
                      //         _currentMode == GaiaMode.identification,
                      //       ),
                      //     ),
                      //     const SizedBox(width: 12),
                      //     Expanded(
                      //       child: _buildModeDescription(
                      //         Icons.psychology,
                      //         'Ask anything',
                      //         'General gardening questions and advice',
                      //         _currentMode == GaiaMode.general,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      
                      // Quick Start Tips with slide animation - completely removed
                      // if (_showWelcomeAnimation && !hasSession) ...[
                      //   const SizedBox(height: 32),
                      //   TweenAnimationBuilder<double>(
                      //     duration: const Duration(milliseconds: 1000),
                      //     tween: Tween(begin: 0.0, end: 1.0),
                      //     builder: (context, slideValue, child) {
                      //       return Transform.translate(
                      //         offset: Offset(100 * (1 - slideValue), 0),
                      //         child: Opacity(
                      //           opacity: slideValue,
                      //           child: Container(
                      //             padding: const EdgeInsets.all(20),
                      //             decoration: BoxDecoration(
                      //               color: Colors.blue.shade50,
                      //               borderRadius: BorderRadius.circular(16),
                      //               border: Border.all(color: Colors.blue.shade200),
                      //             ),
                      //             child: Column(
                      //               children: [
                      //                 Row(
                      //                   children: [
                      //                     // Spinning lightbulb
                      //                     TweenAnimationBuilder<double>(
                      //                       duration: const Duration(milliseconds: 3000),
                      //                       tween: Tween(begin: 0.0, end: 1.0),
                      //                       builder: (context, spinValue, child) {
                      //                         return Transform.rotate(
                      //                           angle: spinValue * 2 * 3.14159,
                      //                           child: Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 24),
                      //                         );
                      //                       },
                      //                     ),
                      //                     const SizedBox(width: 12),
                      //                     Text(
                      //                       'Quick Start: Choose a mode to get started!',
                      //                       style: GoogleFonts.inter(
                      //                         fontSize: 18,
                      //                         fontWeight: FontWeight.w600,
                      //                         color: Colors.blue.shade700,
                      //                       ),
                      //                     ),
                      //                   ],
                      //                 ),
                      //                 const SizedBox(height: 12),
                      //                 Text(
                      //                   'Choose a mode to get started!',
                      //                   style: GoogleFonts.inter(
                      //                     fontSize: 14,
                      //                     color: Colors.blue.shade700,
                      //                   ),
                      //                   textAlign: TextAlign.center,
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ),
                      //       );
                      //     },
                      //   ),
                      //   const SizedBox(height: 32),
                      // ],
              ],
            ),
          ),
        ),
            ),
          ),
          
          // Help Button (Top Right) with pulse animation
          Positioned(
            top: 20,
            right: 20,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 2000),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, pulseValue, child) {
                return Transform.scale(
                  scale: 1.0 + (0.1 * Curves.easeInOut.transform(pulseValue)),
                  child: FloatingActionButton(
                    heroTag: 'help',
                    onPressed: _showHelpTips,
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: AppColors.surfaceLight,
                    mini: true,
                    child: const Icon(Icons.help_outline),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      );
    }

  // Floating action buttons with wave effect
  Widget _buildFloatingActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 800 + (index * 200)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: FloatingActionButton(
                    heroTag: 'floating_$index',
                    onPressed: () {},
                    backgroundColor: AppColors.surfaceLight,
                    foregroundColor: AppColors.successGreen,
                    mini: true,
                    child: Icon([
                      Icons.medical_services,
                      Icons.camera_alt,
                      Icons.psychology,
                    ][index]),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // Typing text effect
  Widget _buildTypingText(String text, {required TextStyle style}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: text.length * 100),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        final endIndex = (value * text.length).round();
        final displayText = text.substring(0, endIndex);
        
        return RichText(
          text: TextSpan(
            text: displayText,
            style: style,
            children: [
              if (value < 1.0)
                TextSpan(
                  text: '|',
                  style: style.copyWith(
                    color: Colors.transparent,
                    backgroundColor: AppColors.accentGreen,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border(top: BorderSide(color: AppColors.surfaceLight)),
                        ),
                child: Column(
          mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                    children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Type your question or drop an image…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Help & Tips',
                  icon: const Icon(Icons.help_outline),
                  onPressed: _showHelpTips,
                ),
                IconButton(
                  tooltip: 'Add image',
                  icon: const Icon(Icons.image_outlined),
                  onPressed: _pickImage,
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surfaceLight)) : const Icon(Icons.send),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.forestGreen, foregroundColor: AppColors.surfaceLight),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_images.isNotEmpty)
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => Stack(
                  children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_images[i], height: 70, width: 70, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () { setState(() { _images.removeAt(i); _imageNames.removeAt(i); }); },
                          child: Container(
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      )
                  ],
                ),
              ),
              ),
            const SizedBox(height: 6),
            // Smart mode selection for multiple images or changing intentions
            if (_images.isNotEmpty || _localMessages.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, size: 16, color: AppColors.textLight),
                        const SizedBox(width: 8),
                        Text(
                          'Mode for this message:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medical_services, size: 16, color: _currentMode == GaiaMode.diagnosis ? Colors.white : AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      const Text('Plant Doctor'),
                    ],
                  ),
                  selected: _currentMode == GaiaMode.diagnosis,
                  onSelected: (_) => _switchMode(GaiaMode.diagnosis),
                ),
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, size: 16, color: _currentMode == GaiaMode.identification ? Colors.white : AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      const Text('Plant ID'),
                    ],
                  ),
                  selected: _currentMode == GaiaMode.identification,
                  onSelected: (_) => _switchMode(GaiaMode.identification),
                ),
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology, size: 16, color: _currentMode == GaiaMode.general ? Colors.white : AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      const Text('Ask anything'),
                    ],
                  ),
                  selected: _currentMode == GaiaMode.general,
                  onSelected: (_) => _switchMode(GaiaMode.general),
                ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Image info display
            if (_images.isNotEmpty)
              Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentGreen),
                    ),
                      child: Row(
                      mainAxisSize: MainAxisSize.min,
                        children: [
                        const Icon(Icons.image, size: 16, color: AppColors.primaryGreen),
                        const SizedBox(width: 6),
                        Text(_imageNames.isNotEmpty ? _imageNames.first : 'image', style: const TextStyle(color: AppColors.primaryGreen)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() { _images = []; _imageNames = []; }),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralResponse(Map<String, dynamic> data, {String? userQuestion}) {
    final text = data['text']?.toString() ?? '';
    
    // Clean up Markdown symbols and formatting
    String cleanText = text
        .replaceAll('**', '') // Remove bold markers
        .replaceAll('*', '')  // Remove italic markers
        .replaceAll('`', '')  // Remove code markers
        .replaceAll('#', '')  // Remove header markers
        .replaceAll('>', '')  // Remove quote markers
        .replaceAll('|', '')  // Remove table markers
        .replaceAll('~', '')  // Remove strikethrough markers
        .trim();
    
    // Debug: Print the decision process
    print('🔍 _buildGeneralResponse Debug:');
    print('  - Text length: ${cleanText.length}');
    print('  - Should use AnswerCard: ${_shouldUseAnswerCard(cleanText)}');
    print('  - Is simple response: ${_isSimpleResponse(cleanText)}');
    print('  - Has structured content: ${_hasStructuredContent(cleanText)}');
    
    // For short, simple responses, just use simple text
    if (cleanText.length < 120 || !_shouldUseAnswerCard(cleanText)) {
      print('  ✅ Using simple text bubble');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceMedium),
        ),
        child: Text(
          cleanText,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.textMedium,
          ),
        ),
      );
    }
    
    print('  🎨 Using beautiful Ask anything card');
    
    // Use the actual user question if provided, otherwise use a generic title
    String question = userQuestion ?? "Plant Care Question";
    
    // Don't try to extract question from AI response - that's not reliable
    // The question should come from the user's actual input
    
    // Extract key points from the clean text (simple heuristic)
    List<String> keyPoints = [];
    
    // Split text into paragraphs and identify key information
    List<String> paragraphs = cleanText.split('\n\n');
    if (paragraphs.length > 1) {
      // Look for bullet points or numbered lists
      List<String> lines = cleanText.split('\n');
      for (String line in lines) {
        line = line.trim();
        if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*') || 
            RegExp(r'^\d+\.').hasMatch(line)) {
          String cleanPoint = line.replaceAll(RegExp(r'^[•\-*\d\.\s]+'), '').trim();
          if (cleanPoint.isNotEmpty && cleanPoint.length > 10) {
            keyPoints.add(cleanPoint);
          }
        }
      }
      
      // If no bullet points found, create key points from paragraphs
      if (keyPoints.isEmpty && paragraphs.length > 1) {
        for (int i = 1; i < paragraphs.length && keyPoints.length < 5; i++) {
          String para = paragraphs[i].trim();
          if (para.isNotEmpty && para.length > 20) {
            // Extract first sentence as key point
            String firstSentence = para.split('.')[0].trim();
            if (firstSentence.isNotEmpty && firstSentence.length > 10) {
              keyPoints.add(firstSentence);
            }
          }
        }
      }
      
      // If still no key points, extract from sentences with colons
      if (keyPoints.isEmpty) {
        List<String> sentences = cleanText.split('.');
        for (String sentence in sentences) {
          sentence = sentence.trim();
          if (sentence.contains(':') && sentence.length > 15 && keyPoints.length < 5) {
            // Extract the part after colon as key point
            String afterColon = sentence.split(':')[1].trim();
            if (afterColon.isNotEmpty && afterColon.length > 10) {
              keyPoints.add(afterColon);
            }
          }
        }
      }
    }
    
    // If we couldn't extract structured info, create a simple format
    if (keyPoints.isEmpty) {
      keyPoints = ["Important plant care information"];
    }
    
    // Use our beautiful AnswerCard component with clean text
    return AnswerCard(
      question: question,
      answer: cleanText, // Remove truncation, display complete text
      keyPoints: keyPoints.take(5).toList(), // Limit to 5 key points
    );
  }

  // Helper function to determine if we should use AnswerCard
  bool _shouldUseAnswerCard(String text) {
    // Don't use AnswerCard for very short responses
    if (text.length < 50) return false;
    
    // Don't use AnswerCard for simple polite responses or greetings
    if (_isSimpleResponse(text)) return false;
    
    // Use AnswerCard for responses that would benefit from organization
    // Check for structured content first
    if (_hasStructuredContent(text)) return true;
    
    // Use AnswerCard for longer responses (likely educational content)
    if (text.length > 200) return true;
    
    // Use AnswerCard for responses with multiple paragraphs
    if (text.contains('\n\n')) return true;
    
    // Use AnswerCard for responses that contain colons (indicating structured content)
    if (text.contains(':')) return true;
    
    // Use AnswerCard for responses that contain multiple sentences
    if (text.split('.').length > 4) return true;
    
    // Use AnswerCard for responses that contain plant care keywords
    if (_containsPlantCareContent(text)) return true;
    
    return false;
  }

  // Check if response contains plant care content
  bool _containsPlantCareContent(String text) {
    final lowerText = text.toLowerCase();
    
    // Plant care related keywords
    final plantCareKeywords = [
      'grow', 'plant', 'water', 'fertilize', 'soil', 'sunlight', 'temperature',
      'climate', 'zone', 'variety', 'hardy', 'frost', 'greenhouse', 'container',
      'prune', 'repot', 'pest', 'disease', 'nutrient', 'drainage', 'humidity',
    ];
    
    int keywordCount = 0;
    for (final keyword in plantCareKeywords) {
      if (lowerText.contains(keyword)) {
        keywordCount++;
      }
    }
    
    // If it contains multiple plant care keywords, it's likely educational content
    return keywordCount >= 2;
  }

  // Check if response is just a simple polite response
  bool _isSimpleResponse(String text) {
    final lowerText = text.toLowerCase();
    
    // Very short responses are simple
    if (text.length < 80) return true;
    
    // Simple polite responses
    final politeResponses = [
      'thank you', 'thanks', 'you\'re welcome', 'no problem', 'my pleasure',
      'glad to help', 'happy to help', 'anytime', 'sure thing', 'of course',
    ];
    
    for (final polite in politeResponses) {
      if (lowerText.contains(polite)) {
        // Only mark as simple if it's mostly just the polite response
        if (text.length < 150 || _getContentRatio(text, polite) > 0.5) {
          return true;
        }
      }
    }
    
    // Simple greetings - only if they're truly simple
    final greetings = [
      'hello', 'hi', 'hey', 'good morning', 'good afternoon', 'good evening',
    ];
    
    for (final greeting in greetings) {
      if (lowerText.contains(greeting)) {
        // Only mark as simple if it's a very short greeting
        if (text.length < 100) {
          return true;
        }
        
        // For longer responses with greetings, check if they're mostly conversational
        // and don't contain substantial plant care information
        if (_isConversationalResponse(text) && !_containsPlantCareContent(text)) {
          return true;
        }
      }
    }
    
    return false;
  }

  // Check if response is mostly conversational without substantial content
  bool _isConversationalResponse(String text) {
    final lowerText = text.toLowerCase();
    
    // Conversational phrases that don't add substantial value
    final conversationalPhrases = [
      'how are you', 'how\'s it going', 'nice to meet you', 'pleasure to meet you',
      'is there anything else', 'anything else you\'d like to know',
      'feel free to ask', 'don\'t hesitate to ask', 'let me know if you need',
      'what can i help you with', 'how can i assist you', 'i\'m here to help',
    ];
    
    int phraseCount = 0;
    for (final phrase in conversationalPhrases) {
      if (lowerText.contains(phrase)) {
        phraseCount++;
      }
    }
    
    // If it contains multiple conversational phrases, it's likely conversational
    if (phraseCount >= 2) return true;
    
    // Check if the response is mostly questions without answers
    int questionCount = 0;
    List<String> sentences = text.split('.');
    for (String sentence in sentences) {
      sentence = sentence.trim();
      if (sentence.contains('?') && sentence.length < 100) {
        questionCount++;
      }
    }
    
    // If mostly questions, it's conversational
    if (questionCount >= 2 && questionCount >= sentences.length * 0.5) {
      return true;
    }
    
    return false;
  }

  // Check if the question is not plant-related
  bool _isNonPlantQuestion(String text) {
    final lowerText = text.toLowerCase();
    
    // Non-plant topics that should use simple text
    final nonPlantTopics = [
      'weather', 'temperature', 'climate', 'season', 'time', 'date', 'calendar',
      'math', 'calculation', 'number', 'percentage', 'statistics',
      'history', 'politics', 'news', 'current events', 'technology', 'computer',
      'cooking', 'recipe', 'food', 'restaurant', 'travel', 'vacation', 'hotel',
      'music', 'movie', 'book', 'art', 'sport', 'exercise', 'health', 'medical',
    ];
    
    int nonPlantCount = 0;
    for (final topic in nonPlantTopics) {
      if (lowerText.contains(topic)) {
        nonPlantCount++;
      }
    }
    
    // If it contains multiple non-plant topics, it's likely not a plant question
    if (nonPlantCount >= 2) return true;
    
    // Check for specific non-plant question patterns
    final nonPlantPatterns = [
      'what is the weather', 'how is the weather', 'what time is it',
      'what day is it', 'what date is it', 'how to cook', 'recipe for',
      'where to eat', 'best restaurant', 'how to travel', 'vacation tips',
      'what movie', 'what book', 'how to exercise', 'health tips',
    ];
    
    for (final pattern in nonPlantPatterns) {
      if (lowerText.contains(pattern)) return true;
    }
    
    return false;
  }

  // Check if the text is plant-related
  bool _isPlantRelated(String text) {
    final lowerText = text.toLowerCase();
    
    // Plant-related keywords - expanded list
    final plantKeywords = [
      'plant', 'flower', 'tree', 'garden', 'gardening', 'grow', 'growing',
      'seed', 'seedling', 'leaf', 'leaves', 'root', 'stem', 'bud', 'bloom',
      'water', 'fertilize', 'soil', 'sunlight', 'prune', 'repot', 'propagate',
      'pest', 'disease', 'nutrient', 'ph', 'drainage', 'humidity', 'temperature',
      'mango', 'tomato', 'rose', 'orchid', 'succulent', 'herb', 'vegetable',
      'fruit', 'berry', 'apple', 'orange', 'lemon', 'lime', 'grape', 'strawberry',
      'cactus', 'fern', 'palm', 'bamboo', 'vine', 'shrub', 'bush', 'grass',
    ];
    
    int plantCount = 0;
    for (final keyword in plantKeywords) {
      if (lowerText.contains(keyword)) {
        plantCount++;
      }
    }
    
    // More lenient: if it contains at least 1 plant-related keyword, it's plant-related
    // This covers questions like "can I grow mangoes in houston?"
    if (plantCount >= 1) return true;
    
    // Also check for common plant question patterns
    final plantQuestionPatterns = [
      'can i grow', 'how to grow', 'is it possible to grow', 'growing in',
      'plant in', 'grow in', 'climate for', 'zone for', 'temperature for',
      'soil for', 'sunlight for', 'water for', 'fertilize for',
    ];
    
    for (final pattern in plantQuestionPatterns) {
      if (lowerText.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }

  // Check if text has structured content that would benefit from AnswerCard
  bool _hasStructuredContent(String text) {
    // Multiple paragraphs
    if (text.contains('\n\n')) return true;
    
    // Bullet points or numbered lists
    if (text.contains('•') || text.contains('-') || text.contains('*')) return true;
    if (RegExp(r'\d+\.').hasMatch(text)) return true;
    
    // Section headers (common patterns)
    if (RegExp(r'[A-Z][a-z]+:').hasMatch(text)) return true;
    if (RegExp(r'[A-Z][a-z]+\s+[A-Z][a-z]+:').hasMatch(text)) return true;
    
    // Multiple sentences with clear structure
    List<String> sentences = text.split('.');
    if (sentences.length >= 4) {
      // Check if sentences have consistent structure
      int structuredSentences = 0;
      for (String sentence in sentences) {
        sentence = sentence.trim();
        if (sentence.length > 20 && 
            (sentence.contains(':') || 
             sentence.startsWith('First') || sentence.startsWith('Second') ||
             sentence.startsWith('Third') || sentence.startsWith('Finally') ||
             sentence.startsWith('1.') || sentence.startsWith('2.') ||
             sentence.startsWith('3.') || sentence.startsWith('4.'))) {
          structuredSentences++;
        }
      }
      if (structuredSentences >= 2) return true;
    }
    
    return false;
  }

  // Check if text contains substantial plant care information
  bool _hasSubstantialPlantInfo(String text) {
    final lowerText = text.toLowerCase();
    
    // Plant care action keywords (more specific and actionable)
    final actionKeywords = [
      'water', 'fertilize', 'prune', 'repot', 'propagate', 'harvest',
      'plant', 'grow', 'sow', 'transplant', 'divide', 'cut back',
    ];
    
    // Plant care topic keywords (educational content)
    final topicKeywords = [
      'sunlight', 'soil', 'temperature', 'humidity', 'climate', 'zone',
      'pest', 'disease', 'nutrient', 'ph', 'drainage', 'air circulation',
    ];
    
    // Plant-specific keywords
    final plantKeywords = [
      'mango', 'tomato', 'rose', 'orchid', 'succulent', 'herb', 'vegetable',
      'fruit tree', 'indoor plant', 'outdoor plant', 'annual', 'perennial',
    ];
    
    int actionCount = 0;
    int topicCount = 0;
    int plantCount = 0;
    
    for (final keyword in actionKeywords) {
      if (lowerText.contains(keyword)) actionCount++;
    }
    
    for (final keyword in topicKeywords) {
      if (lowerText.contains(keyword)) topicCount++;
    }
    
    for (final keyword in plantKeywords) {
      if (lowerText.contains(keyword)) plantCount++;
    }
    
    // Need substantial combination of keywords to use AnswerCard
    int totalScore = actionCount + topicCount + plantCount;
    
    // Must have at least 3 relevant keywords AND substantial length
    if (totalScore >= 3 && text.length > 200) return true;
    
    // Or have very specific plant care instructions
    if (actionCount >= 2 && topicCount >= 1) return true;
    
    return false;
  }

  // Helper function to calculate content ratio
  double _getContentRatio(String text, String phrase) {
    if (text.isEmpty || phrase.isEmpty) return 0.0;
    
    int phraseCount = text.toLowerCase().split(phrase.toLowerCase()).length - 1;
    return phraseCount * phrase.length / text.length;
  }

  // Check if the question is related to general gardening topics
  bool _isGeneralGardeningQuestion(String text) {
    final lowerText = text.toLowerCase();
    
    // Gardening-related topics that are acceptable
    final gardeningTopics = [
      'garden', 'gardening', 'landscape', 'lawn', 'yard', 'outdoor', 'outdoors',
      'seasonal', 'spring', 'summer', 'fall', 'autumn', 'winter',
      'climate', 'weather', 'zone', 'hardiness', 'frost', 'heat', 'cold',
      'compost', 'mulch', 'organic', 'natural', 'sustainable', 'eco-friendly',
      'container', 'pot', 'planter', 'greenhouse', 'indoor', 'houseplant',
      'vegetable', 'herb', 'fruit', 'edible', 'harvest', 'harvesting',
    ];
    
    // Check if the question contains gardening-related topics
    for (final topic in gardeningTopics) {
      if (lowerText.contains(topic)) {
        return true;
      }
    }
    
    // Check for common gardening question patterns
    final gardeningPatterns = [
      'how to', 'what is', 'when to', 'where to', 'why do', 'can i',
      'best way', 'tips for', 'advice on', 'help with', 'problem with',
    ];
    
    for (final pattern in gardeningPatterns) {
      if (lowerText.contains(pattern)) {
        // If it's a "how to" question, it's likely gardening-related
        return true;
      }
    }
    
    return false;
  }

  Widget _buildPlantInfoResponse(Map<String, dynamic> data) {
    // Debug: Print the actual data structure
    print('🔍 _buildPlantInfoResponse Debug:');
    print('  - Raw data: $data');
    print('  - Data keys: ${data.keys.toList()}');
    print('  - plantInfo: ${data['plantInfo']}');
    print('  - careInstructions: ${data['careInstructions']}');
    
    final plantInfo = data['plantInfo'] as Map<String, dynamic>?;
    final care = data['careInstructions'] as Map<String, dynamic>?;
    
    print('  - Parsed plantInfo: $plantInfo');
    print('  - Parsed care: $care');
    
    if (plantInfo != null) {
      print('  - plantInfo keys: ${plantInfo.keys.toList()}');
      print('  - plantInfo name: ${plantInfo['name']}');
      print('  - plantInfo scientificName: ${plantInfo['scientificName']}');
    }
    
    if (care != null) {
      print('  - care keys: ${care.keys.toList()}');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plantInfo != null) ...[
          Container(
            width: double.infinity,
          padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceMedium),
            ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.local_florist, color: AppColors.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
              Text(
                      'Plant Information',
                      style: TextStyle(
                        fontSize: 18,
                  fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (plantInfo['name'] != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Name:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          plantInfo['name'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (plantInfo['scientificName'] != null) ...[
                  Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Scientific Name:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          plantInfo['scientificName'].toString(),
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        if (care != null && care.isNotEmpty) ...[
          Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                ),
                      child: Icon(Icons.eco, color: AppColors.accentGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                      'Care Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successGreen,
                ),
              ),
            ],
          ),
                const SizedBox(height: 16),
                ..._buildCareInstructions(care),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildCareInstructions(Map<String, dynamic> care) {
    final instructions = <Widget>[];
    
    final careCategories = [
      {'key': 'watering', 'label': 'Watering', 'icon': '💧', 'color': AppColors.accentBlue},
      {'key': 'light', 'label': 'Light', 'icon': '✳️', 'color': AppColors.warningYellow},
      {'key': 'soil', 'label': 'Soil', 'icon': '🌱', 'color': AppColors.accentGreen},
      {'key': 'temperature', 'label': 'Temperature', 'icon': '🌡️', 'color': AppColors.errorRed},
    ];
    
    for (final category in careCategories) {
      final value = care[category['key']]?.toString();
      if (value != null && value.isNotEmpty) {
        instructions.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category['icon']} ${category['label']}:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: category['color'] as Color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    return instructions;
  }

  Widget _buildDiagnosisResponse(Map<String, dynamic> data) {
    final diagnosis = data['diagnosis']?.toString();
    final recs = (data['recommendations'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (diagnosis != null && diagnosis.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.search, color: AppColors.accentBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Diagnosis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  diagnosis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        if (recs.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceMedium),
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCream,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.lightbulb, color: AppColors.warningYellow, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recommendations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningYellow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...recs.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          color: AppColors.warningYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rec,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _switchMode(GaiaMode newMode) {
    if (_currentMode == newMode) return;

    // 在 Ask anything 模式下，保留用戶的輸入以維持對話流暢性
    final preserveInput = _currentMode == GaiaMode.general && newMode == GaiaMode.general;
    final currentText = preserveInput ? _chatController.text : '';
    final currentDescription = preserveInput ? _descriptionController.text : '';

    setState(() {
      _currentMode = newMode;
      _diagnosisResult = null;
      _errorMessage = '';
      _images.clear();
      _imageNames.clear();
      
      // 如果不是在 Ask anything 模式之間切換，則清空輸入
      if (!preserveInput) {
      _chatController.clear();
      _descriptionController.clear();
      } else {
        // 保留輸入內容
        _chatController.text = currentText;
        _descriptionController.text = currentDescription;
      }
      
      _localMessages.clear();
    });

    // Load messages after setState to avoid compilation issues
    if (_currentSessionId != null && _currentSessionId != 'local') {
      _loadSessionMessages();
    }
  }

  Future<void> _loadSessionMessages() async {
    try {
      final messages = await ChatService.loadMessages(_currentSessionId!);
      if (mounted) {
        setState(() {
          _localMessages.addAll(messages);
        });
      }
    } catch (e) {
      print('❌ Error loading session messages: $e');
    }
  }

  Widget _buildIntentOptions() {
    if (_intentAnalysis == null) return const SizedBox.shrink();
    
    final suggestedActions = _intentAnalysis!['suggestedActions'] as List? ?? [];
    final imageDescription = _intentAnalysis!['imageDescription'] as String? ?? '';
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: AppColors.surfaceCream,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCream.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome, color: AppColors.successGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Smart Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (imageDescription.isNotEmpty) ...[
              Text(
                imageDescription,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'What would you like to do with this image?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestedActions.map<Widget>((action) {
                final actionData = action as Map<String, dynamic>;
                final id = actionData['id'] as String? ?? '';
                final title = actionData['title'] as String? ?? '';
                final description = actionData['description'] as String? ?? '';
                final color = actionData['color'] as String? ?? '#4CAF50';
                
                return InkWell(
                  onTap: () => _selectIntent(id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(int.parse(color.replaceAll('#', '0xFF'))).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(int.parse(color.replaceAll('#', '0xFF'))).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(int.parse(color.replaceAll('#', '0xFF'))),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Format Plant ID response as text for Ask anything mode
  String _formatPlantInfoAsText(Map<String, dynamic> plantData) {
    final plantInfo = plantData['plantInfo'] as Map<String, dynamic>?;
    final careInstructions = plantData['careInstructions'] as Map<String, dynamic>?;
    final recommendations = plantData['recommendations'] as List<dynamic>?;
    
    final buffer = StringBuffer();
    
    // Start with a friendly, conversational tone
    buffer.writeln('Hi there! Thanks for asking about growing strawberries. That\'s a great question!');
    buffer.writeln();
    buffer.writeln('The short answer is... it\'s definitely possible and quite rewarding! Here\'s a more detailed breakdown:');
    buffer.writeln();
    
    // Plant information in a friendly way
    if (plantInfo != null) {
      if (plantInfo['name'] != null && plantInfo['name'].toString().toLowerCase().contains('strawberry')) {
        buffer.writeln('🌱 Strawberry Growing Guide');
        buffer.writeln();
        buffer.writeln('Strawberries are wonderful plants that can be grown in gardens, containers, or even hanging baskets. They\'re perfect for beginners and provide delicious rewards!');
        buffer.writeln();
      }
    }
    
    // Care instructions in a helpful, conversational way
    if (careInstructions != null && careInstructions.isNotEmpty) {
      buffer.writeln('💧 Key Care Points:');
      buffer.writeln();
      
      if (careInstructions['watering'] != null) {
        buffer.writeln('Watering: ${careInstructions['watering']}');
        buffer.writeln();
      }
      if (careInstructions['light'] != null) {
        buffer.writeln('Light: ${careInstructions['light']}');
        buffer.writeln();
      }
      if (careInstructions['soil'] != null) {
        buffer.writeln('Soil: ${careInstructions['soil']}');
        buffer.writeln();
      }
      if (careInstructions['temperature'] != null) {
        buffer.writeln('Temperature: ${careInstructions['temperature']}');
        buffer.writeln();
      }
      if (careInstructions['fertilizing'] != null) {
        buffer.writeln('Fertilizing: ${careInstructions['fertilizing']}');
        buffer.writeln();
      }
      if (careInstructions['humidity'] != null) {
        buffer.writeln('Humidity: ${careInstructions['humidity']}');
        buffer.writeln();
      }
    }
    
    // Additional recommendations
    if (recommendations != null && recommendations.isNotEmpty) {
      buffer.writeln('💡 Pro Tips:');
      for (final rec in recommendations) {
        buffer.writeln('• $rec');
      }
      buffer.writeln();
    }
    
    // Add encouraging conclusion
    buffer.writeln('🎯 Getting Started:');
    buffer.writeln('The best time to plant strawberries is in early spring or late summer. You can start with young plants from a garden center or grow from seeds if you\'re patient!');
    buffer.writeln();
    buffer.writeln('💚 Feel free to ask more specific questions about any of these care aspects. I\'m here to help you grow the best strawberries possible!');
    
    return buffer.toString();
  }

  // Security and content filtering
  static const List<String> _blockedKeywords = [
    // Illegal activities
    'bomb', 'explosive', 'weapon', 'drug', 'illegal', 'hack', 'steal', 'kill', 'murder',
    'terrorism', 'extremist', 'radical', 'criminal', 'fraud', 'scam', 'phishing',
    
    // Harmful content
    'hate', 'racism', 'discrimination', 'violence', 'abuse', 'harassment', 'bully',
    'suicide', 'self-harm', 'dangerous', 'harmful', 'toxic',
    
    // Inappropriate content
    'porn', 'adult', 'sexual', 'explicit', 'inappropriate', 'offensive',
    
    // System attacks
    'sql injection', 'xss', 'csrf', 'buffer overflow', 'ddos', 'malware', 'virus',
    'backdoor', 'rootkit', 'trojan', 'spyware',
  ];

  static const List<String> _suspiciousPatterns = [
    // Suspicious patterns
    r'<script.*?>', // HTML script tags
    r'javascript:', // JavaScript protocol
    r'data:text/html', // Data URLs
    r'vbscript:', // VBScript
    r'on\w+\s*=', // Event handlers
    r'<iframe.*?>', // Iframe tags
    r'<object.*?>', // Object tags
    r'<embed.*?>', // Embed tags
    r'<link.*?>', // Link tags
    r'<meta.*?>', // Meta tags
  ];

  // Check if input contains blocked content
  bool _isContentBlocked(String text) {
    final lowerText = text.toLowerCase();
    
    // Check for blocked keywords
    for (final keyword in _blockedKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        print('🚫 Content blocked: Contains blocked keyword "$keyword"');
        return true;
      }
    }
    
    // Check for suspicious patterns
    for (final pattern in _suspiciousPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(text)) {
        print('🚫 Content blocked: Contains suspicious pattern "$pattern"');
        return true;
      }
    }
    
    // Check for excessive length (prevent abuse)
    if (text.length > 2000) {
      print('🚫 Content blocked: Input too long (${text.length} characters)');
      return true;
    }
    
    // Check for excessive repetition (spam detection)
    final words = text.toLowerCase().split(' ');
    final wordCount = <String, int>{};
    for (final word in words) {
      if (word.length > 3) { // Only check meaningful words
        wordCount[word] = (wordCount[word] ?? 0) + 1;
        if (wordCount[word]! > 10) { // Word repeated more than 10 times
          print('🚫 Content blocked: Excessive word repetition "$word"');
          return true;
        }
      }
    }
    
    return false;
  }

  // Sanitize input text
  String _sanitizeInput(String text) {
    // Remove HTML tags
    String sanitized = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Remove script-like content
    sanitized = sanitized.replaceAll(RegExp(r'<script.*?</script>', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'vbscript:', caseSensitive: false), '');
    
    // Remove event handlers - fix the regex syntax
    sanitized = sanitized.replaceAll(RegExp(r'on\w+\s*=\s*["\''][^"\']*["\']', caseSensitive: false), '');
    
    // Remove excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Trim and limit length
    sanitized = sanitized.trim();
    if (sanitized.length > 1000) {
      sanitized = '${sanitized.substring(0, 1000)}...';
    }
    
    return sanitized;
  }
}
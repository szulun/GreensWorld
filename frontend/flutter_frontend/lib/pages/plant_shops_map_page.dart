import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add Firebase Auth import
import '../widgets/navbar_home.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env_config.dart';
import '../widgets/theme.dart';
import 'dart:js' as js; // Added for web-specific tests

class PlantShopsMapPage extends StatefulWidget {
  const PlantShopsMapPage({super.key});

  @override
  State<PlantShopsMapPage> createState() => _PlantShopsMapPageState();
}

class _PlantShopsMapPageState extends State<PlantShopsMapPage> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  LatLng? _currentLocation;
  bool _isLoading = false;
  String _status = 'Ready to get location';
  final bool _isWeb = kIsWeb;
  List<Map<String, dynamic>> _plantShops = [];

  bool _showHelpPanel = false;
  late AnimationController _helpAnimationController;
  late Animation<double> _helpSlideAnimation;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final bool _showSearchResults = false;

  // Results panel animation
  late AnimationController _panelAnimationController;
  late Animation<double> _panelSlideAnimation;
  bool _showResultsPanel = false;

  // Enhanced user authentication tracking
  Set<String> _favoriteShopIds = {};
  bool _isFavoriteLoading = false;
  String? _currentUserId;
  String? _currentUserEmail;
  bool _isUserLoggedIn = false;

  // Firebase Auth listener
  StreamSubscription<User?>? _authSubscription;

  Future<Map<String, String>> _authHeaders() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('Not signed in');
  }
  final idToken = await user.getIdToken(true); // force refresh
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $idToken',
  };
}

  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(40.7128, -74.0060),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    setState(() {
      _status = 'Ready to get location';
    });

    // Initialize animation controller for results panel
    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _panelSlideAnimation = Tween<double>(
      begin: -350.0, // Hidden off-screen
      end: 0.0,      // Visible position
    ).animate(CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeInOut,
    ));

      // Initialize help panel animation controller
    _helpAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _helpSlideAnimation = Tween<double>(
      begin: 380.0, // Start off-screen to the right
      end: 0.0,     // End in visible position
    ).animate(CurvedAnimation(
      parent: _helpAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize user and load favorites
    _initializeUser();
    
    // Test if Google Maps API is working properly
    _testGoogleMapsAPI();
    
    // Automatically get location and display shop list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getLocation();
    });
  }

  // Update your dispose() method:
  @override
  void dispose() {
    _searchController.dispose();
    _panelAnimationController.dispose();
    _helpAnimationController.dispose(); // Add this line
    _authSubscription?.cancel();
    super.dispose();
  }

  // Enhanced user initialization with Firebase Auth integration
  Future<void> _initializeUser() async {
    // Listen to Firebase Auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User is signed in
        setState(() {
          _currentUserId = user.uid;
          _currentUserEmail = user.email;
          _isUserLoggedIn = true;
        });

        // Also sync with SharedPreferences
        await _syncUserWithSharedPreferences(user);
        
        // Load favorites after user is confirmed
        await _loadFavoriteShops();
        
        print('Firebase user authenticated: ${user.uid} (${user.email})');
      } else {
        // User is signed out
        await _clearUserSession();
        print('User signed out');
      }
    });

    // Also check SharedPreferences as fallback
    await _loadCurrentUser();
  }

  // Sync Firebase user with SharedPreferences
  Future<void> _syncUserWithSharedPreferences(User user) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('userId', user.uid);
      await prefs.setString('userEmail', user.email ?? '');
      await prefs.setString('userName', user.displayName ?? '');
      await prefs.setBool('isLoggedIn', true);
      
      print('Synced Firebase user to SharedPreferences: ${user.uid}');
    } catch (e) {
      print('Error syncing user to SharedPreferences: $e');
    }
  }

  // Improved user loading with better validation
  Future<void> _loadCurrentUser() async {
    try {
      // First check if there's a Firebase user
      User? firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        setState(() {
          _currentUserId = firebaseUser.uid;
          _currentUserEmail = firebaseUser.email;
          _isUserLoggedIn = true;
        });
        await _loadFavoriteShops();
        return;
      }

      // Fallback to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');
      String? userEmail = prefs.getString('userEmail');
      bool? isLoggedIn = prefs.getBool('isLoggedIn');
      
      print('SharedPreferences - UserId: $userId, UserEmail: $userEmail, IsLoggedIn: $isLoggedIn');
      
      // Check for valid user ID (not offline and not empty)
      if (userId != null && 
          userId.isNotEmpty && 
          !userId.startsWith('offline_') &&
          userEmail != null &&
          userEmail.isNotEmpty &&
          (isLoggedIn == true)) {
        
        // Verify user exists in backend
        bool userExists = await _verifyUserExists(userId);
        
        if (userExists) {
          setState(() {
            _currentUserId = userId;
            _currentUserEmail = userEmail;
            _isUserLoggedIn = true;
          });
          await _loadFavoriteShops();
          print('Valid user loaded from SharedPreferences: $userId ($userEmail)');
        } else {
          print('User verification failed for ID: $userId');
          await _clearUserSession();
        }
      } else {
        print('No valid user credentials found in SharedPreferences');
        await _clearUserSession();
      }
    } catch (e) {
      print('Error loading current user: $e');
      await _clearUserSession();
    }
  }

  // Verify user exists in backend
  Future<bool> _verifyUserExists(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${EnvConfig.apiUrl}/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));

      print('User verification response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] != null;
      }
      return false;
    } catch (e) {
      print('Error verifying user: $e');
      return false;
    }
  }

  // Clear user session
  Future<void> _clearUserSession() async {
    try {
      // Clear SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('userEmail');
      await prefs.remove('userName');
      await prefs.setBool('isLoggedIn', false);

      setState(() {
        _currentUserId = null;
        _currentUserEmail = null;
        _isUserLoggedIn = false;
        _favoriteShopIds.clear();
      });

      print('User session cleared');
    } catch (e) {
      print('Error clearing user session: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
      _status = 'Getting location...';
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 30),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _status = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 14,
          ),
        ),
      );

      await _fetchNearbyPlantShops();

      // Automatically display results panel
      if (_plantShops.isNotEmpty) {
        setState(() {
          _showResultsPanel = true;
        });
        _panelAnimationController.forward();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎯 Found your location!'),
          backgroundColor: AppColors.successGreen,
        ),
      );

    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Location error: $e'),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNearbyPlantShops({String? searchQuery, String? place}) async {
    if (_currentLocation == null && place == null) return;

    try {
      setState(() {
        _status = searchQuery != null 
          ? 'Searching for $searchQuery...' 
          : place != null 
            ? 'Searching near $place...'
            : 'Fetching nearby plant shops...';
      });

      String apiUrl = '${EnvConfig.apiUrl}/plant-shops/nearby?';
      
      if (place != null) {
        apiUrl += 'place=${Uri.encodeComponent(place)}&radius=10000';
        if (searchQuery != null) {
          apiUrl += '&q=${Uri.encodeComponent(searchQuery)}';
        }
      } else if (_currentLocation != null) {
        apiUrl += 'lat=${_currentLocation!.latitude}&lng=${_currentLocation!.longitude}&radius=5000';
        if (searchQuery != null) {
          apiUrl += '&q=${Uri.encodeComponent(searchQuery)}';
        }
      }

      print('API URL: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _createMarkersFromShops(data['features']);
          setState(() {
            _status = place != null 
              ? 'Found ${data['features'].length} plant shops near $place'
              : 'Found ${data['features'].length} nearby plant shops';
            _plantShops = List<Map<String, dynamic>>.from(data['features']);
          });

          // Show results panel if we have results
          if (_plantShops.isNotEmpty) {
            _showResultsPanel = true;
            _panelAnimationController.forward();
          }

          if (place != null && data['summary']['searchLocation'] != null) {
            final searchLoc = data['summary']['searchLocation'];
            final newLocation = LatLng(searchLoc['lat'], searchLoc['lng']);
            final GoogleMapController controller = await _controller.future;
            controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: newLocation,
                  zoom: 14,
                ),
              ),
            );
          }
        } else {
          throw Exception('Failed to fetch shops: ${data['error']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _status = 'Error fetching shops: $e';
      });
      
      if (_currentLocation != null) {
        _createMockShopsAroundLocation();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Using fallback data. API error: $e'),
          backgroundColor: AppColors.warningYellow,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _createMarkersFromShops(List<dynamic> shops) {
    final Set<Marker> newMarkers = {};
    
    for (var shop in shops) {
      final marker = Marker(
        markerId: MarkerId(shop['id']),
        position: LatLng(
          shop['lat'],
          shop['lng'],
        ),
        infoWindow: InfoWindow(
          title: shop['name'],
          snippet: '${shop['address']} • ${shop['distanceMeters']}m away${shop['rating'] != null ? ' • ⭐ ${shop['rating']}' : ''}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0),
        onTap: () => _showShopDetails(shop),
      );
      newMarkers.add(marker);
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _showShopDetails(Map<String, dynamic> shop) {
    final shopId = shop['id'].toString();
    final isFavorited = _favoriteShopIds.contains(shopId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              Row(
                children: [
                  Icon(Icons.local_florist, color: Colors.green.shade700, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shop['name'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  // Show favorite button only for logged in users
                  if (_isUserLoggedIn)
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _isFavoriteLoading ? null : () => _toggleFavorite(shop),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            child: _isFavoriteLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryGreen,
                                    ),
                                  ),
                                )
                              : Icon(
                                  isFavorited ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorited ? Colors.red : Colors.grey.shade500,
                                  size: 24,
                                ),
                          ),
                        ),
                      ),
                    ),
                  if (shop['rating'] != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text(
                            shop['rating'].toString(),
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16),
              
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey.shade600, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shop['address'],
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(Icons.directions_walk, color: Colors.grey.shade600, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '${shop['distanceMeters']}m away',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                    ),
                  ),
                  if (shop['isOpen'] != null) ...[
                    SizedBox(width: 20),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: shop['isOpen'] ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        shop['isOpen'] ? 'Open Now' : 'Closed',
                        style: TextStyle(
                          color: shop['isOpen'] ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 20),
              
              if (shop['types'] != null && shop['types'].isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (shop['types'] as List).take(3).map<Widget>((type) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        type.toString().replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _createMockShopsAroundLocation() {
    if (_currentLocation == null) return;

    final Set<Marker> newMarkers = {};
    
    final mockShops = [
      {
        'id': 'shop_1',
        'name': 'Local Garden Center',
        'address': 'Near your location',
        'lat': _currentLocation!.latitude + 0.01,
        'lng': _currentLocation!.longitude + 0.01,
        'distanceMeters': 1000,
        'rating': 4.5,
      },
      {
        'id': 'shop_2',
        'name': 'Plant Nursery',
        'address': 'Near your location',
        'lat': _currentLocation!.latitude - 0.01,
        'lng': _currentLocation!.longitude - 0.01,
        'distanceMeters': 1200,
        'rating': 4.2,
      },
      {
        'id': 'shop_3',
        'name': 'Flower Shop',
        'address': 'Near your location',
        'lat': _currentLocation!.latitude + 0.02,
        'lng': _currentLocation!.longitude - 0.02,
        'distanceMeters': 2000,
        'rating': 4.8,
      },
    ];

    for (var shop in mockShops) {
      final marker = Marker(
        markerId: MarkerId(shop['id'] as String),
        position: LatLng(
          shop['lat'] as double,
          shop['lng'] as double,
        ),
        infoWindow: InfoWindow(
          title: shop['name'] as String,
          snippet: '${shop['address']} • ${shop['distanceMeters']}m away • ⭐ ${shop['rating']}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0),
      );
      newMarkers.add(marker);
    }

    setState(() {
      _markers = newMarkers;
      _plantShops = mockShops.cast<Map<String, dynamic>>();
    });

    // Show results panel for mock data too
    if (_plantShops.isNotEmpty) {
      _showResultsPanel = true;
      _panelAnimationController.forward();
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final plantKeywords = [
      'rose', 'roses', 'succulent', 'succulents', 'cactus', 'cacti',
      'orchid', 'orchids', 'houseplant', 'houseplants', 'indoor',
      'outdoor', 'flower', 'flowers', 'plant', 'plants', 'herb',
      'herbs', 'tree', 'trees', 'shrub', 'shrubs', 'fern', 'ferns',
      'palm', 'palms', 'bamboo', 'mint', 'basil', 'sage', 'thyme',
      'lavender', 'lily', 'tulip', 'daisy', 'sunflower', 'petunia'
    ];

    if (query.toLowerCase().contains(' near ')) {
      final parts = query.toLowerCase().split(' near ');
      if (parts.length == 2) {
        await _fetchNearbyPlantShops(
          searchQuery: parts[0].trim(),
          place: parts[1].trim(),
        );
        FocusScope.of(context).unfocus();
        return;
      }
    }

    if (query.toLowerCase().contains(' in ')) {
      final parts = query.toLowerCase().split(' in ');
      if (parts.length == 2) {
        await _fetchNearbyPlantShops(
          searchQuery: parts[0].trim(),
          place: parts[1].trim(),
        );
        FocusScope.of(context).unfocus();
        return;
      }
    }

    final isPlantKeyword = plantKeywords.any((keyword) => 
      query.toLowerCase().contains(keyword));

    final commonPlaces = [
      'brooklyn', 'manhattan', 'queens', 'bronx', 'staten island',
      'central park', 'times square', 'wall street', 'soho', 'chelsea',
      'williamsburg', 'park slope', 'long island', 'jersey city',
      'atlanta', 'miami', 'chicago', 'boston', 'philadelphia',
      'washington dc', 'los angeles', 'san francisco', 'seattle'
    ];

    final isKnownPlace = commonPlaces.any((place) => 
      query.toLowerCase().contains(place.toLowerCase()));

    if (isPlantKeyword || query.split(' ').length > 1) {
      if (_currentLocation != null) {
        await _fetchNearbyPlantShops(searchQuery: query);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎯 Please get your location first or search "roses near [place name]"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else if (isKnownPlace) {
      await _fetchNearbyPlantShops(place: query);
    } else {
      if (_currentLocation != null) {
        await _fetchNearbyPlantShops(searchQuery: query);
      } else {
        await _fetchNearbyPlantShops(place: query);
      }
    }

    FocusScope.of(context).unfocus();
  }

  // Enhanced favorites functionality with better error handling
  Future<void> _loadFavoriteShops() async {
    if (!_isUserLoggedIn || _currentUserId == null) {
      print('Cannot load favorites: User not logged in');
      return;
    }

    try {
      print('Loading favorites for user: $_currentUserId');

      final headers = await _authHeaders(); // get token + Content-Type

      final response = await http.get(
        Uri.parse('${EnvConfig.apiUrl}/users/$_currentUserId/favorites/plant-shops'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));


      print('Favorites response status: ${response.statusCode}');
      print('Favorites response body: ${response.body}');

      if (response.statusCode == 200) {
        // Check if response is actually JSON before parsing
        if (response.body.startsWith('<') || response.body.contains('DOCTYPE')) {
          throw Exception('Server returned HTML instead of JSON. Check API endpoint.');
        }

        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _favoriteShopIds = Set<String>.from(
              data['favorites'].map((shop) => shop['shopId'].toString())
            );
          });
          print('Successfully loaded ${_favoriteShopIds.length} favorites');
        } else {
          print('API returned success: false - ${data['error'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 404) {
        // User has no favorites yet - this is okay
        print('No favorites found for user (404) - this is normal for new users');
        setState(() {
          _favoriteShopIds = {};
        });
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error loading favorites: $e');
      // Don't show error to user for favorites loading - fail silently
      setState(() {
        _favoriteShopIds = {};
      });
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> shop) async {
    if (!_isUserLoggedIn || _currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Please log in to save favorites'),
          backgroundColor: AppColors.errorRed,
          action: SnackBarAction(
            label: 'Login',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
        ),
      );
      return;
    }

    final shopId = shop['id'].toString();
    final isFavorited = _favoriteShopIds.contains(shopId);

    setState(() => _isFavoriteLoading = true);

    try {
      final base = '${EnvConfig.apiUrl}/users/$_currentUserId/favorites/plant-shops';
      final url = isFavorited ? '$base/$shopId' : base;
      final headers = await _authHeaders(); // <-- includes Bearer token

      print('Toggle favorite URL: $url');
      print('Method: ${isFavorited ? "DELETE" : "POST"}');

      final response = isFavorited
          ? await http
              .delete(Uri.parse(url), headers: headers)
              .timeout(const Duration(seconds: 10))
          : await http
              .post(
                Uri.parse(url),
                headers: headers,
                body: json.encode({
                  'shopId': shopId,
                  'name': shop['name'],
                  'address': _buildDetailedAddress(shop), // 使用更詳細的地址
                  'lat': shop['lat'],
                  'lng': shop['lng'],
                  'rating': shop['rating'],
                  'types': shop['types'],
                }),
              )
              .timeout(const Duration(seconds: 10));

      print('Favorite response status: ${response.statusCode}');
      print('Favorite response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.startsWith('<') || response.body.contains('DOCTYPE')) {
          throw Exception('Server returned HTML instead of JSON. Check API endpoint.');
        }
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            if (isFavorited) {
              _favoriteShopIds.remove(shopId);
            } else {
              _favoriteShopIds.add(shopId);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFavorited ? '💔 Removed from favorites' : '❤️ Added to favorites!'),
              backgroundColor: isFavorited ? Colors.orange.shade600 : AppColors.successGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception(data['error'] ?? 'Unknown error from server');
        }
      } else {
        String msg = 'Failed to update favorite status';
        try {
          if (!response.body.startsWith('<')) {
            final err = json.decode(response.body);
            msg = err['error'] ?? msg;
          }
        } catch (_) {
          msg = 'Server error (${response.statusCode})';
        }
        throw Exception(msg);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error updating favorites: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      setState(() => _isFavoriteLoading = false);
    }
  }

  // Test if Google Maps API is working properly
  void _testGoogleMapsAPI() {
    try {
      // Check if Google Maps API is loaded
      if (kIsWeb) {
        // Test on Web
        print('🔍 Testing Google Maps API...');
        
        // Check global variables
        if (js.context.hasProperty('google') && 
            js.context['google'].hasProperty('maps') &&
            js.context['google']['maps'].hasProperty('Geocoder')) {
          print('✅ Google Maps API loaded, Geocoding available');
        } else {
          print('⚠️ Google Maps API loaded, but Geocoding not available');
          print('💡 Please enable Geocoding API in Google Cloud Console');
        }
        
        if (js.context.hasProperty('google') && 
            js.context['google'].hasProperty('maps') &&
            js.context['google']['maps'].hasProperty('places')) {
          print('✅ Google Maps API loaded, Places available');
        } else {
          print('⚠️ Google Maps API loaded, but Places not available');
          print('💡 Please enable Places API in Google Cloud Console');
        }
      }
    } catch (e) {
      print('❌ Google Maps API test failed: $e');
    }
  }

  String _buildDetailedAddress(Map<String, dynamic> shop) {
    // If address is a generic description, try to build more detailed info
    String address = shop['address']?.toString() ?? '';
    
    if (address.toLowerCase().contains('near your location') ||
        address.toLowerCase().contains('near your area') ||
        address.isEmpty) {
      
      // Try to build a more detailed address
      List<String> addressParts = [];
      
      // Add shop name
      if (shop['name'] != null && shop['name'].toString().isNotEmpty) {
        addressParts.add(shop['name'].toString());
      }
      
      // Add distance info
      if (shop['distanceMeters'] != null) {
        int distance = shop['distanceMeters'] as int;
        if (distance < 1000) {
          addressParts.add('${distance}m away');
        } else {
          addressParts.add('${(distance / 1000).toStringAsFixed(1)}km away');
        }
      }
      
      // If rating, also add it
      if (shop['rating'] != null) {
        addressParts.add('⭐ ${shop['rating']}');
      }
      
      // Combine address info
      if (addressParts.isNotEmpty) {
        return addressParts.join(' • ');
      }
    }
    
    return address;
  }


  void _onShopTapped(Map<String, dynamic> shop) async {
    final GoogleMapController controller = await _controller.future;
    
    // Animate to the marker
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(shop['lat'], shop['lng']),
          zoom: 16,
        ),
      ),
    );

    // Optional: Show info window or details
    Future.delayed(Duration(milliseconds: 500), () {
      _showShopDetails(shop);
    });

    // Hide the panel on mobile for better view
    if (MediaQuery.of(context).size.width < 768) {
      _hideResultsPanel();
    }
  }

  void _hideResultsPanel() {
    _panelAnimationController.reverse();
    Future.delayed(Duration(milliseconds: 300), () {
      setState(() {
        _showResultsPanel = false;
      });
    });
  }

  Widget _buildResultsPanel() {
    return AnimatedBuilder(
      animation: _panelSlideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_panelSlideAnimation.value, 0),
          child: Container(
            width: 350,
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_florist, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Plant Shops (${_plantShops.length})',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!_isUserLoggedIn)
                        Tooltip(
                          message: 'Log in to save favorites',
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: _hideResultsPanel,
                      ),
                    ],
                  ),
                ),
                
                // Results list
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _plantShops.length,
                    itemBuilder: (context, index) {
                      final shop = _plantShops[index];
                      return _buildShopListItem(shop, index);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShopListItem(Map<String, dynamic> shop, int index) {
    final shopId = shop['id'].toString();
    final isFavorited = _favoriteShopIds.contains(shopId);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onShopTapped(shop),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop name, rating, and favorite button
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_florist,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop['name'],
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (shop['rating'] != null)
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.orange, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  shop['rating'].toString(),
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Show favorite button only for logged in users
                    if (_isUserLoggedIn)
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _isFavoriteLoading ? null : () => _toggleFavorite(shop),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              child: _isFavoriteLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryGreen,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    isFavorited ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorited ? Colors.red : Colors.grey.shade500,
                                    size: 20,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    // Distance badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${shop['distanceMeters']}m',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // Address
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey.shade500, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shop['address'],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                // Status and types
                if (shop['isOpen'] != null || (shop['types'] != null && shop['types'].isNotEmpty)) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      if (shop['isOpen'] != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: shop['isOpen'] ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            shop['isOpen'] ? 'Open' : 'Closed',
                            style: TextStyle(
                              color: shop['isOpen'] ? Colors.green.shade700 : Colors.red.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      if (shop['types'] != null && shop['types'].isNotEmpty) ...[
                        if (shop['isOpen'] != null) SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (shop['types'] as List).take(2).map((type) => 
                              type.toString().replaceAll('_', ' ')).join(' • '),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add this new method to build the help panel:
Widget _buildHelpPanel() {
  return AnimatedBuilder(
    animation: _helpSlideAnimation,
    builder: (context, child) {
      return Transform.translate(
        offset: Offset(_helpSlideAnimation.value, 0),
        child: Container(
          width: MediaQuery.of(context).size.width < 768 ? 
                MediaQuery.of(context).size.width - 40 : 360,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryGreen, AppColors.deepGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      '🗺️ How to Search',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showHelpPanel = false;
                        });
                        _helpAnimationController.reverse();
                      },
                      icon: Icon(Icons.close, color: Colors.white),
                      iconSize: 20,
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    // Prevent scroll events from bubbling up to the map
                    return true;
                  },
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    physics: ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plant Keywords Section
                        _buildHelpSection(
                          icon: '🎯',
                          title: 'Plant Keywords',
                          description: 'Search for specific plants using your current location',
                          examples: [
                            '"roses"',
                            '"succulents"',
                            '"houseplants"',
                          ],
                          isGood: true,
                        ),
                        
                        // Plant tags
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: ['orchids', 'herbs', 'cactus', 'flowers', 'ferns']
                              .map((tag) => Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Plant + Location Section
                        _buildHelpSection(
                          icon: '📍',
                          title: 'Plant + Location',
                          description: 'Combine plants with specific places',
                          examples: [
                            '"roses near Central Park"',
                            '"succulents in Brooklyn"',
                            '"herbs near Manhattan"',
                          ],
                          isGood: true,
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Location Specificity Warning
                        _buildHelpSection(
                          icon: '⚠️',
                          title: 'Be Specific with Locations',
                          description: null,
                          examples: [
                            '"orchids in Washington DC"',
                          ],
                          isGood: true,
                        ),
                        
                        _buildHelpSection(
                          icon: null,
                          title: null,
                          description: null,
                          examples: [
                            '"orchids in Washington" ← Too vague!',
                          ],
                          isGood: false,
                        ),
                        
                        // Tip
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('💡', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade800,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Washington DC',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(text: ' vs '),
                                      TextSpan(
                                        text: 'Washington State',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(text: ' - Specificity matters for accurate results!'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Quick Tips
                        _buildHelpSection(
                          icon: '🚀',
                          title: 'Quick Tips',
                          description: null,
                          examples: null,
                          isGood: null,
                        ),
                        
                        Container(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• Enable location first for best results',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              SizedBox(height: 4),
                              Text('• Log in to save favorite shops',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              SizedBox(height: 4),
                              Text('• Tap markers for shop details',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              SizedBox(height: 4),
                              Text('• Use the list view on mobile',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
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
  // Add this helper method to build help sections:
  Widget _buildHelpSection({
    String? icon,
    String? title,
    String? description,
    List<String>? examples,
    bool? isGood,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Text(icon, style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
        ],
        
        if (description != null) ...[
          Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          SizedBox(height: 12),
        ],
        
        if (examples != null)
          ...examples.map((example) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGood == true 
                      ? Colors.green.shade50 
                      : isGood == false 
                          ? Colors.red.shade50 
                          : Colors.grey.shade50,
                  border: Border.all(
                    color: isGood == true 
                        ? Colors.green.shade200 
                        : isGood == false 
                            ? Colors.red.shade200 
                            : Colors.grey.shade200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        example,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: isGood == true 
                              ? Colors.green.shade700 
                              : isGood == false 
                                  ? Colors.red.shade700 
                                  : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (isGood != null)
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isGood 
                              ? Colors.green.shade600 
                              : Colors.red.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isGood ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                  ],
                ),
              )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NavbarHome(),
      body: Stack(
        children: [
          // Map with conditional left margin
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            margin: EdgeInsets.only(
              left: _showResultsPanel && MediaQuery.of(context).size.width >= 768 ? 350 : 0,
            ),
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              initialCameraPosition: _defaultLocation,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
            ),
          ),

          // Results Panel (only show when we have results)
          if (_showResultsPanel && _plantShops.isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              child: _buildResultsPanel(),
            ),

          if (_isLoading)
            Container(
              color: AppColors.deepGreen.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      _status,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (_isWeb) ...[
                      SizedBox(height: 8),
                      Text(
                        'Please allow location access in browser',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Search bar
          Positioned(
            top: 16,
            left: _showResultsPanel && MediaQuery.of(context).size.width >= 768 ? 366 : 16,
            right: 80,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search "roses", "succulents near Central Park"',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.green.shade700),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                ),
                onSubmitted: (_) => _performSearch(),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),

          // Search button
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _performSearch,
              backgroundColor: Colors.green.shade700,
              child: Icon(Icons.search, color: Colors.white),
            ),
          ),

          // Enhanced status bar with user login status
          Positioned(
            top: 80,
            left: _showResultsPanel && MediaQuery.of(context).size.width >= 768 ? 366 : 16,
            right: 16,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _isUserLoggedIn ? Icons.info : Icons.login,
                    color: _isUserLoggedIn ? Colors.blue : Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isUserLoggedIn
                        ? '$_status • Favorites enabled'
                        : '$_status • Log in to save favorites',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  // Add quick login button if not logged in
                  if (!_isUserLoggedIn)
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Location button
          Positioned(
            top: 140,
            right: 16,
            child: FloatingActionButton(
              onPressed: _isLoading ? null : _getLocation,
              backgroundColor: const Color(0xFF2E7D32),
              child: _isLoading 
                ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Icon(Icons.my_location, color: Colors.white),
            ),
          ),

          // Help section button
          Positioned(
          top: 200, 
          right: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              setState(() {
                _showHelpPanel = !_showHelpPanel;
              });
              if (_showHelpPanel) {
                _helpAnimationController.forward();
              } else {
                _helpAnimationController.reverse();
              }
            },
            backgroundColor: AppColors.primaryGreen,
            child: Icon(
              Icons.help_outline,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),

        // Help Panel
        if (_showHelpPanel)
          Positioned(
            top: 120,
            right: MediaQuery.of(context).size.width < 768 ? 20 : 20,
            child: _buildHelpPanel(),
          ),

          // Results panel toggle button (for mobile)
          if (_plantShops.isNotEmpty && MediaQuery.of(context).size.width < 768)
            Positioned(
              top: 200,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: () {
                  if (_showResultsPanel) {
                    _hideResultsPanel();
                  } else {
                    setState(() {
                      _showResultsPanel = true;
                    });
                    _panelAnimationController.forward();
                  }
                },
                backgroundColor: AppColors.primaryGreen,
                child: Icon(
                  _showResultsPanel ? Icons.list : Icons.list,
                  color: Colors.white,
                ),
              ),
            ),

          // Bottom info card (only show when results panel is hidden or on mobile)
          if (_markers.isNotEmpty && (!_showResultsPanel || MediaQuery.of(context).size.width < 768))
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_florist, color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Nearby Plant Shops',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        Spacer(),
                        if (MediaQuery.of(context).size.width < 768)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showResultsPanel = true;
                              });
                              _panelAnimationController.forward();
                            },
                            child: Text(
                              'View List',
                              style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Found ${_markers.length} plant shops • Tap markers for details${!_isUserLoggedIn ? ' • Log in to save favorites' : ' • ${_favoriteShopIds.length} favorites saved'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
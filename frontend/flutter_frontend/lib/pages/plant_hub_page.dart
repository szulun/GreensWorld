import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../widgets/navbar_home.dart';
import '../widgets/theme.dart';

class PlantHubPage extends StatefulWidget {
  const PlantHubPage({super.key});

  @override
  State<PlantHubPage> createState() => _PlantHubPageState();
}

class _PlantHubPageState extends State<PlantHubPage> {
  int _selectedIndex = 0; // 0: Available, 1: My Listings, 2: Requests
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  User? _currentUser;
  bool _isLoading = true;

  // Real data from Firestore
  List<PlantListing> _availablePlants = [];
  List<PlantListing> _myListings = [];
  List<SwapRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_currentUser == null) return;

    try {
      setState(() => _isLoading = true);

      // Load available plants
      final availableSnapshot = await _firestore
          .collection('plant_listings')
          .where('status', isEqualTo: 'available')
          .orderBy('datePosted', descending: true)
          .get();

      _availablePlants = availableSnapshot.docs.map((doc) {
        final data = doc.data();
        return PlantListing.fromFirestore(doc);
      }).toList();

      // Load my listings
      final myListingsSnapshot = await _firestore
          .collection('plant_listings')
          .where('userId', isEqualTo: _currentUser!.uid)
          .orderBy('datePosted', descending: true)
          .get();

      _myListings = myListingsSnapshot.docs.map((doc) {
        return PlantListing.fromFirestore(doc);
      }).toList();

      // Load swap requests
      final requestsSnapshot = await _firestore
          .collection('swap_requests')
          .where('toUserId', isEqualTo: _currentUser!.uid)
          .orderBy('dateRequested', descending: true)
          .get();

      _requests = requestsSnapshot.docs.map((doc) {
        final data = doc.data();
        return SwapRequest.fromFirestore(doc);
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NavbarHome(),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceMedium,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.swap_horiz, size: 40, color: AppColors.primaryGreen),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plant Hub',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      Text(
                        'Exchange plants and connect with fellow enthusiasts',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddListingDialog(),
                  icon: Icon(Icons.add, color: AppColors.surfaceLight),
                  label: Text(
                    'Add Plant',
                    style: TextStyle(color: AppColors.surfaceLight),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.surfaceLight,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMedium,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildTab('Available', 0),
                _buildTab('My Listings', 1),
                _buildTab('Requests', 2),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.surfaceLight : AppColors.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildAvailablePlants();
      case 1:
        return _buildMyListings();
      case 2:
        return _buildRequests();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAvailablePlants() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7, // More compact card
      ),
      itemCount: _availablePlants.length,
      itemBuilder: (context, index) {
        final plant = _availablePlants[index];
        return _buildPlantCard(plant, showRequestButton: true);
      },
    );
  }

  Widget _buildMyListings() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7, // More compact card
      ),
      itemCount: _myListings.length,
      itemBuilder: (context, index) {
        final plant = _myListings[index];
        return _buildPlantCard(plant, showRequestButton: false);
      },
    );
  }

  Widget _buildRequests() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildPlantCard(PlantListing plant, {required bool showRequestButton}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo display area - square design
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 1.0, // Perfect square
              child: plant.images.isNotEmpty
                  ? Stack(
                      children: [
                        // Main photo
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(plant.images.first),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Photo count indicator
                        if (plant.images.length > 1)
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
                                '+${plant.images.length - 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        // Tap to view all photos button
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showPhotoGallery(plant),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMedium,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_florist,
                            size: 60,
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No Photo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Content - optimized for square layout
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and status row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        plant.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Edit and delete buttons (only shown in My Listings)
                    if (!showRequestButton) ...[
                      IconButton(
                        onPressed: () => _showEditPlantDialog(plant),
                        icon: Icon(
                          Icons.edit,
                          color: AppColors.primaryGreen,
                          size: 18,
                        ),
                        tooltip: 'Edit',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(28, 28),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _showDeletePlantDialog(plant),
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade400,
                          size: 18,
                        ),
                        tooltip: 'Delete',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(28, 28),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Description
                Text(
                  plant.description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMedium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // User and location info
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: AppColors.textMedium),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        plant.owner,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMedium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.textMedium),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        plant.location,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMedium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Exchange requirements
                Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 14, color: AppColors.textMedium),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'Wants: ${plant.wantsInReturn}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMedium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Buttons
                if (showRequestButton)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showRequestDialog(plant),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.surfaceLight,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Request Swap',
                        style: TextStyle(
                          color: AppColors.surfaceLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(SwapRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.plantName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(request.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
        child: Text(
                    request.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'From: ${request.fromUser}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              request.message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequest(request.id, 'accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: AppColors.surfaceLight,
                    ),
                    child: Text(
                      'Accept',
                      style: TextStyle(color: AppColors.surfaceLight),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequest(request.id, 'decline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      foregroundColor: AppColors.surfaceLight,
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(color: AppColors.surfaceLight),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'excellent':
        return AppColors.successGreen;
      case 'good':
        return AppColors.warningYellow;
      case 'fair':
        return AppColors.errorRed;
      default:
        return AppColors.textLight;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warningYellow;
      case 'accepted':
        return AppColors.successGreen;
      case 'declined':
        return AppColors.errorRed;
      default:
        return AppColors.textLight;
    }
  }

  void _showAddListingDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController wantsInReturnController = TextEditingController();
    String selectedCondition = 'Excellent';
    String selectedLocation = 'Downtown';
    List<String> selectedImages = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Add New Plant',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Plant Name',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCondition,
                  decoration: InputDecoration(
                    labelText: 'Plant Condition',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                  items: ['Excellent', 'Good', 'Fair'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      selectedCondition = newValue;
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLocation,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                  items: ['Downtown', 'Westside', 'Eastside', 'Northside', 'Southside'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      selectedLocation = newValue;
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Photo upload area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plant Photos',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                                              if (selectedImages.isEmpty)
                          GestureDetector(
                            onTap: () => _showImagePickerDialog(context, selectedImages),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMedium,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.3),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 32,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Photo',
                                  style: GoogleFonts.inter(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: selectedImages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == selectedImages.length) {
                              // Add more photos button
                              return GestureDetector(
                                onTap: () => _showImagePickerDialog(context, selectedImages),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMedium,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primaryGreen.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              );
                            }
                            // Display selected photos
                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(selectedImages[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      selectedImages.removeAt(index);
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
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
                const SizedBox(height: 16),
                TextField(
                  controller: wantsInReturnController,
                  decoration: InputDecoration(
                    labelText: 'What do you want in return?',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                ),
              ],
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
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                  final newPlant = PlantListing(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    description: descriptionController.text,
                    images: selectedImages.isNotEmpty ? selectedImages : ['assets/images/nanolotus.png'],
                    owner: _currentUser!.uid,
                    location: selectedLocation,
                    condition: selectedCondition,
                    wantsInReturn: wantsInReturnController.text.isNotEmpty 
                        ? wantsInReturnController.text 
                        : 'Any interesting plants',
                    datePosted: DateTime.now(),
                    status: 'available',
                  );
                  
                  _uploadImagesToStorage(selectedImages).then((urls) {
                    if (urls.isNotEmpty) {
                      newPlant.images = urls;
                      _addPlantToFirestore(newPlant);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Failed to upload photos'),
                          backgroundColor: AppColors.warningYellow,
                        ),
                      );
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Please fill in all required fields'),
                      backgroundColor: AppColors.warningYellow,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.surfaceLight,
              ),
              child: Text(
                'Add Plant',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRequestDialog(PlantListing plant) {
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Request Exchange',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requesting: ${plant.name}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Owner: ${plant.owner}',
                style: GoogleFonts.inter(
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message to owner',
                  labelStyle: TextStyle(color: AppColors.textMedium),
                  hintText: 'Tell them what you can offer in exchange...',
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
              onPressed: () {
                if (messageController.text.isNotEmpty) {
                  final newRequest = SwapRequest(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    fromUser: _currentUser!.uid,
                    plantName: plant.name,
                    message: messageController.text,
                    status: 'Pending',
                    dateRequested: DateTime.now(),
                    toUserId: plant.owner,
                  );
                  
                  _addRequestToFirestore(newRequest);
                  
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Exchange request sent for ${plant.name}!'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Please enter a message'),
                      backgroundColor: AppColors.warningYellow,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.surfaceLight,
              ),
              child: Text(
                'Send Request',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleRequest(String requestId, String action) {
    setState(() {
      final requestIndex = _requests.indexWhere((req) => req.id == requestId);
      if (requestIndex != -1) {
        _requests[requestIndex] = SwapRequest(
          id: _requests[requestIndex].id,
          fromUser: _requests[requestIndex].fromUser,
          plantName: _requests[requestIndex].plantName,
          message: _requests[requestIndex].message,
          status: action == 'accept' ? 'Accepted' : 'Declined',
          dateRequested: _requests[requestIndex].dateRequested,
          toUserId: _requests[requestIndex].toUserId,
        );
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Request ${action == 'accept' ? 'accepted' : 'declined'}!'),
        backgroundColor: action == 'accept' ? AppColors.successGreen : Colors.orange.shade600,
      ),
    );
  }

  // Photo picker dialog
  void _showImagePickerDialog(BuildContext context, List<String> selectedImages) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Add Photo',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primaryGreen),
                title: Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.gallery, selectedImages);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primaryGreen),
                title: Text('Take a Photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.camera, selectedImages);
                },
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
          ],
        );
      },
    );
  }

  // Show photo gallery
  void _showPhotoGallery(PlantListing plant) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Title bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plant.name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Photo display
                Expanded(
                  child: PageView.builder(
                    itemCount: plant.images.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(plant.images[index]),
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Photo indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: plant.images.asMap().entries.map((entry) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.key == 0 
                              ? AppColors.primaryGreen 
                              : AppColors.textLight,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Select photo
  Future<void> _pickImage(ImageSource source, List<String> selectedImages) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        if (kIsWeb) {
          // For web, upload directly to Firebase Storage
          final String imageUrl = await _uploadImageToStorage(image);
          setState(() {
            selectedImages.add(imageUrl);
          });
        } else {
          // For mobile, use file path temporarily
          setState(() {
            selectedImages.add(image.path);
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Photo added successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to add photo: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  // Upload single image to Firebase Storage
  Future<String> _uploadImageToStorage(XFile image) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      print('Starting image upload for user: ${user.uid}');
      print('Image name: ${image.name}');
      print('Image path: ${image.path}');
      
      final bytes = await image.readAsBytes();
      print('Read ${bytes.length} bytes from image');
      
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'plant_images/${user.uid}/plant_$timestamp.jpg';
      print('Uploading to path: $fileName');
      
      final storage = FirebaseStorage.instance;
      final storageRef = storage.ref().child(fileName);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('Starting upload task...');
      final uploadTask = storageRef.putData(bytes, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      final snapshot = await uploadTask;
      print('Upload completed. Bytes transferred: ${snapshot.bytesTransferred}');
      
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload images to Firebase Storage (for multiple images)
  Future<List<String>> _uploadImagesToStorage(List<String> imagePaths) async {
    final List<String> uploadedUrls = [];
    
    for (String path in imagePaths) {
      try {
        if (path.startsWith('http')) {
          // Already a URL, no need to upload
          uploadedUrls.add(path);
        } else if (kIsWeb) {
          // Web platform - should already be URLs
          uploadedUrls.add(path);
        } else {
          // Mobile platform - upload file
          final file = File(path);
          final User? user = FirebaseAuth.instance.currentUser;
          if (user == null) continue;
          
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String fileName = 'plant_images/${user.uid}/plant_$timestamp.jpg';
          
          final storage = FirebaseStorage.instance;
          final storageRef = storage.ref().child(fileName);
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          
          final uploadTask = storageRef.putFile(file, metadata);
          final snapshot = await uploadTask;
          final String downloadUrl = await snapshot.ref.getDownloadURL();
          
          uploadedUrls.add(downloadUrl);
        }
      } catch (e) {
        print('Error uploading image $path: $e');
      }
    }
    
    return uploadedUrls;
  }

  // Add plant to Firestore
  Future<void> _addPlantToFirestore(PlantListing plant) async {
    try {
      await _firestore.collection('plant_listings').doc(plant.id).set(plant.toJson());
      setState(() {
        _availablePlants.add(plant);
        _myListings.add(plant); // Assuming a plant can be both available and my listing
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${plant.name} added successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      print('Error adding plant to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to add plant: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  // Add swap request to Firestore
  Future<void> _addRequestToFirestore(SwapRequest request) async {
    try {
      await _firestore.collection('swap_requests').doc(request.id).set(request.toJson());
      setState(() {
        _requests.add(request);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Exchange request sent for ${request.plantName}!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      print('Error adding request to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send request: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  // Delete plant listing dialog
  void _showDeletePlantDialog(PlantListing plant) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Plant Listing',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${plant.name}"? This action cannot be undone.',
            style: GoogleFonts.inter(
              color: AppColors.textMedium,
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
            ElevatedButton(
              onPressed: () {
                // Remove plant from both lists
                setState(() {
                  _myListings.removeWhere((p) => p.id == plant.id);
                  _availablePlants.removeWhere((p) => p.id == plant.id);
                });
                
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗑️ "${plant.name}" has been deleted'),
                    backgroundColor: Colors.orange.shade600,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // Edit plant listing dialog
  void _showEditPlantDialog(PlantListing plant) {
    final TextEditingController nameController = TextEditingController(text: plant.name);
    final TextEditingController descriptionController = TextEditingController(text: plant.description);
    final TextEditingController wantsInReturnController = TextEditingController(text: plant.wantsInReturn);
    String selectedCondition = plant.condition;
    String selectedLocation = plant.location;
    List<String> selectedImages = List.from(plant.images);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Edit Plant Listing',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Plant Name',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCondition,
                  decoration: InputDecoration(
                    labelText: 'Plant Condition',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                  items: ['Excellent', 'Good', 'Fair'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      selectedCondition = newValue;
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLocation,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                  items: ['Downtown', 'Westside', 'Eastside', 'Northside', 'Southside'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      selectedLocation = newValue;
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Photo upload area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plant Photos',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                                              if (selectedImages.isEmpty)
                          GestureDetector(
                            onTap: () => _showImagePickerDialog(context, selectedImages),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMedium,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.3),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 32,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Photo',
                                  style: GoogleFonts.inter(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: selectedImages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == selectedImages.length) {
                              // Add more photos button
                              return GestureDetector(
                                onTap: () => _showImagePickerDialog(context, selectedImages),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMedium,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primaryGreen.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              );
                            }
                            // Display selected photos
                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(selectedImages[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      selectedImages.removeAt(index);
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
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
                const SizedBox(height: 16),
                TextField(
                  controller: wantsInReturnController,
                  decoration: InputDecoration(
                    labelText: 'What do you want in return?',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                ),
              ],
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
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                  final updatedPlant = PlantListing(
                    id: plant.id,
                    name: nameController.text,
                    description: descriptionController.text,
                    images: selectedImages.isNotEmpty ? selectedImages : plant.images,
                    owner: plant.owner,
                    location: selectedLocation,
                    condition: selectedCondition,
                    wantsInReturn: wantsInReturnController.text.isNotEmpty 
                        ? wantsInReturnController.text 
                        : plant.wantsInReturn,
                    datePosted: plant.datePosted,
                    status: plant.status, // Keep original status
                  );
                  
                  _uploadImagesToStorage(selectedImages).then((urls) {
                    if (urls.isNotEmpty) {
                      updatedPlant.images = urls;
                      _updatePlantInFirestore(updatedPlant);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Failed to upload photos'),
                          backgroundColor: AppColors.warningYellow,
                        ),
                      );
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Please fill in all required fields'),
                      backgroundColor: AppColors.warningYellow,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.surfaceLight,
              ),
              child: Text(
                'Save Changes',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // Update plant in Firestore
  Future<void> _updatePlantInFirestore(PlantListing plant) async {
    try {
      await _firestore.collection('plant_listings').doc(plant.id).update(plant.toJson());
      setState(() {
        final index = _myListings.indexWhere((p) => p.id == plant.id);
        if (index != -1) {
          _myListings[index] = plant;
        }
        final indexAvailable = _availablePlants.indexWhere((p) => p.id == plant.id);
        if (indexAvailable != -1) {
          _availablePlants[indexAvailable] = plant;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${plant.name} updated successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      print('Error updating plant in Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to update plant: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}

class PlantListing {
  final String id;
  final String name;
  final String description;
  List<String> images; // Changed from final to allow updates
  final String owner;
  final String location;
  final String condition;
  final String wantsInReturn;
  final DateTime datePosted;
  final String status;

  PlantListing({
    required this.id,
    required this.name,
    required this.description,
    required this.images,
    required this.owner,
    required this.location,
    required this.condition,
    required this.wantsInReturn,
    required this.datePosted,
    required this.status,
  });

  factory PlantListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlantListing(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      owner: data['owner'] ?? '',
      location: data['location'] ?? '',
      condition: data['condition'] ?? '',
      wantsInReturn: data['wantsInReturn'] ?? '',
      datePosted: (data['datePosted'] as Timestamp).toDate(),
      status: data['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'images': images,
      'owner': owner,
      'location': location,
      'condition': condition,
      'wantsInReturn': wantsInReturn,
      'datePosted': datePosted,
      'status': status,
    };
  }
}

class SwapRequest {
  final String id;
  final String fromUser;
  final String plantName;
  final String message;
  final String status;
  final DateTime dateRequested;
  final String toUserId; // Added for the recipient

  SwapRequest({
    required this.id,
    required this.fromUser,
    required this.plantName,
    required this.message,
    required this.status,
    required this.dateRequested,
    required this.toUserId,
  });

  factory SwapRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SwapRequest(
      id: doc.id,
      fromUser: data['fromUser'] ?? '',
      plantName: data['plantName'] ?? '',
      message: data['message'] ?? '',
      status: data['status'] ?? 'Pending',
      dateRequested: (data['dateRequested'] as Timestamp).toDate(),
      toUserId: data['toUserId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUser': fromUser,
      'plantName': plantName,
      'message': message,
      'status': status,
      'dateRequested': dateRequested,
      'toUserId': toUserId,
    };
  }
}
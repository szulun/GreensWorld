import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/navbar_home.dart';
import '../services/profile_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';

class PlantProfilePage extends StatefulWidget {
  const PlantProfilePage({super.key});

  @override
  State<PlantProfilePage> createState() => _PlantProfilePageState();
}

class _PlantProfilePageState extends State<PlantProfilePage> {
  late Future<UserProfile> _futureProfile;
  String? _pendingAvatarDataUrl; // preview & payload
  final CropController _cropController = CropController();
  Uint8List? _rawPickedImage;

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
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(profile),
                const SizedBox(height: 16),
                _buildStats(profile),
                const SizedBox(height: 16),
                _buildMyPlants(profile),
                const SizedBox(height: 16),
                _buildRecentActivity(profile),
              ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
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
                    Text(p.name, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF2E7D32))),
                    const SizedBox(height: 4),
                    Row(children: [const Text('📍 '), Text(p.location, style: GoogleFonts.inter(color: Colors.grey.shade700))]),
                    const SizedBox(height: 12),
                    Text(p.bio, style: GoogleFonts.inter(color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: _buildBadges(p.badges)),
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
              child: const Text('Edit Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserProfile p) {
    final avatarDataUrl = _pendingAvatarDataUrl ?? p.avatarUrl;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 96,
            height: 96,
            color: const Color(0xFF81C784),
            alignment: Alignment.center,
            child: (avatarDataUrl == null || avatarDataUrl.isEmpty)
                ? Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : 'A',
                    style: GoogleFonts.poppins(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700),
                  )
                : Image.memory(
                    base64Decode(avatarDataUrl.split(',').last),
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _pickAvatar,
          icon: const Icon(Icons.photo_camera, size: 18),
          label: const Text('Change avatar'),
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (img == null) return;
      _rawPickedImage = await img.readAsBytes();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Crop avatar'),
          content: SizedBox(
            width: 360,
            height: 360,
            child: Crop(
              controller: _cropController,
              image: _rawPickedImage!,
              aspectRatio: 1,
              withCircleUi: false,
              initialSize: 0.9,
              baseColor: Colors.black87,
              maskColor: Colors.black38,
              onCropped: (cropped) {
                final dataUrl = 'data:image/png;base64,${base64Encode(cropped)}';
                setState(() => _pendingAvatarDataUrl = dataUrl);
                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () { _cropController.crop(); },
              child: const Text('Apply'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  List<Widget> _buildBadges(List<String> badges) {
    Color colorFor(String b) {
      switch (b.toLowerCase()) {
        case 'verified':
          return const Color(0xFFE3F2FD);
        case 'plant expert':
          return const Color(0xFFE8F5E8);
        case 'active trader':
          return const Color(0xFFFFF3E0);
        default:
          return Colors.grey.shade100;
      }
    }

    Color textColorFor(String b) {
      switch (b.toLowerCase()) {
        case 'verified':
          return const Color(0xFF1976D2);
        case 'plant expert':
          return const Color(0xFF2E7D32);
        case 'active trader':
          return const Color(0xFFF57C00);
        default:
          return Colors.black54;
      }
    }

    return badges
        .map((b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: colorFor(b), borderRadius: BorderRadius.circular(16)),
              child: Text(b, style: GoogleFonts.inter(color: textColorFor(b), fontWeight: FontWeight.w600, fontSize: 12)),
            ))
        .toList();
  }

  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF2E7D32))),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.inter(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(UserProfile p) {
    return Row(
      children: [
        _buildStatCard(p.successfulSwaps.toString(), 'Successful Swaps'),
        const SizedBox(width: 12),
        _buildStatCard(p.rating.toStringAsFixed(1), 'Rating'),
        const SizedBox(width: 12),
        _buildStatCard(p.communityHelps.toString(), 'Community Helps'),
        const SizedBox(width: 12),
        _buildStatCard(p.activePlants.toString(), 'Active Plants'),
      ],
    );
  }

  Widget _buildMyPlants(UserProfile p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Plants', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF2E7D32))),
              TextButton(onPressed: () {}, child: const Text('View All (23)')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: p.plants.map((pl) => _miniPlantCard(pl)).toList(),
          )
        ],
      ),
    );
  }

  Widget _miniPlantCard(PlantSummary pl) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pl.status.toLowerCase() == 'available' ? const Color(0xFF4CAF50) : Colors.transparent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pl.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(pl.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(pl.status, style: GoogleFonts.inter(fontSize: 12, color: pl.status.toLowerCase() == 'available' ? const Color(0xFF2E7D32) : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(UserProfile p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF2E7D32))),
          const SizedBox(height: 12),
          ...p.recentActivities.map((a) => _activityRow(a)),
        ],
      ),
    );
  }

  Widget _activityRow(ActivityItem a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: const Color(0xFFE8F5E8), child: Text(a.iconEmoji)),
          const SizedBox(width: 12),
          Expanded(child: Text(a.text, style: GoogleFonts.inter())),
          Text(a.timeAgo, style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(UserProfile p) async {
    final nameCtrl = TextEditingController(text: p.name);
    final locationCtrl = TextEditingController(text: p.location);
    final bioCtrl = TextEditingController(text: p.bio);

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
                const SizedBox(height: 12),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 12),
                TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
                const SizedBox(height: 12),
                if (_pendingAvatarDataUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(base64Decode(_pendingAvatarDataUrl!.split(',').last), height: 80),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Update backend profile
                  await ProfileService.updateProfile(
                    UserProfileUpdate(
                      displayName: nameCtrl.text.trim(),
                      location: locationCtrl.text.trim(),
                      bio: bioCtrl.text.trim(),
                      avatarUrl: _pendingAvatarDataUrl,
                    ),
                  );
                  // Also update Firebase display name for Navbar
                  await FirebaseAuth.instance.currentUser?.updateDisplayName(nameCtrl.text.trim());
                  await FirebaseAuth.instance.currentUser?.reload();
                  if (context.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (res == true && mounted) {
      setState(() {
        _futureProfile = ProfileService.fetchCurrentUserProfile();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }
} 
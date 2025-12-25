import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/navbar_home.dart';
import '../widgets/hero_section.dart';
import '../widgets/theme.dart'; 

const kFontFamily = 'Segoe UI, Calibri, Arial, Helvetica, sans-serif';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: const NavbarHome(), // ä½¿ç"¨æ›´æ–°çš„ NavbarHome
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Hero Section
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: isWide ? 64 : 32,
                horizontal: isWide ? 64 : 16,
              ),
              child: isWide
                  ? Stack(
                      children: [
                        // Background: Extended lotus flower video
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            height: 500,
                            width: double.infinity,
                            child: const HeroSection(showText: false),
                          ),
                        ),
                        // Foreground: Buttons positioned over the video
                        Positioned(
                          left: 64,
                          bottom: 64,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Updated Use GAIA Button
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => Navigator.pushNamed(context, '/ai-assistant'),
                                child: const Text('Use GAIA'),
                              ),
                              const SizedBox(height: 16),
                              // Updated Discovery Map Button
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/plant-shops-map');
                                },
                                child: const Text('Discovery Map'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Mobile layout
                        const SizedBox(height: 16),
                        // Resized video container for mobile
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            height: 350,
                            width: double.infinity,
                            child: const HeroSection(showText: false),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Updated buttons for mobile
                        Column(
                          children: [
                            SizedBox(
                              width: 200, // Fixed width for buttons
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => Navigator.pushNamed(context, '/ai-assistant'),
                                child: const Text('Use GAIA'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 200, // Fixed width for buttons
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/plant-shops-map');
                                },
                                child: const Text('Discovery Map'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            // Features Section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Features', style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w900, fontSize: 28, color: const Color(0xFF22223B))),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FeatureCard(
                            icon: Icons.local_florist,
                            title: 'Plant Swap',
                            description: 'Trade plants with local enthusiasts and grow your collection.',
                          ),
                          const SizedBox(width: 24),
                          _FeatureCard(
                            icon: Icons.smart_toy,
                            title: 'Ask GAIA',
                            description: 'AI-powered plant identification, diagnosis, and care guides.',
                          ),
                          const SizedBox(width: 24),
                          _FeatureCard(
                            icon: Icons.map,
                            title: 'Plant Shops',
                            description: 'Find local plant shops and nurseries near you.',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // Our Story Section
            const OurStorySection(),
            // Our Team Section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Our Team', style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w900, fontSize: 28, color: const Color(0xFF22223B))),
                  const SizedBox(height: 24),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TeamMemberCard(
                          name: 'Shawn Gibson',
                          role: 'Full Stack Engineer',
                          imagePath: 'assets/images/Shawn.jpeg',
                        ),
                        const SizedBox(width: 16),
                        _TeamMemberCard(
                          name: 'Andres Cuervo',
                          role: 'Full Stack Engineer',
                          imagePath: 'assets/images/Andres.png',
                        ),
                        const SizedBox(width: 16),
                        _TeamMemberCard(
                          name: 'Zoey Huang',
                          role: 'Full Stack Engineer',
                          imagePath: 'assets/images/Zoey.jpeg',
                        ),
                        const SizedBox(width: 16),
                        _TeamMemberCard(
                          name: 'Juliana Uribe',
                          role: 'Full Stack Engineer',
                          imagePath: 'assets/images/Juliana.png',
                        ),
                        const SizedBox(width: 16),
                        _TeamMemberCard(
                          name: 'Jason Nwaneti',
                          role: 'Full Stack Engineer',
                          imagePath: 'assets/images/Jason.png',
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              width: double.infinity,
              color: const Color(0xFF18332F),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Center(
                child: Text(
                  '© 2025 GreensWrld. All rights reserved.',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    color: const Color(0xFFCCCCCC),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 48, color: AppColors.primaryGreen),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontFamily: kFontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OurStorySection extends StatefulWidget {
  const OurStorySection({super.key});

  @override
  State<OurStorySection> createState() => _OurStorySectionState();
}

class _OurStorySectionState extends State<OurStorySection> {
  bool expanded = false;

  static const String storyIntro =
      "Every great change starts with a single idea, much like a mighty oak begins with a tiny acorn. At GreensWrld, our story began with a simple, yet profound, realization: the world needed a better way to connect with the green heartbeat of our planet. We saw fragmented knowledge, isolated growers, and missed opportunities for collective growth.";

  static const String storyRest =
      "\n\nWe envisioned a global canvas for growth, a place where passion for plants could blossom into tangible action. What if we could build a platform that was more than just an app? What if it was a community hub, a one-stop shop for every gardening necessity, every farming innovation, and every shared dream of a greener future? We imagined something akin to GitHub for agriculture, where ideas are cultivated, projects are shared, and collective wisdom truly flourishes.\n\nFrom this vision, GreensWrld was born. We set out to create a mobile-friendly, location-based platform that seamlessly connects you with local plant services, essential tools, and a vibrant network of fellow enthusiasts. Whether you're looking for a farmer's market, need tips for your home garden, or want to share your latest harvest, GreensWrld is designed to empower you.\n\nWe believe that by nurturing change one seed at a time, through education, community engagement, and accessible resources, we can cultivate a world where sustainable living isn't just a concept, but a shared reality. Join us in growing a greener, more connected world.";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'About GreensWrld',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Nurturing Change, One Seed at a Time',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                expanded ? storyIntro + storyRest : storyIntro,
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  color: Color(0xFF4A4E69),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => setState(() => expanded = !expanded),
                child: Text(
                  expanded ? 'Read Less' : 'Read More',
                  style: const TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.surfaceLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final String name;
  final String role;
  final String imagePath;
  
  const _TeamMemberCard({
    required this.name,
    required this.role,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120, // å¾ž 180 æ¸›å°åˆ° 120
          height: 120, // å¾ž 180 æ¸›å°åˆ° 120
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              imagePath,
              width: 120, // å¾ž 180 æ¸›å°åˆ° 120
              height: 120, // å¾ž 180 æ¸›å°åˆ° 120
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // å¦‚æžœåœ–ç‰‡åŠ è¼‰å¤±æ•—ï¼Œé¡¯ç¤ºé»˜èªåœ–æ¨™
                return Container(
                  width: 120, // å¾ž 180 æ¸›å°åˆ° 120
                  height: 120, // å¾ž 180 æ¸›å°åˆ° 120
                  color: AppColors.surfaceDark,
                  child: const Center(
                    child: Icon(Icons.person, color: AppColors.textLight, size: 48), // å¾ž 64 æ¸›å°åˆ° 48
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12), // å¾ž 16 æ¸›å°åˆ° 12
        Text(
          name,
          style: TextStyle(
            fontFamily: kFontFamily,
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 14, // å¾ž 16 æ¸›å°åˆ° 14
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          role,
          style: TextStyle(
            fontFamily: kFontFamily,
            color: AppColors.textMedium,
            fontWeight: FontWeight.w500,
            fontSize: 12, // å¾ž 14 æ¸›å°åˆ° 12
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
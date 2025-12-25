import 'package:flutter/material.dart';
import '../widgets/theme.dart';

const kFontFamily = 'Segoe UI, Calibri, Arial, Helvetica, sans-serif';

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
              Text(
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
              Text(
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
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  color: AppColors.textMedium,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
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

class TeamBox extends StatelessWidget {
  const TeamBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.textDark,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.person, color: Colors.white24, size: 64),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Coming Soon',
          style: TextStyle(
            fontFamily: kFontFamily,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
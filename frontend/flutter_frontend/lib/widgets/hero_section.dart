import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../widgets/theme.dart';

class HeroSection extends StatefulWidget {
  final bool showText;
  final double? customHeight;
  final double? customWidth;
  final BoxFit? videoFit; // Add video fit parameter
  final Alignment? videoAlignment; // Add video alignment parameter
  
  const HeroSection({
    super.key, 
    this.showText = true, 
    this.customHeight,
    this.customWidth,
    this.videoFit,
    this.videoAlignment,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/images/Masterpiece_8k.mp4')
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Determine dimensions based on context
    double videoHeight;
    double? videoWidth;
    
    if (widget.customHeight != null) {
      videoHeight = widget.customHeight!;
    } else if (!widget.showText) {
      // When showText is false (like on homepage), use more reasonable sizes
      videoHeight = isWide ? 400 : 300;
    } else {
      // Default height when showing text
      videoHeight = isWide ? 500 : 400;
    }
    
    if (widget.customWidth != null) {
      videoWidth = widget.customWidth!;
    } else if (!widget.showText) {
      // When showText is false, constrain width for better control
      videoWidth = isWide ? 500 : 350;
    }
    
    return Container(
      height: videoHeight,
      width: videoWidth ?? double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: !widget.showText ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Video background
            if (_controller.value.isInitialized)
              Positioned.fill(
                child: FittedBox(
                  fit: widget.videoFit ?? BoxFit.cover,
                  alignment: widget.videoAlignment ?? const Alignment(0, -0.7),
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            // Loading indicator when video is not ready
            if (!_controller.value.isInitialized)
              Container(
                color: AppColors.surfaceDark,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            // Overlay for text visibility (lighter when no text)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceDark.withOpacity(widget.showText ? 0.6 : 0.2),
                      AppColors.surfaceDark.withOpacity(widget.showText ? 0.4 : 0.05),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // Content (conditionally show text)
            if (widget.showText)
              Align(
                alignment: isWide ? Alignment.centerLeft : Alignment.center,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 64 : 24,
                    vertical: isWide ? 0 : 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome to GreensWrld',
                          style: TextStyle(
                            fontSize: isWide ? 48 : 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.surfaceCream,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                                color: AppColors.surfaceDark,
                              ),
                            ],
                          ),
                          textAlign: isWide ? TextAlign.left : TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your one-stop platform for plant enthusiasts',
                          style: TextStyle(
                            fontSize: isWide ? 24 : 20,
                            color: AppColors.surfaceCream,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                                color: AppColors.surfaceDark.withOpacity(0.5),
                              ),
                            ],
                          ),
                          textAlign: isWide ? TextAlign.left : TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: isWide ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppColors.surfaceCream,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.surfaceCream),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                'Learn More',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppColors.surfaceCream,
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
      ),
    );
  }
}
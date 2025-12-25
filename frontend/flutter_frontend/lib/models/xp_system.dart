import 'package:flutter/material.dart';

class XPSystem {
  // Level definitions
  static const Map<int, String> levels = {
    0: 'Beginner',
    100: 'Green Thumb',
    300: 'Enthusiast',
    600: 'Expert',
    1000: 'Master',
    2000: 'Legend',
    5000: 'Sage',
    10000: 'Guardian'
  };

  // Level icons
  static const Map<String, IconData> levelIcons = {
    'Beginner': Icons.local_florist,
    'Green Thumb': Icons.eco,
    'Enthusiast': Icons.nature,
    'Expert': Icons.forest,
    'Master': Icons.park,
    'Legend': Icons.landscape,
    'Sage': Icons.agriculture,
    'Guardian': Icons.auto_awesome
  };

  // Level colors
  static const Map<String, Color> levelColors = {
    'Beginner': Colors.grey,
    'Green Thumb': Colors.green,
    'Enthusiast': Colors.lightGreen,
    'Expert': Colors.teal,
    'Master': Colors.blue,
    'Legend': Colors.purple,
    'Sage': Colors.orange,
    'Guardian': Colors.red
  };

  // Get level based on XP
  static String getLevel(int xp) {
    final sortedLevels = levels.keys.toList()..sort((a, b) => b.compareTo(a));
    for (int xpRequired in sortedLevels) {
      if (xp >= xpRequired) {
        return levels[xpRequired]!;
      }
    }
    return 'Plant Beginner';
  }

  // Get XP required for next level
  static int getNextLevelXP(int currentXP) {
    for (int xpRequired in levels.keys) {
      if (currentXP < xpRequired) {
        return xpRequired;
      }
    }
    return currentXP; // Already at max level
  }

  // Get XP required for current level
  static int getCurrentLevelXP(int currentXP) {
    String currentLevel = getLevel(currentXP);
    for (int xpRequired in levels.keys) {
      if (levels[xpRequired] == currentLevel) {
        return xpRequired;
      }
    }
    return 0;
  }

  // Calculate XP progress percentage
  static double getProgressPercentage(int currentXP) {
    int currentLevelXP = getCurrentLevelXP(currentXP);
    int nextLevelXP = getNextLevelXP(currentXP);
    
    if (nextLevelXP == currentLevelXP) {
      return 1.0; // Already at max level
    }
    
    int xpInCurrentLevel = currentXP - currentLevelXP;
    int xpNeededForNextLevel = nextLevelXP - currentLevelXP;
    
    return xpInCurrentLevel / xpNeededForNextLevel;
  }

  // XP earning rules
  static Map<String, int> getXPRules() {
    return {
      'Post': 10,
      'Quality Post': 15,
      'Multi-Image Post': 20,
      'Like': 1,
      'Receive Like': 2,
      'Comment': 3,
      'Receive Comment': 5,
      '7-Day Login Streak': 50,
      'Post Milestone': 100,
      'Plant Collection': 200,
    };
  }

  // Detailed XP rules explanation
  static List<Map<String, dynamic>> getXPRulesDetails() {
    return [
      {
        'action': 'Post',
        'xp': 10,
        'description': 'Share plant photos and tips in Community page',
        'icon': Icons.add_a_photo,
      },
      {
        'action': 'Quality Post',
        'xp': 15,
        'description': 'Post with detailed plant care descriptions',
        'icon': Icons.description,
      },
      {
        'action': 'Multi-Image Post',
        'xp': 20,
        'description': 'Post with 3 or more plant photos',
        'icon': Icons.photo_library,
      },
      {
        'action': 'Like',
        'xp': 1,
        'description': 'Like other users\' posts',
        'icon': Icons.favorite,
      },
      {
        'action': 'Receive Like',
        'xp': 2,
        'description': 'Your post gets liked by other users',
        'icon': Icons.favorite_border,
      },
      {
        'action': 'Comment',
        'xp': 3,
        'description': 'Leave comments on other users\' posts',
        'icon': Icons.chat_bubble,
      },
      {
        'action': 'Receive Comment',
        'xp': 5,
        'description': 'Your post receives comments from other users',
        'icon': Icons.chat_bubble_outline,
      },
      {
        'action': 'Login Streak',
        'xp': 50,
        'description': 'Login for 7 consecutive days',
        'icon': Icons.calendar_today,
      },
      {
        'action': 'Post Milestone',
        'xp': 100,
        'description': 'Reach posting milestones (10th, 50th, 100th post)',
        'icon': Icons.emoji_events,
      },
      {
        'action': 'Plant Collection',
        'xp': 200,
        'description': 'Collect different plant species (5, 10, 20 types)',
        'icon': Icons.eco,
      },
    ];
  }
}

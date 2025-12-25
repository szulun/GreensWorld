import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'config/env_config.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/plant_hub_page.dart';
import 'pages/social_feed_page.dart';
import 'pages/care_guides_page.dart';
import 'pages/ai_assistant_page.dart';
import 'pages/plant_shops_map_page.dart';
import 'pages/profile_page.dart';
import 'pages/avatar_selection_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Validate environment configuration
  EnvConfig.validateEnvironment();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GreensWrldApp());
}

class GreensWrldApp extends StatelessWidget {
  const GreensWrldApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 定義主要顏色
    const primaryColor = Color(0xFF8FADBB);  // 淺藍色
    const backgroundColor = Color(0xFFDFD8CD);  // 米白色
    const accentColor = Color(0xFF5E8AA6);  // 深藍色
    const secondaryColor = Color(0xFFB6C0B8);  // 淺綠灰
    const tertiaryColor = Color(0xFF759581);  // 深綠色

    return MaterialApp(
      title: 'GreensWrld',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 基本顏色設置
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: accentColor,
          tertiary: tertiaryColor,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
        ),

        // 卡片主題
        cardColor: Colors.white,
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),

        // 按鈕主題
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // 輸入框主題
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: secondaryColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: secondaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accentColor, width: 2),
          ),
        ),

        // 文字主題
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'HelveticaNeue',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5E8AA6),
          ),
          headlineLarge: TextStyle(
            fontFamily: 'HelveticaNeue',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5E8AA6),
          ),
          headlineMedium: TextStyle(
            fontFamily: 'HelveticaNeue',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5E8AA6),
          ),
          titleLarge: TextStyle(
            fontFamily: 'HelveticaNeue',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5E8AA6),
          ),
          bodyLarge: TextStyle(
            fontFamily: 'HelveticaNeue',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'HelveticaNeue',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
            height: 1.5,
          ),
        ),

        // AppBar 主題
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF5E8AA6),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'HelveticaNeue',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5E8AA6),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/plant-hub': (context) => const PlantHubPage(),
        '/social-feed': (context) => const SocialFeedPage(),
        '/care-guides': (context) => const CareGuidesPage(),
        '/ai-assistant': (context) => const AiAssistantPage(),
        '/plant-shops-map': (context) => const PlantShopsMapPage(),
        '/profile': (context) => const ProfilePage(),
        '/avatar-selection': (context) => const AvatarSelectionPage(),
      },
    );
  }
}

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EnvConfig {
  // For web, we need to define these directly or use a different approach
  static String get apiUrl {
    if (kIsWeb) {
      // For web, try to get from compile-time constants first, then fallback
      return const String.fromEnvironment('API_URL', 
        defaultValue: 'http://localhost:3001/api');
    } else {
      // For mobile, use dotenv
      return dotenv.env['API_URL'] ?? 'http://localhost:3001/api';
    }
  }

  static String get googleMapsApiKey {
    if (kIsWeb) {
      // For web, try to get from compile-time constants first, then fallback
      return const String.fromEnvironment('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY', 
        defaultValue: '');
    } else {
      // For mobile, use dotenv
      return dotenv.env['NEXT_PUBLIC_GOOGLE_MAPS_API_KEY'] ?? '';
    }
  }

  static bool get isDevelopment {
    if (kIsWeb) {
      return const String.fromEnvironment('ENVIRONMENT', 
        defaultValue: 'development') == 'development';
    } else {
      return dotenv.env['ENVIRONMENT'] == 'development' || 
             dotenv.env['ENVIRONMENT'] == null;
    }
  }

  static bool get isProduction {
    if (kIsWeb) {
      return const String.fromEnvironment('ENVIRONMENT') == 'production';
    } else {
      return dotenv.env['ENVIRONMENT'] == 'production';
    }
  }

  // Alternative method: Load from web-specific config
  static String get apiUrlWeb {
    // You can also define these in web/index.html as global variables
    // and access them here if needed
    return 'http://localhost:3001/api'; // Fallback for web
  }

  // Validate that all required environment variables are loaded
  static bool validateEnvironment() {
    if (kIsWeb) {
      // For web, check compile-time constants
      final apiUrl = const String.fromEnvironment('API_URL');
      final mapsKey = const String.fromEnvironment('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY');
      
      if (apiUrl.isEmpty) {
        print('⚠️ Missing web environment variable: API_URL');
        print('💡 Using fallback: http://localhost:3001/api');
      }
      
      if (mapsKey.isEmpty) {
        print('⚠️ Missing web environment variable: NEXT_PUBLIC_GOOGLE_MAPS_API_KEY');
        print('💡 Please run: ./run_dev.sh or ./build_web.sh');
        print('💡 Or use: flutter run -d chrome --dart-define=NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_key');
      }
      
      print('✅ Web environment configuration loaded');
      return true; // Always return true for web with fallbacks
    } else {
      // Original mobile validation
      final requiredVars = ['API_URL', 'NEXT_PUBLIC_GOOGLE_MAPS_API_KEY'];
      final missingVars = <String>[];

      for (final varName in requiredVars) {
        final value = dotenv.env[varName];
        if (value == null || value.isEmpty) {
          missingVars.add(varName);
        }
      }

      if (missingVars.isNotEmpty) {
        print('⚠️ Missing environment variables: ${missingVars.join(', ')}');
        return false;
      }

      print('✅ All environment variables loaded successfully');
      return true;
    }
  }
}
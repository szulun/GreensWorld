import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // 從環境變數獲取 API URL，如果沒有設置則使用默認值
  static String get baseUrl => dotenv.env['API_URL'] ?? 'http://localhost:5001/api';

  // 測試與後端的連接
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/test'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to connect: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // 獲取所有植物
  static Future<List<Map<String, dynamic>>> getPlants() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/plants'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['plants']);
      } else {
        throw Exception('Failed to load plants: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error occurred: $e');
    }
  }

  // 添加新植物
  static Future<Map<String, dynamic>> addPlant(Map<String, dynamic> plantData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/plants'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(plantData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add plant: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error occurred: $e');
    }
  }
} 
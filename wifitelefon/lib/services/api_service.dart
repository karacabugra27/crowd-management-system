import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Backend URL (Android Emülatör için localhost 10.0.2.2'dir. Gerçek cihazda backendin IP'si girilmelidir.)
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<bool> sendOccupancyData(
    String areaId,
    int occupancyCount,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/occupancy/ingest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'area_id': areaId,
          'count':
              occupancyCount, // README'deki backend /occupancy/ingest formatına uygun
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      print('API Error: $e');
      return false;
    }
  }
}

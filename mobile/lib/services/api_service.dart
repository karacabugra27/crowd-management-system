import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Use localhost for web, 10.0.2.2 for Android emulator
final String kApiBase = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
// Use 'http://localhost:8000' for web or iOS simulator

class AreaModel {
  final int id;
  final String name;
  final String shortName;
  final String building;
  final String icon;
  final int capacity;
  final double? lat;
  final double? lng;

  const AreaModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.building,
    required this.icon,
    required this.capacity,
    this.lat,
    this.lng,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) => AreaModel(
        id:        json['id'],
        name:      json['name'],
        shortName: json['short_name'],
        building:  json['building'],
        icon:      json['icon'],
        capacity:  json['capacity'],
        lat:       (json['lat'] as num?)?.toDouble(),
        lng:       (json['lng'] as num?)?.toDouble(),
      );
}

class OccupancyData {
  final int areaId;
  final String areaName;
  final String shortName;
  final String building;
  final String icon;
  final int capacity;
  final int deviceCount;
  final double occupancyPct;
  final String status;
  final String color;
  final DateTime lastUpdated;

  const OccupancyData({
    required this.areaId,
    required this.areaName,
    required this.shortName,
    required this.building,
    required this.icon,
    required this.capacity,
    required this.deviceCount,
    required this.occupancyPct,
    required this.status,
    required this.color,
    required this.lastUpdated,
  });

  factory OccupancyData.fromJson(Map<String, dynamic> json) => OccupancyData(
        areaId:       json['area_id'],
        areaName:     json['area_name'],
        shortName:    json['short_name'],
        building:     json['building'],
        icon:         json['icon'],
        capacity:     json['capacity'],
        deviceCount:  json['device_count'],
        occupancyPct: (json['occupancy_pct'] as num).toDouble(),
        status:       json['status'],
        color:        json['color'],
        lastUpdated:  DateTime.parse(json['last_updated']),
      );
}

class HistoryPoint {
  final DateTime timestamp;
  final int deviceCount;
  final double occupancyPct;

  const HistoryPoint({
    required this.timestamp,
    required this.deviceCount,
    required this.occupancyPct,
  });

  factory HistoryPoint.fromJson(Map<String, dynamic> json) => HistoryPoint(
        timestamp:    DateTime.parse(json['timestamp']),
        deviceCount:  json['device_count'],
        occupancyPct: (json['occupancy_pct'] as num).toDouble(),
      );
}

class ApiService {
  static Future<List<AreaModel>> getAreas() async {
    final res = await http.get(Uri.parse('$kApiBase/areas/'));
    if (res.statusCode != 200) throw Exception('Alanlar alınamadı');
    final List data = jsonDecode(utf8.decode(res.bodyBytes));
    return data.map((j) => AreaModel.fromJson(j)).toList();
  }

  static Future<List<OccupancyData>> getLiveOccupancy() async {
    final res = await http.get(Uri.parse('$kApiBase/occupancy/live'));
    if (res.statusCode != 200) throw Exception('Anlık veri alınamadı');
    final List data = jsonDecode(utf8.decode(res.bodyBytes));
    return data.map((j) => OccupancyData.fromJson(j)).toList();
  }

  static Future<List<HistoryPoint>> getHistory(int areaId, {int days = 7}) async {
    final uri = Uri.parse('$kApiBase/occupancy/history?area_id=$areaId&days=$days');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Geçmiş veri alınamadı');
    final List data = jsonDecode(utf8.decode(res.bodyBytes));
    return data.map((j) => HistoryPoint.fromJson(j)).toList();
  }

  static Future<Map<String, dynamic>> subscribe({
    required String fcmToken,
    required int areaId,
    required double thresholdPct,
    required String direction,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBase/notifications/subscribe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fcm_token':     fcmToken,
        'area_id':       areaId,
        'threshold_pct': thresholdPct,
        'direction':     direction,
      }),
    );
    if (res.statusCode != 200) throw Exception('Abonelik kaydedilemedi');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<void> unsubscribe(int subscriptionId) async {
    final res = await http.delete(
      Uri.parse('$kApiBase/notifications/subscribe/$subscriptionId'),
    );
    if (res.statusCode != 200) throw Exception('Abonelik iptal edilemedi');
  }
}

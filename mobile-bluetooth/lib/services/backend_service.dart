import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

/// Result of a single submission to the backend.
class ScanSubmissionResult {
  final bool success;
  final int? deviceCount;
  final double? occupancyPct;
  final String? status;
  final String? error;

  ScanSubmissionResult.ok({
    required this.deviceCount,
    required this.occupancyPct,
    required this.status,
  })  : success = true,
        error = null;

  ScanSubmissionResult.fail(this.error)
      : success = false,
        deviceCount = null,
        occupancyPct = null,
        status = null;
}

/// Posts a batch of detected MAC addresses to the Crowdly backend.
///
/// Endpoint: `POST /api/scanner/data`
/// Auth:     `X-API-Key` header
/// Body:     `{ area_id: int, mac_hashes: [sha256_hex_string] }`
class BackendService {
  BackendService(this._config);

  final ApiConfig _config;
  final http.Client _client = http.Client();

  Future<ScanSubmissionResult> submitScan(Iterable<String> macAddresses) async {
    if (!_config.isComplete) {
      return ScanSubmissionResult.fail(
        'Yapılandırma eksik. Lütfen ayarları kontrol edin.',
      );
    }

    final hashes = macAddresses
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .map(_sha256Hex)
        .toSet()
        .toList();

    final uri = Uri.parse('${_config.baseUrl}/api/scanner/data');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _config.apiKey,
            },
            body: jsonEncode({
              'area_id': _config.areaId,
              'mac_hashes': hashes,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ScanSubmissionResult.ok(
          deviceCount: json['device_count'] as int?,
          occupancyPct: (json['occupancy_pct'] as num?)?.toDouble(),
          status: json['status'] as String?,
        );
      }

      return ScanSubmissionResult.fail(
        _translateStatus(response.statusCode, response.body),
      );
    } on TimeoutException {
      return ScanSubmissionResult.fail(
        'Sunucu yanıt vermedi (zaman aşımı).',
      );
    } catch (e) {
      return ScanSubmissionResult.fail(
        'Sunucuya ulaşılamadı: ${e.toString()}',
      );
    }
  }

  static String _sha256Hex(String mac) {
    // Normalize: uppercase, no separators, then hash.
    final normalized = mac.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static String _translateStatus(int status, String body) {
    switch (status) {
      case 401:
      case 403:
        return 'Geçersiz API anahtarı. Lütfen ayarları kontrol edin.';
      case 404:
        return 'Sunucu uç noktası bulunamadı.';
      case 422:
        return 'Gönderilen veri geçersiz: $body';
      case 429:
        return 'Çok fazla istek gönderildi. Lütfen biraz bekleyin.';
      case 500:
      case 502:
      case 503:
        return 'Sunucu hatası (HTTP $status). Lütfen daha sonra deneyin.';
      default:
        return 'Beklenmeyen yanıt (HTTP $status).';
    }
  }

  void dispose() {
    _client.close();
  }
}

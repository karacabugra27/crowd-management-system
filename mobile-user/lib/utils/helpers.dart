import 'package:flutter/material.dart';

/// Doluluk durumuna göre renk döndürür (web helpers.js statusColor ile aynı)
Color statusColor(String status) {
  switch (status) {
    case 'empty':
      return const Color(0xFF22C55E);
    case 'low':
      return const Color(0xFF84CC16);
    case 'medium':
      return const Color(0xFFEAB308);
    case 'high':
      return const Color(0xFFF97316);
    case 'full':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF6B7280);
  }
}

/// Doluluk durumuna göre Türkçe etiket
String statusLabel(String status) {
  switch (status) {
    case 'empty':
      return 'Boş';
    case 'low':
      return 'Düşük';
    case 'medium':
      return 'Orta';
    case 'high':
      return 'Yoğun';
    case 'full':
      return 'Dolu';
    default:
      return status;
  }
}

/// Doluluk durumuna göre arka plan rengi (şeffaf)
Color statusBg(String status) {
  return statusColor(status).withValues(alpha: 0.15);
}

/// Yüzde formatlama
String formatPercent(double val) {
  return '${val.round()}%';
}

/// Tarih formatlama (web helpers.js formatDate ile aynı format)
String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '—';
  try {
    final date = DateTime.parse(dateStr);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return '—';
  }
}

/// Saat formatlama
String formatTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '—';
  try {
    final date = DateTime.parse(dateStr);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return '—';
  }
}

/// Hata mesajlarını temizle (Exception: önekini kaldır)
String cleanError(dynamic e) {
  String msg = e.toString();
  if (msg.startsWith('Exception: ')) {
    return msg.replaceFirst('Exception: ', '');
  }
  return msg;
}

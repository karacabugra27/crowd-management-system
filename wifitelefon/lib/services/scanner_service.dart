import 'dart:io';

class ScannerService {
  /// Android'de hotspot'a bağlanan cihazları arp veya ip neigh kullanarak tespit eder
  static Future<int> getConnectedDevicesCount() async {
    int count = 0;
    try {
      // Android terminali üzerinden ip komutunu çalıştır (root gerektirmez, bazen kısıtlı olabilir ama hotspot için çoğu zaman çalışır)
      final result = await Process.run('ip', ['neigh']);

      if (result.stdout != null) {
        final String output = result.stdout.toString();
        final List<String> lines = output.split('\n');

        for (String line in lines) {
          // Kendi cihazımızı (loopback vb.) saymamak ve sadece bağlı/ulaşılabilir olanları saymak için filtre
          // REACHABLE, STALE, DELAY durumları genelde bağlı bir cihazı temsil eder.
          if (line.contains('wlan') || line.contains('ap')) {
            if (line.contains('REACHABLE') ||
                line.contains('STALE') ||
                line.contains('DELAY')) {
              count++;
            }
          }
        }
      }
    } catch (e) {
      print('Scanner Error: $e');
    }

    // Eğer shell komutu sıfır dönerse ve test için cihaz gerektiğini düşünüyorsan,
    // fallback olarak ping işlemi de eklenebilir. Şimdilik "ip neigh" sonucunu dönüyoruz.
    return count;
  }
}

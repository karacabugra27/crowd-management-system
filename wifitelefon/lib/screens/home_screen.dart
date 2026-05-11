import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Sadece Icons veya ThemeData Color yardımcıları için (opsiyonel)
import '../services/scanner_service.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final String areaId;

  const HomeScreen({super.key, required this.areaId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isScanning = false;
  int _connectedDevices = 0;
  Timer? _timer;
  bool? _lastSendSuccess;
  String _lastSendTime = '--:--:--';

  void _toggleScanning(bool value) {
    setState(() {
      _isScanning = value;
      if (_isScanning) {
        _startTimer();
      } else {
        _stopTimer();
      }
    });
  }

  void _startTimer() {
    _scanAndSend(); // İlk başlatmada hemen çalıştır
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _scanAndSend();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _scanAndSend() async {
    int count = await ScannerService.getConnectedDevicesCount();

    // Uygulama ön planda kalmadığında durumu güncellememek için (mounted)
    if (!mounted) return;

    setState(() {
      _connectedDevices = count;
    });

    bool success = await ApiService.sendOccupancyData(widget.areaId, count);

    if (mounted) {
      setState(() {
        _lastSendSuccess = success;
        final now = DateTime.now();
        _lastSendTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('CampusPulse Dinleyici'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const SizedBox(height: 20),
            Center(
              child: ClipOval(
                child: Container(
                  width: 160,
                  height: 160,
                  color: _isScanning
                      ? CupertinoColors.activeBlue.withOpacity(0.1)
                      : CupertinoColors.inactiveGray.withOpacity(0.2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.wifi,
                        size: 48,
                        color: _isScanning
                            ? CupertinoColors.activeBlue
                            : CupertinoColors.systemGrey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$_connectedDevices',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: _isScanning
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Bağlı Cihaz Sayısı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(height: 40),
            CupertinoListSection.insetGrouped(
              header: const Text('KONTROL MERKEZİ'),
              children: [
                CupertinoListTile(
                  title: const Text('Taramayı Başlat'),
                  subtitle: const Text('10 saniyede bir eşitle'),
                  leading: const Icon(
                    CupertinoIcons.antenna_radiowaves_left_right,
                  ),
                  trailing: CupertinoSwitch(
                    value: _isScanning,
                    onChanged: _toggleScanning,
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('DURUM'),
              children: [
                CupertinoListTile(
                  title: const Text('Son Gönderim'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _lastSendTime,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_lastSendSuccess != null)
                        Icon(
                          _lastSendSuccess!
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.clear_circled_solid,
                          color: _lastSendSuccess!
                              ? CupertinoColors.activeGreen
                              : CupertinoColors.destructiveRed,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('CİHAZ BİLGİSİ (ALAN KİMLİĞİ)'),
              footer: const Text(
                'Bu benzersiz kimlik CampusPulse backend sisteminde bu cihazın konumlandığı alanı (Örn: Kütüphane) temsil eder.',
              ),
              children: [
                CupertinoListTile(
                  title: Text(
                    widget.areaId,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 13),
                  ),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.doc_on_clipboard,
                      size: 20,
                    ),
                    onPressed: () {
                      // Kopyalama işlemi eklenebilir
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

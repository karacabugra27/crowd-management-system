/// logs_screen.dart
/// -----------------
/// Backend API log kayıtlarını gerçek zamanlı olarak listeleyen ekran.
/// Her log seviyesine farklı renk atanır: INFO=yeşil, WARNING=sarı, ERROR=kırmızı.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _scrollController = ScrollController();
  StreamSubscription<List<ApiLogEntry>>? _sub;
  List<ApiLogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _logs = List.from(ApiService.instance.logs);
    _sub = ApiService.instance.logStream.listen((logs) {
      if (!mounted) return;
      setState(() => _logs = List.from(logs));
      // Otomatik en alta kaydır
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Color _levelColor(String level) {
    return switch (level) {
      'ERROR' => Colors.red.shade400,
      'WARNING' => Colors.orange.shade400,
      _ => Colors.green.shade400,
    };
  }

  IconData _levelIcon(String level) {
    return switch (level) {
      'ERROR' => Icons.error_outline,
      'WARNING' => Icons.warning_amber_outlined,
      _ => Icons.check_circle_outline,
    };
  }

  void _copyAll() {
    final text = _logs.map((e) => e.toString()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loglar kopyalandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text(
          'API Logları',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Tümünü kopyala',
            onPressed: _logs.isEmpty ? null : _copyAll,
            color: Colors.white70,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Logları temizle',
            onPressed: () {
              ApiService.instance.clearLogs();
              setState(() => _logs = []);
            },
            color: Colors.white70,
          ),
        ],
      ),
      body: _logs.isEmpty
          ? const Center(
              child: Text(
                'Henüz log yok.\nTarama başlatınca loglar burada görünür.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final entry = _logs[i];
                final color = _levelColor(entry.level);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withAlpha(60)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_levelIcon(entry.level), color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.timestamp
                                  .toLocal()
                                  .toString()
                                  .substring(0, 19),
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 10),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.message,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

      // Backend URL ayarlama FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSettingsDialog(context),
        icon: const Icon(Icons.settings),
        label: const Text('Backend URL'),
        backgroundColor: const Color(0xFF7C3AED),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final urlController =
        TextEditingController(text: ApiService.instance.baseUrl);
    final idController =
        TextEditingController(text: ApiService.instance.listenerId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Backend Ayarları',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Telefonun ve bilgisayarın aynı Wi-Fi\'da olduğundan emin ol.\n'
              'Bilgisayarının IP adresini ipconfig ile öğrenebilirsin.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'http://192.168.1.X:8000',
                hintStyle: TextStyle(color: Colors.white30),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7C3AED))),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: idController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Dinleyici ID',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'emre-listener-01',
                hintStyle: TextStyle(color: Colors.white30),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7C3AED))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () async {
              await ApiService.instance.saveSettings(
                baseUrl: urlController.text.trim(),
                listenerId: idController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

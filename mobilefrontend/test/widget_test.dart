import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crowdpulse_mobile/main.dart';

void main() {
  testWidgets('CrowdPulse app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CrowdPulseApp());
    // App should show loading initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

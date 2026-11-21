import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/core/theme/app_theme.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/vendor/vendor_screen.dart';
import 'package:wedding_collect/features/vendor/widgets/vendor_cards.dart';

/// 웨딩업체 목록 순서 (11-21 사용자 요청): [시연] 업체 6곳 → 실제 연계업체 → 나머지 [시연] 업체
void main() {
  testWidgets('서울 전체 항목: 처음 6칸은 시연 업체, 그다음 실제 업체', (tester) async {
    await tester.runAsync(() async {
      await Repos.vendor.realVendors();
      await Repos.vendor.demoVendors();
    });
    tester.view.physicalSize = const Size(1170, 2532) * 4; // 목록이 한 화면에 많이 보이게 (길게)
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const VendorScreen()));
    await tester.pumpAndSettle();

    final tiles = tester
        .widgetList(find.byWidgetPredicate((w) => w is DemoVendorCard || w is RealVendorTile))
        .map((w) => w is DemoVendorCard ? 'demo' : 'real')
        .toList();
    expect(tiles.take(6), everyElement('demo'));
    expect(tiles[6], 'real');
    expect(tiles.where((t) => t == 'real'), isNotEmpty);
    expect(find.textContaining('[시연] 업체 6곳 먼저'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wedding_collect/data/models/venue.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/intro/lookbook_ad.dart';

/// 앱 시작 룩북 광고: 실제 예식장 이름, 터치하면 그 예식장, 오늘 하루 보지 않기
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('사진마다 실제 예식장이 있다', () async {
    final ids = {for (final v in await Repos.venue.loadAll()) v.id};
    expect(LookbookAd.catalog.every((s) => ids.contains(s.venueId)), isTrue);
  });

  test('오늘 하루 보지 않기를 누르면 오늘은 숨김', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await LookbookAd.hiddenToday(), isFalse);
    await LookbookAd.hideToday();
    expect(await LookbookAd.hiddenToday(), isTrue);
  });

  testWidgets('실제 예식장 이름·대관료를 보여 주고, 사진을 누르면 그 예식장으로', (tester) async {
    await tester.runAsync(() => Repos.venue.loadAll());
    Venue? opened;
    await tester.pumpWidget(MaterialApp(home: LookbookAd(onOpenVenue: (v) => opened = v)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('북서울 꿈의숲(창녕위궁재사)'), findsOneWidget);
    expect(find.textContaining('대관료 무료'), findsWidgets);
    expect(find.byTooltip('닫기'), findsOneWidget);
    expect(find.text('오늘 하루 보지 않기'), findsOneWidget);
    await tester.tap(find.text('터치하여 예식장 보기 →').first);
    expect(opened?.id, 'H084');
    await tester.pumpWidget(const SizedBox()); // 자동 넘김 타이머 정리
  });
}

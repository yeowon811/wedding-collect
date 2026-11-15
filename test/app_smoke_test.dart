import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/app/app.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/local_data_agent.dart';
import 'package:wedding_collect/features/venue/widgets/venue_card.dart';

/// 모든 탭을 열어 보고 주요 흐름이 오류 없이 그려지는지 확인한다.
/// 테스트 환경에서는 에셋을 실제 비동기로 읽어야 하므로 미리 불러 둔다.
Future<void> _preload(WidgetTester tester) => tester.runAsync(() async {
      await Repos.venue.loadAll();
      await Repos.policy.loadAll();
      await Repos.vendor.realVendors();
      await Repos.vendor.demoVendors();
      await Repos.vendor.nearbyFor('H001');
    });

/// 현재 화면 닫기 (뒤로 가기)
Future<void> back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('5개 탭이 모두 열린다', (tester) async {
    await _preload(tester);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const WeddingCollectApp());
    await tester.pumpAndSettle();
    expect(find.text('공공예식장 찾기'), findsWidgets);
    expect(find.textContaining('전국 240곳'), findsOneWidget);

    for (final tab in ['정책', '업체', '체크리스트', 'AI 상담', '예식장']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('업체 비교·상담 신청·예식장 상세 흐름', (tester) async {
    await _preload(tester);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WeddingCollectApp());
    await tester.pumpAndSettle();

    Future<void> tab(String name) async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(name)));
      await tester.pumpAndSettle();
    }

    // 예식장 상세 (근처 업체·관련 정책)
    await tester.tap(find.byType(VenueCard).first);
    await tester.pumpAndSettle();
    expect(find.text('예약 페이지 열기'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('근처 실제 연계 업체'), 300,
        scrollable: find.byType(Scrollable).first);
    await back(tester);
    await tester.pumpAndSettle();

    // 업체: 드레스 2곳 비교
    await tab('업체');
    await tester.tap(find.widgetWithText(ChoiceChip, '드레스'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('비교 담기').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('비교 담기').first);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('비교하기'));
    await tester.pumpAndSettle();
    expect(find.text('드레스 비교'), findsOneWidget);
    await back(tester);
    await tester.pumpAndSettle();

    // 업체 상세 → 상담 신청
    await tester.ensureVisible(find.textContaining('[시연]').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('[시연]').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('상담 신청 · 일정 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('상담 신청 · 일정 선택'));
    await tester.pumpAndSettle();
    final open = find.byWidgetPredicate((w) =>
        w is ChoiceChip && w.onSelected != null && (w.label as Text).data!.endsWith(':00'));
    await tester.tap(open.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('상담 신청하기'));
    await tester.pumpAndSettle();
    expect(find.text('상담 신청 완료'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('이 업체로 계약 완료 표시'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 업체로 계약 완료 표시'));
    await tester.pumpAndSettle();
    await back(tester);
    await tester.pumpAndSettle();

    // 실제 업체 모드
    await tester.tap(find.text('실제 연계 업체'));
    await tester.pumpAndSettle();
    expect(find.textContaining('실제 연계 업체'), findsWidgets);

    // 체크리스트에 상담 일정·계약 반영
    await tab('체크리스트');
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.textContaining('1/11 완료'), 200, scrollable: list);
    await tester.scrollUntilVisible(find.text('내 상담 일정'), 200, scrollable: list);
    await tester.scrollUntilVisible(find.text('예식일 기준 할 일'), 200, scrollable: list);

    // 시안 바꾸기
    await tester.tap(find.byTooltip('디자인 시안 바꾸기').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('C. 모노톤 & 골드').last);
    await tester.pumpAndSettle();
    expect(find.text('준비 체크리스트'), findsOneWidget); // 탭 유지

    expect(tester.takeException(), isNull);
  });

  testWidgets('데이터 건수', (tester) async {
    await _preload(tester);
    expect((await Repos.venue.loadAll()).length, 240);
    expect((await Repos.policy.loadAll()).length, 177);
    expect((await Repos.vendor.realVendors()).length, 103);
    final demo = await Repos.vendor.demoVendors();
    expect(demo.length, 561);
    expect(demo.every((v) => v.name.startsWith('[시연]')), isTrue);
    expect(demo.map((v) => v.category).toSet().length, VendorCategory.planItems.length);
    expect((await Repos.vendor.nearbyFor('H001')).isNotEmpty, isTrue);
  });

  testWidgets('AI 상담이 질문 유형별로 답한다', (tester) async {
    await _preload(tester);
    final agent = LocalDataAgent();
    final venue = await agent.reply('서울 공공예식장 알려줘');
    expect(venue.text, contains('서울 공공예식장은'));
    expect(venue.cards, isNotEmpty);

    final policy = await agent.reply('29세 받을 수 있는 정책 있어?');
    expect(policy.text, contains('만 29세'));

    final dress = await agent.reply('예산 안에서 드레스 추천해줘');
    expect(dress.text, contains('드레스 추천 예산'));
    expect(dress.cards, isNotEmpty);

    final parent = await agent.reply('혼주 메이크업 알려줘');
    expect(parent.text, contains('혼주 메이크업'));

    expect((await agent.reply('예산 어떻게 나눠?')).text, contains('추천 배분'));
    expect((await agent.reply('뭐부터 해야 해?')).text, contains('먼저 할 일'));
    expect((await agent.reply('대전 공공예식장')).text, contains('없어요'));
  });
}

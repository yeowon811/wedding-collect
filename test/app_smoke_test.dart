import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/app/app.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/data/repositories/review_repository.dart';
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
    await tester.scrollUntilVisible(find.text('예약 페이지 열기'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('근처 실제 연계 업체'), 300,
        scrollable: find.byType(Scrollable).first);
    await back(tester);
    await tester.pumpAndSettle();

    // 예식장 조건 필터: 무료 대관 → 정원·요금 배지
    await tester.tap(find.widgetWithText(FilterChip, '무료 대관'));
    await tester.pumpAndSettle();
    expect(find.textContaining('대관료 무료'), findsWidgets);
    await tester.tap(find.widgetWithText(FilterChip, '무료 대관'));
    await tester.tap(find.textContaining('명 수용'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('명 수용'));
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
    await tester.scrollUntilVisible(find.text('상담 신청 · 일정 선택'), 300,
        scrollable: find.byType(Scrollable).first);
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
    // 후기: 요약·목록이 보이고, 상담한 업체라 후기를 쓸 수 있다
    await tester.scrollUntilVisible(find.text('많이 언급된 키워드'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('후기 쓰기'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('후기 쓰기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4점'));
    await tester.enterText(find.byType(TextField).last, '상담이 친절하고 설명이 자세했어요.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('등록하기'));
    await tester.pumpAndSettle();
    expect(find.text('내 후기'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('전체 보기'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.text('평점 높은순').evaluate().isEmpty, isTrue); // 기본은 최신순
    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await back(tester);

    await tester.scrollUntilVisible(find.text('이 업체로 계약 완료 표시'), 300,
        scrollable: find.byType(Scrollable).first);
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
    final venues = await Repos.venue.loadAll();
    expect(venues.length, 240);

    // 공유누리 수집 데이터 (validate_venues.py 보고서 수치와 같아야 함)
    expect(venues.where((v) => v.isCollected).length, 117);
    expect(venues.where((v) => v.capacity != null).length, 84);
    expect(venues.where((v) => v.rentalFee != null).length, 114);
    expect(venues.where((v) => v.isFree).length, 43);
    expect(venues.where((v) => v.images.isNotEmpty).length, 113);
    // 정원 '1명'·'문의' 같은 값은 숫자로 쓰지 않고, 확인 필요 안내가 붙는다
    for (final v in venues.where((v) => v.capacityText != null && v.capacity == null)) {
      expect(v.dataNotes, isNotEmpty, reason: v.id);
    }
    expect(venues.every((v) => v.capacity == null || v.capacity! > 1), isTrue);
    expect(venues.where((v) => !v.isCollected).every((v) => v.capacity == null && v.images.isEmpty), isTrue);
    final h001 = venues.firstWhere((v) => v.id == 'H001');
    expect(h001.capacity, 100);
    expect(h001.rentalFee, 100000);
    expect(h001.feeLabel, '기본요금 10만원');
    expect(h001.images.length, 1);
    expect((await Repos.policy.loadAll()).length, 177);
    expect((await Repos.vendor.realVendors()).length, 103);
    final demo = await Repos.vendor.demoVendors();
    expect(demo.length, 561);
    expect(demo.every((v) => v.name.startsWith('[시연]')), isTrue);
    expect(demo.map((v) => v.category).toSet().length, VendorCategory.planItems.length);
    expect((await Repos.vendor.nearbyFor('H001')).isNotEmpty, isTrue);

    // 후기: 별점 분포의 평균·개수가 업체 평점·후기 수와 같다 (561곳 모두)
    AppState.instance.myReviews.clear(); // 앞 테스트에서 쓴 내 후기 제외
    for (final v in demo) {
      final s = ReviewRepository.summaryFor(v);
      expect(s.count, v.reviewCount, reason: v.id);
      expect(s.average, v.rating, reason: v.id);
      final list = ReviewRepository.reviewsFor(v);
      expect(list.length, v.reviewCount < 30 ? v.reviewCount : 30);
      expect(list.every((r) => r.text.isNotEmpty && r.rating >= 1 && r.rating <= 5), isTrue);
    }
    // 같은 업체는 항상 같은 후기
    expect(ReviewRepository.reviewsFor(demo.first).first.text,
        ReviewRepository.reviewsFor(demo.first).first.text);
  });

  testWidgets('AI 상담이 질문 유형별로 답한다', (tester) async {
    await _preload(tester);
    final agent = LocalDataAgent();
    final venue = await agent.reply('서울 공공예식장 알려줘');
    expect(venue.text, contains('서울 공공예식장은'));
    expect(venue.text, contains('무료 대관'));
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/app/app.dart';
import 'package:wedding_collect/app/main_shell.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/data/repositories/stock_photos.dart';
import 'package:wedding_collect/features/vendor/widgets/vendor_cards.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/data/repositories/review_repository.dart';
import 'package:wedding_collect/data/models/policy.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/understanding.dart';
import 'package:wedding_collect/features/venue/widgets/venue_card.dart';
import 'package:wedding_collect/features/intro/lookbook_ad.dart';

/// 모든 탭을 열어 보고 주요 흐름이 오류 없이 그려지는지 확인한다.
/// 테스트 환경에서는 에셋을 실제 비동기로 읽어야 하므로 미리 불러 둔다.
Future<void> _preload(WidgetTester tester) => tester.runAsync(() async {
      await Repos.venue.loadAll();
      await Repos.policy.loadAll();
      await Repos.booking.loadAll();
      await Repos.venueReview.loadAll();
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
  LookbookAd.enabled = false; // 앱 시작 광고는 따로 시험
  testWidgets('5개 탭이 모두 열린다', (tester) async {
    await _preload(tester);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    MainShell.tab.value = 0; // 앞 테스트에서 바꾼 탭 초기화
    await tester.pumpWidget(const WeddingCollectApp());
    await tester.pumpAndSettle();
    expect(find.text('We Connect'), findsOneWidget);
    expect(find.textContaining('전국 240곳'), findsNothing); // 제목 아래 개수 줄은 없앰

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
    MainShell.tab.value = 0; // 앞 테스트에서 바꾼 탭 초기화
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

    // 예식장 지역: 서울 → 강남구만 보기
    expect(find.byType(FilterChip), findsNothing); // 예약방식·조건 버튼은 없앰
    await tester.tap(find.widgetWithText(ChoiceChip, '서울 74'));
    await tester.pumpAndSettle();
    // 선택창: 시군구를 고르고 [확인]
    expect(find.text('서울 시·군·구 선택'), findsOneWidget);
    await tester.tap(find.textContaining('강남구'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FilledButton), matching: find.textContaining(RegExp(r'^확인 \('))));
    await tester.pumpAndSettle();
    expect(find.text('서울 시·군·구 선택'), findsNothing);
    expect(find.textContaining('서울 강남구'), findsWidgets);
    expect(find.text('서울 · 강남구'), findsOneWidget); // 칩에 고른 시군구 표시
    for (final card in tester.widgetList<VenueCard>(find.byType(VenueCard))) {
      expect(card.venue.sigungu, '강남구');
    }

    // 여러 곳: 송파구도 더하고, 다른 시도(전북)도 함께
    await tester.tap(find.widgetWithText(ChoiceChip, '서울 · 강남구'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('송파구'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인 (7곳)'));
    await tester.pumpAndSettle();
    expect(find.text('서울 · 강남구 외 1'), findsOneWidget);
    expect(find.textContaining('송파구', skipOffstage: false), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, '전북 26'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FilledButton), matching: find.textContaining(RegExp(r'^확인 \('))));
    await tester.pumpAndSettle();
    expect(find.text('서울 · 강남구 외 1'), findsOneWidget);
    for (final card in tester.widgetList<VenueCard>(find.byType(VenueCard))) {
      expect(card.venue.sido == '전북' || const {'강남구', '송파구'}.contains(card.venue.sigungu), isTrue);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, '전체')); // 전체 = 고른 지역 모두 풀기
    await tester.pumpAndSettle();
    expect(find.text('서울 · 강남구 외 1'), findsNothing);

    // 업체: 드레스 2곳 비교
    await tab('업체');
    await tester.tap(find.widgetWithText(ChoiceChip, '드레스'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byTooltip('비교 담기').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('비교 담기').first);
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
    await tester.scrollUntilVisible(find.text('상담 신청'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('상담 신청'));
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
    await tester.scrollUntilVisible(find.text('많이 언급된 키워드'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('후기 쓰기'), -200,
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

    await tester.scrollUntilVisible(find.text('계약 완료 표시'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('계약 완료 표시'));
    await tester.pumpAndSettle();
    await back(tester);
    await tester.pumpAndSettle();

    // 실제 연계업체도 같은 목록에 (서울: 공식전담 체크 표시)
    final list0 = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.byType(RealVendorTile).first, -300, scrollable: list0);
    expect(find.byType(RealVendorTile), findsWidgets);
    expect(find.text('공식전담(서울시)'), findsWidgets);

    // 체크리스트에 상담 일정·계약 반영
    await tab('체크리스트');
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.textContaining('1/11 완료'), 200, scrollable: list);
    await tester.scrollUntilVisible(find.text('내 상담 일정'), 200, scrollable: list);
    await tester.scrollUntilVisible(find.text('예식일 기준 할 일'), -200, scrollable: list); // 준비 항목보다 위
    // 처음에는 할 일이 비어 있다 → 예식일 입력 + 할 일 채우기
    expect(find.textContaining('예식일을 입력하면'), findsOneWidget);
    final app = AppState.instance;
    app.updatePlan(app.plan.copyWith(weddingDate: DateTime.now().add(const Duration(days: 200))));
    await tester.pumpAndSettle();
    app.loadRecommendedTasks(); // (화면의 불러오기 버튼은 없앰) 시연용으로 할 일을 채운다
    await tester.pumpAndSettle();

    // 할 일 캘린더: 달력과 이번 달 일정 (상담 신청한 날이 들어 있다)
    await tester.ensureVisible(find.text('캘린더'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('캘린더'));
    await tester.pumpAndSettle();
    expect(find.text('할 일 캘린더'), findsOneWidget);
    expect(find.textContaining('월 일정'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('전체 할 일'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('전체 할 일'), findsOneWidget);
    await back(tester);
    expect(find.textContaining('다음 할 일 ·'), findsOneWidget); // 체크리스트에는 가장 가까운 할 일만

    expect(tester.takeException(), isNull);
  });

  testWidgets('데이터 건수', (tester) async {
    await _preload(tester);
    final venues = await Repos.venue.loadAll();
    expect(venues.length, 240);

    // 공유누리 수집 데이터 (validate_venues.py 보고서 수치와 같아야 함)
    expect(venues.where((v) => v.isCollected).length, 231);
    expect(venues.where((v) => v.collectSource == '공유누리').length, 117);
    expect(venues.where((v) => v.collectSource == '서울마이웨딩(더아결)').length, 65);
    expect(venues.where((v) => v.collectSource?.startsWith('기관 안내 페이지') ?? false).length, 49);
    expect(venues.where((v) => v.capacity != null).length, 159);
    expect(venues.where((v) => v.rentalFee != null).length, 183);
    expect(venues.where((v) => v.isFree).length, 110);
    expect(venues.where((v) => v.images.isNotEmpty).length, 180);
    // 기관 페이지 수집: 다양한 정원·요금 문구, 지원 사업 안내, 수집 실패 사유
    final h018 = venues.firstWhere((v) => v.id == 'H018'); // '하객은 50명 이하로 인원 제한합니다.'
    expect(h018.capacity, 50);
    final h023 = venues.firstWhere((v) => v.id == 'H023'); // '유료 450,000원(원/회차 당)'
    expect(h023.rentalFee, 450000);
    final h178 = venues.firstWhere((v) => v.id == 'H178'); // '…수용가능인원 350명 정도'
    expect(h178.capacity, 350);
    expect(h178.dataNotes.any((n) => n.contains('대략적인 값')), isTrue);
    final h057 = venues.firstWhere((v) => v.id == 'H057'); // '대관료 : 협의 후 결정'
    expect(h057.rentalFee, isNull);
    expect(h057.feeText, '대관료 : 협의 후 결정');
    expect(venues.where((v) => v.programInfo != null).length, greaterThan(20));
    final h159 = venues.firstWhere((v) => v.id == 'H159'); // 세종: 사이트 접속 차단
    expect(h159.isCollected, isFalse);
    expect(h159.dataNotes.single, startsWith('수집 실패: 접근 차단'));
    // AI 생성 이미지는 실제 사진이 없는 곳(4곳)에만 남기고, 실제 사진이 있으면 뺀다
    final aiOnly = venues.where((v) => v.aiImages.isNotEmpty).toList();
    expect(aiOnly.length, 4);
    expect(aiOnly.every((v) => v.aiImages.length == v.images.length), isTrue);
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

    // 더아결: 정원 범위, AI 생성 이미지 제외, 협력업체
    final h078 = venues.firstWhere((v) => v.id == 'H078');
    expect(h078.capacityMin, 100);
    expect(h078.capacity, 200);
    expect(h078.capacityLabel, '100~200명');
    expect(h078.isFree, isTrue);
    expect(h078.aiImages, isEmpty); // 실제 사진이 있어 AI 생성 이미지는 뺌
    expect(h078.images, isNotEmpty);
    expect(h078.partnerVendors, isNotEmpty);
    for (final v in venues) {
      expect(v.aiImages.every(v.images.contains), isTrue, reason: v.id);
    }
    expect((await Repos.policy.loadAll()).length, 177);
    final real = await Repos.vendor.realVendors();
    expect(real.length, 103);
    final demo = await Repos.vendor.demoVendors();
    expect(demo.length, 561);
    expect(demo.every((v) => v.name.startsWith('[시연]')), isTrue);
    // 실제 업체 대표 사진: 홈페이지에서 가져온 https 주소, 검수에서 뺀 곳(V015 등)은 없음
    final withImage = real.where((v) => v.image != null).toList();
    expect(withImage.length, 59); // 첫 화면 54 + 하위 페이지 5
    expect(withImage.every((v) => v.image!.startsWith('https://')), isTrue);
    expect(real.firstWhere((v) => v.id == 'V015').image, isNull); // 검수에서 뺀 곳
    // 무료 사진: [시연] 업체는 모든 항목에, 사진 없는 실제 업체도 분류에 맞는 참고 사진이 있다 (저작자·라이선스 포함)
    for (final c in [...VendorCategory.planItems, ...VendorCategory.realGroups]) {
      final p = StockPhotos.pick(c, 'D0001');
      expect(p, isNotNull, reason: c.name);
      expect(p!.url, startsWith('https://'));
      expect(p.credit, contains('Wikimedia Commons'));
    }
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

  test('질문 이해: 나이대·분야·결혼 단계를 읽는다', () {
    final nlu = RuleUnderstander();
    final u = nlu.parse('20대 청년이 신혼생활에 받을 수 있는 정책이 뭐가있어?');
    expect(u.intent, ConsultIntent.policy);
    expect(u.facts.age, 20);
    expect(u.facts.ageMax, 29);
    expect(u.topic, PolicyCategory.housing);
    expect(u.facts.sido, isNull);
    expect(u.facts.stage, isNull); // "신혼생활"만으로는 혼인신고 여부를 알 수 없음

    final v = nlu.parse('하객 100명 정도인데 서울 공공예식장 추천해줘');
    expect(v.intent, ConsultIntent.venue);
    expect(v.facts.guests, 100);
    expect(v.facts.sido, '서울');

    final d = nlu.parse('예산 3천만원인데 드레스 추천해줘');
    expect(d.intent, ConsultIntent.vendor);
    expect(d.facts.budget, 3000);

    expect(nlu.parse('27', expecting: Slot.age).facts.age, 27);
    expect(nlu.parse('결혼 2년차예요').facts.marriedYears, 2);
    expect(nlu.parse('결혼 2년차예요').facts.stage, MarriageStage.married);
  });

  testWidgets('내 정보가 없으면 필요한 정보를 하나씩 되묻고 이어서 답한다', (tester) async {
    await _preload(tester);
    AppState.instance.resetProfile();
    final agent = ConsultAgent();

    await tester.runAsync(() async {
      // 지역·결혼 단계를 모르므로 먼저 지역을 묻는다 (나이는 "20대"로 앎)
      var m = await agent.reply('20대 청년이 신혼생활에 받을 수 있는 정책이 뭐가있어?');
      expect(m.isQuestion, isTrue);
      expect(agent.asking, Slot.sido);
      expect(m.text, contains('어느 지역'));
      expect(m.quickReplies.map((r) => r.label), contains('서울'));
      expect(m.basis, contains('만 20~29세'));

      // 버튼으로 답 → 이어서 시·군·구를 묻는다 (서울 → 강남구 …)
      m = await agent.choose(m.quickReplies.firstWhere((r) => r.label == '서울'));
      expect(agent.asking, Slot.sigungu);
      expect(m.text, contains('서울의 어느 시·군·구'));
      expect(m.quickReplies.map((r) => r.label), containsAll(['강남구', '송파구', '잘 모르겠어요']));
      m = await agent.choose(m.quickReplies.firstWhere((r) => r.label == '강남구'));
      expect(agent.asking, Slot.stage);

      // 글로 답해도 된다
      m = await agent.reply('네 혼인신고 했어요');
      expect(agent.asking, Slot.marriedYears);
      m = await agent.choose(m.quickReplies.firstWhere((r) => r.label == '1년 이내'));
      expect(agent.asking, Slot.homeless);

      // 모르면 건너뛰기 → 답변
      m = await agent.reply('잘 모르겠어요');
      expect(m.isQuestion, isFalse);
      expect(agent.asking, isNull);
      expect(m.basis, contains('서울'));
      expect(m.basis, contains('만 20~29세'));
      expect(m.text, contains('주거·대출'));
      expect(m.cards, isNotEmpty);
      expect(m.text, contains('정확한 만 나이')); // 범위로만 알면 안내
      expect(m.quickReplies.any((r) => r.action == 'save_profile'), isTrue);

      // 대화에서 알게 된 정보는 기억한다 → 다음 질문에서는 지역을 다시 묻지 않는다
      m = await agent.reply('하객 150명인데 공공예식장 추천해줘');
      expect(m.isQuestion, isFalse);
      expect(m.basis, contains('하객 150명'));

      // 되묻는 중에 다른 질문을 하면 새 질문으로 처리
      final other = ConsultAgent();
      await other.reply('공공예식장 추천해줘');
      expect(other.asking, Slot.sido);
      m = await other.reply('예산 어떻게 나누면 돼?');
      expect(other.asking, Slot.budget);
    });
  });

  testWidgets('내 정보를 입력하면 첫 화면은 질문 추천만, 이후 답은 되묻지 않는다', (tester) async {
    await _preload(tester);
    AppState.instance.saveProfile(const UserProfile(
      sido: '서울', age: 29, stage: MarriageStage.engaged, guests: 120, budget: 3000, homeless: true));
    final agent = ConsultAgent();
    await tester.runAsync(() async {
      final first = await agent.start();
      expect(first.cards, isEmpty); // 처음부터 예식장 목록을 보여주지 않는다
      expect(first.text, contains('무엇부터'));
      final labels = first.quickReplies.map((q) => q.label).toList();
      expect(labels, contains('서울 공공예식장'));
      expect(labels, contains('예산 나누기'));
      expect(labels, contains('받을 수 있는 정책'));

      final p = await agent.reply('받을 수 있는 정책 있어?');
      expect(p.isQuestion, isFalse);
      expect(p.basis, contains('만 29세'));

      final dress = await agent.reply('드레스 추천해줘');
      expect(dress.text, isNot(contains('추천 예산')));

      expect((await agent.reply('대전 공공예식장 알려줘')).text, contains('없어요'));
      expect((await agent.reply('혼주 메이크업 추천')).text, contains('혼주 메이크업'));
    });
    AppState.instance.resetProfile();
  });
}

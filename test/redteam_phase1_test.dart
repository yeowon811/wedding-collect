import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/chat_screen.dart';
import 'package:wedding_collect/features/chat/profile_setup_view.dart';

/// Red Team 진단 Phase 1 (P0): 위쪽 조건 줄 동기화·✕ 지우기·입력 폼 자동 저장 (2026-11-20)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;

  setUpAll(() async {
    await Repos.venue.loadAll();
    await Repos.policy.loadAll();
    await Repos.booking.loadAll();
  });
  tearDown(() => app.resetProfile());

  testWidgets('입력을 건너뛴 사람도 대화에서 반영한 값이 위쪽 조건 줄에 바로 보이고, ✕로 지운다', (tester) async {
    app.resetProfile();
    app.skipProfile(); // 처음 입력 폼을 건너뜀 (예전에는 이때 늘 "내 정보 없음")
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListenableBuilder(listenable: app, builder: (_, _) => ProfileChipsBar(onEdit: () {}))),
    ));
    expect(find.textContaining('내 정보 없음'), findsOneWidget);

    // 대화에서 "하객 150명" 반영 (에이전트가 쓰는 것과 같은 경로)
    app.updateProfileDraft(app.profile.copyWith(sido: '서울', guests: 150, budget: 3000));
    await tester.pump();
    expect(find.text('하객 150명'), findsOneWidget);
    expect(find.text('총예산 3,000만원'), findsOneWidget);
    expect(find.textContaining('내 정보 없음'), findsNothing);

    await tester.tap(find.byTooltip('하객 150명 지우기'));
    await tester.pump();
    expect(app.profile.guests, isNull);
    expect(app.plan.hasGuests, isFalse); // 체크리스트 결혼 정보도 '입력 안 함'
    expect(find.text('하객 150명'), findsNothing);
    expect(app.profile.budget, 3000); // 다른 값은 그대로
  });

  test('조건 칩으로 지운 값은 대화 기억에서도 빠진다', () async {
    app.saveProfile(const UserProfile(sido: '서울', guests: 150, budget: 3000));
    final agent = ConsultAgent();
    await agent.reply('안녕');
    expect(agent.known.guests, 150);
    app.clearProfileField('guests');
    await agent.reply('안녕');
    expect(agent.known.guests, isNull);
    expect(agent.known.budget, 3000);
  });

  testWidgets('하객·예산을 입력만 하고 [확인]을 안 눌러도 아래 시작 버튼이 함께 저장한다', (tester) async {
    app.resetProfile();
    await tester.binding.setSurfaceSize(const Size(800, 2400)); // 폼 전체가 한 화면에 보이게
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var done = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProfileSetupView(onDone: () => done = true))));
    final fields = find.byType(TextField);
    // 하객·총예산 입력칸 (지역 칸 다음)
    final guests = find.widgetWithText(TextField, '예: 150');
    final budget = find.widgetWithText(TextField, '예: 3000 (3천만원)');
    expect(fields, findsWidgets);
    await tester.enterText(guests, '180');
    await tester.enterText(budget, '2500');
    await tester.pump();
    expect(find.textContaining('아래 버튼을 누르면 함께 저장돼요'), findsWidgets);
    await tester.tap(find.text('이 정보로 상담 시작'));
    await tester.pump();
    expect(done, isTrue);
    expect(app.profile.guests, 180);
    expect(app.profile.budget, 2500);
  });
}

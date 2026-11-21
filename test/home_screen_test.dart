import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/app/main_shell.dart';
import 'package:wedding_collect/core/theme/app_theme.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/chat_screen.dart';
import 'package:wedding_collect/features/home/home_screen.dart';
import 'package:wedding_collect/features/policy/policy_screen.dart';
import 'package:wedding_collect/data/models/policy.dart';
import 'package:wedding_collect/features/venue/venue_home_screen.dart';

/// 홈 화면 (2026-11-21 사용자 시안 기반)
void main() {
  HomeScreen.autoPlay = false;

  Future<void> pumpHome(WidgetTester tester, {Size size = const Size(360, 780)}) async {
    await tester.runAsync(() async {
      await Repos.venue.loadAll();
      await Repos.policy.loadAll();
      await Repos.booking.loadAll();
    });
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const HomeScreen()));
    await tester.pumpAndSettle();
  }

  tearDown(() {
    AppState.instance.resetProfile();
    MainShell.tab.value = MainShell.home;
    ChatScreen.questionRequest.value = null;
  });

  testWidgets('좁은 휴대폰(360)에서도 넘치지 않고, 정부 표시·지어낸 문구가 없다', (tester) async {
    await pumpHome(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('청년 결혼지원 통합플랫폼'), findsOneWidget);
    expect(find.text('대한민국 정부'), findsNothing);
    expect(find.textContaining('많이 찾는'), findsNothing);
    expect(find.text('맞춤 지원 찾아보기'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('추천 서비스'), 200, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('맞춤 지원 칸은 내 정보를 보여 주고, 바로가기는 그 탭·조건으로 연다', (tester) async {
    AppState.instance.updateProfileDraft(const UserProfile(sido: '서울', sigungu: '강남구'));
    await pumpHome(tester);
    expect(find.text('서울 강남구'), findsOneWidget);

    await tester.tap(find.text('결혼지원 정책'));
    expect(MainShell.tab.value, 1);
    await tester.tap(find.text('공공예식장'));
    expect(MainShell.tab.value, 0);

    await tester.scrollUntilVisible(find.text('추천 서비스'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('지원금 혜택'));
    expect(MainShell.tab.value, 1);
    expect(PolicyScreen.categoryRequest.value, PolicyCategory.cash);
    PolicyScreen.categoryRequest.value = null;
    await tester.tap(find.textContaining('무료 예식장'));
    expect(VenueHomeScreen.freeOnlyRequest.value, isTrue);
    VenueHomeScreen.freeOnlyRequest.value = false;
    await tester.tap(find.textContaining('웨딩 가이드'));
    expect(MainShell.tab.value, 4);
    expect(ChatScreen.questionRequest.value, contains('비용을 어떻게 나누면'));
  });

  testWidgets('배너: 무료 공공예식장 수는 데이터에서 센 값', (tester) async {
    await pumpHome(tester);
    final free = (await Repos.venue.loadAll()).where((v) => v.isFree).length;
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('대관료 무료 공공예식장 $free곳'), findsOneWidget);
  });
}

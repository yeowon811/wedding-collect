import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/core/theme/app_theme.dart';
import 'package:wedding_collect/features/auth/login_screen.dart';

/// 로그인 화면 (11-21 시안 배치)
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const LoginScreen()));
    await tester.pumpAndSettle();
  }

  FilledButton submit(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('두 칸을 채워야 로그인 버튼이 켜지고, 좁은 폰에서도 넘치지 않는다', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('이메일 아이디로 로그인'), findsOneWidget);
    expect(find.text('We Connect'), findsOneWidget);
    expect(submit(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.pump();
    expect(submit(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField).at(1), 'secret1');
    await tester.pump();
    expect(submit(tester).onPressed, isNotNull);
  });

  testWidgets('"처음 오셨나요? 회원가입"으로 회원가입 칸(비밀번호 확인·동의)이 나온다', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, '회원가입'));
    await tester.pumpAndSettle();
    expect(find.text('이메일로 회원가입'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.textContaining('개인정보 수집·이용 동의'), findsOneWidget);
    expect(find.text('가입하고 시작하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../data/account_service.dart';
import '../features/auth/login_screen.dart';
import '../features/intro/lookbook_ad.dart';
import 'main_shell.dart';

class WeddingCollectApp extends StatelessWidget {
  const WeddingCollectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'We Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      // 로그인 안 했으면 첫 화면(로그인·회원가입·둘러보기), 그 외에는 앱
      home: _IntroGate(
        child: ListenableBuilder(
          listenable: AccountService.instance,
          builder: (context, _) => AccountService.instance.mode == AccountMode.signedOut
              ? const LoginScreen()
              : const MainShell(),
        ),
      ),
    );
  }
}

/// 앱을 처음 열면 첫 화면 위에 룩북 광고를 한 번 띄운다 (오늘 숨김·시연 링크면 안 띄움)
class _IntroGate extends StatefulWidget {
  const _IntroGate({required this.child});

  final Widget child;

  @override
  State<_IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<_IntroGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LookbookAd.showIfNeeded(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../data/account_service.dart';
import '../features/auth/login_screen.dart';
import 'main_shell.dart';

class WeddingCollectApp extends StatelessWidget {
  const WeddingCollectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '공공예식장 찾기',
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
      home: ListenableBuilder(
        listenable: AccountService.instance,
        builder: (context, _) => AccountService.instance.mode == AccountMode.signedOut
            ? const LoginScreen()
            : const MainShell(),
      ),
    );
  }
}

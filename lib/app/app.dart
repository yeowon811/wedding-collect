import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../data/account_service.dart';
import '../features/auth/login_screen.dart';
import '../features/intro/intro_video.dart';
import 'demo_links.dart';
import 'main_shell.dart';

class WeddingCollectApp extends StatefulWidget {
  const WeddingCollectApp({super.key});

  @override
  State<WeddingCollectApp> createState() => _WeddingCollectAppState();
}

class _WeddingCollectAppState extends State<WeddingCollectApp> {
  // 앱을 켤 때 한 번 시작 영상 → 끝나면 로그인(또는 앱). 시연 링크·테스트에서는 바로
  late bool _intro = IntroVideo.enabled && !DemoLinks.isDemoLink && !_inTest;

  /// flutter test 안에서는 영상 플러그인이 없어서 건너뛴다
  static bool get _inTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

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
      // 시작 영상 → 로그인 안 했으면 첫 화면(로그인·회원가입·둘러보기), 그 외에는 앱
      // 영상 → 로그인은 0.6초 동안 겹쳐 바뀐다 (영상은 서서히 사라지고 로그인이 서서히 나타남, 11-21)
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _intro
            ? IntroVideo(key: const ValueKey('intro'), onDone: () => setState(() => _intro = false))
            : ListenableBuilder(
                key: const ValueKey('app'),
                listenable: AccountService.instance,
                builder: (context, _) => AccountService.instance.mode == AccountMode.signedOut
                    ? const LoginScreen()
                    : const MainShell(),
              ),
      ),
    );
  }
}

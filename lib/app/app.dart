import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import 'main_shell.dart';

class WeddingCollectApp extends StatelessWidget {
  const WeddingCollectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 시안을 바꾸면 앱 전체를 새 색으로 다시 그린다 (탭 위치 등은 MainShell이 유지)
    return ValueListenableBuilder<AppPalette>(
      valueListenable: ThemeController.instance,
      builder: (context, palette, _) => MaterialApp(
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
        home: MainShell(key: MainShell.shellKey, palette: palette),
      ),
    );
  }
}

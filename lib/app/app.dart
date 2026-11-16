import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
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
      home: const MainShell(),
    );
  }
}

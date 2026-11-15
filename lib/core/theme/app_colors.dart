import 'package:flutter/material.dart';

import 'app_palette.dart';

/// 화면에서 쓰는 색. 값은 현재 선택된 시안([AppPalette])에서 가져온다.
/// 시안이 바뀌면 앱 전체가 다시 그려지므로 화면 코드는 그대로 두면 된다.
class AppColors {
  AppColors._();

  static AppPalette palette = AppPalette.rose;

  static Color get primary => palette.primary;
  static Color get primaryDark => palette.primaryDark;
  static Color get background => palette.background;
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get placeholder => palette.placeholder;
  static Color get headerStart => palette.headerStart;
  static Color get headerEnd => palette.headerEnd;
  static Color get onHeader => palette.onHeader;

  static const surface = Colors.white;
  static const divider = Color(0xFFE6E1DC);

  // 상태 표시 (시안과 관계없이 의미가 같은 색)
  static const success = Color(0xFF3DAA6B);
  static const warning = Color(0xFFE59A2F);
  static const unknown = Color(0xFF9E958A);
}

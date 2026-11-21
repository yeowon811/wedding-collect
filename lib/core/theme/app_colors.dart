import 'package:flutter/material.dart';

import 'app_palette.dart';

/// 화면에서 쓰는 색. 화면 코드는 색 값을 직접 쓰지 말고 여기 이름을 쓴다.
class AppColors {
  AppColors._();

  static const AppPalette palette = AppPalette.rose;

  static Color get primary => palette.primary;
  static Color get primaryDark => palette.primaryDark;
  static Color get primarySoft => palette.primarySoft;
  static Color get background => palette.background;
  static Color get fill => palette.fill;
  static Color get border => palette.border;
  static Color get textPrimary => palette.textPrimary;
  static Color get textBody => palette.textBody;
  static Color get textSecondary => palette.textSecondary;
  static Color get textHint => palette.textHint;
  static Color get placeholder => palette.placeholder;
  static Color get ink => palette.ink;

  // 예전 시안의 머리띠 색 → 연한 포인트 면 위에 진한 글자
  static Color get headerStart => palette.primarySoft;
  static Color get headerEnd => palette.primarySoft;
  static Color get onHeader => palette.textPrimary;

  static const surface = Colors.white;
  static const divider = Color(0xFFEFE4E8);

  // 상태 표시 (글자로 써도 흰 바탕에서 읽히는 진한 값)
  static const success = Color(0xFF1B7A4B);
  static const successSoft = Color(0xFFE8F3EE);
  static const warning = Color(0xFFC2410C);
  static const warningSoft = Color(0xFFFFF1E8);
  static const unknown = Color(0xFF8B95A1);

  // 달력 (11-22 사용자 지정 색): 바탕 연핑크, 고른 날짜 진한 로즈. 할 일 캘린더·예약 현황 달력·날짜 고르기 창에 같이 쓴다
  static const calendarBg = Color(0xFFFCF4F7);
  static const calendarSelected = Color(0xFFA34E63);
}

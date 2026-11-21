import 'package:flutter/material.dart';

/// 디자인 시안 A "클린 미니멀"의 색 (2026-11-16 확정).
/// 흰 바탕 + 진한 회색 글자 + 파란 포인트 하나. 면 구분은 그림자 대신 연한 회색 면으로 한다.
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.background,
    required this.fill,
    required this.border,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textHint,
    required this.placeholder,
    required this.ink,
  });

  final Color primary; // 메인 버튼, 선택 표시, 링크
  final Color primaryDark; // 눌림, 진한 강조
  final Color primarySoft; // 포인트 색의 연한 면 (추천 배너, AI 배지)
  final Color background; // 화면 바탕
  final Color fill; // 검색창·칩·카드 안쪽 같은 연한 면
  final Color border; // 테두리·구분선
  final Color textPrimary; // 제목·본문
  final Color textBody; // 칩·보조 본문
  final Color textSecondary; // 설명·지역
  final Color textHint; // 입력 안내·비활성
  final Color placeholder; // 사진 없는 자리
  final Color ink; // 선택된 칩·사용자 강조 (거의 검정)

  static const clean = AppPalette(
    primary: Color(0xFF3B5BDB),
    primaryDark: Color(0xFF2F4AC0),
    primarySoft: Color(0xFFF0F4FF),
    background: Color(0xFFFFFFFF),
    fill: Color(0xFFF2F4F6),
    border: Color(0xFFE5E8EB),
    textPrimary: Color(0xFF191F28),
    textBody: Color(0xFF4E5968),
    textSecondary: Color(0xFF6B7684),
    textHint: Color(0xFF8B95A1),
    placeholder: Color(0xFFE9ECEF),
    ink: Color(0xFF191F28),
  );

  /// "We Connect" 로즈 (2026-11-21 사용자 확정: 앱 아이콘·홈 시안의 핑크 톤을 앱 전체에).
  /// 포인트 로즈는 흰 글자를 얹어도 읽히는 진한 값(대비 흰 바탕 5.3:1 · 연핑크 면 4.7:1), 면은 아주 연한 핑크.
  static const rose = AppPalette(
    primary: Color(0xFFB04862),
    primaryDark: Color(0xFF9C3B57),
    primarySoft: Color(0xFFFCEEF2),
    background: Color(0xFFFFFFFF),
    fill: Color(0xFFF8F2F4),
    border: Color(0xFFEFE4E8),
    textPrimary: Color(0xFF1F1A1C),
    textBody: Color(0xFF51484C),
    textSecondary: Color(0xFF6F6569),
    textHint: Color(0xFF948A8E),
    placeholder: Color(0xFFF1E9EC),
    ink: Color(0xFF2A1F23),
  );
}

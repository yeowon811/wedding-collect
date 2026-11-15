import 'package:flutter/material.dart';

/// 디자인 시안별 색 묶음. 시안을 확정하면 나머지는 지우고 하나만 남긴다.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.label,
    required this.primary,
    required this.primaryDark,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.placeholder,
    required this.headerStart,
    required this.headerEnd,
    required this.onHeader,
  });

  final String id;
  final String label;
  final Color primary; // 버튼, 선택된 칩, 강조
  final Color primaryDark; // 눌림, 아이콘, 진한 강조
  final Color background; // 화면 바탕
  final Color textPrimary;
  final Color textSecondary;
  final Color placeholder; // 빈 이미지 자리, 연한 면
  final Color headerStart; // 카드 머리띠 그라데이션
  final Color headerEnd;
  final Color onHeader; // 머리띠 위 글자색

  static const mint = AppPalette(
    id: 'mint',
    label: '기본 (템플릿)',
    primary: Color(0xFF54D3C2),
    primaryDark: Color(0xFF2FA898),
    background: Color(0xFFF6F6F6),
    textPrimary: Color(0xFF17262A),
    textSecondary: Color(0xFF6B7478),
    placeholder: Color(0xFFE8E3DC),
    headerStart: Color(0xFF6ADBCB),
    headerEnd: Color(0xFF2FA898),
    onHeader: Colors.white,
  );

  static const rose = AppPalette(
    id: 'rose',
    label: 'A. 웜 로즈 & 아이보리',
    primary: Color(0xFFC8737B),
    primaryDark: Color(0xFFA4545D),
    background: Color(0xFFFBF6F2),
    textPrimary: Color(0xFF3A2A2C),
    textSecondary: Color(0xFF85716F),
    placeholder: Color(0xFFF1E4DF),
    headerStart: Color(0xFFE3A9A5),
    headerEnd: Color(0xFFC8737B),
    onHeader: Colors.white,
  );

  static const sage = AppPalette(
    id: 'sage',
    label: 'B. 세이지 그린 & 화이트',
    primary: Color(0xFF6F9277),
    primaryDark: Color(0xFF4E7258),
    background: Color(0xFFF4F6F2),
    textPrimary: Color(0xFF1F2D25),
    textSecondary: Color(0xFF66736B),
    placeholder: Color(0xFFE2E9E1),
    headerStart: Color(0xFF9DB8A2),
    headerEnd: Color(0xFF5E8267),
    onHeader: Colors.white,
  );

  static const monoGold = AppPalette(
    id: 'monoGold',
    label: 'C. 모노톤 & 골드',
    primary: Color(0xFFB08D4F),
    primaryDark: Color(0xFF86683A),
    background: Color(0xFFF6F5F2),
    textPrimary: Color(0xFF1C1C1C),
    textSecondary: Color(0xFF6E6E6E),
    placeholder: Color(0xFFE6E3DC),
    headerStart: Color(0xFF3A3A3A),
    headerEnd: Color(0xFF151515),
    onHeader: Color(0xFFE7CF9C),
  );

  static const all = [rose, sage, monoGold, mint];
}

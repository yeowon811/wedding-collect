import 'package:flutter/material.dart';

import '../../../core/widgets/favorite_button.dart';
import '../../../data/models/policy.dart';

/// 정책 기간 표시 (데이터에 마감일이 없어 정책 성격으로 정직하게):
/// - 전국 사업(대출·세제·검진 등): 상시 신청
/// - 지자체 사업: 2026년 사업 기준 연말까지, 예산 소진 시 조기 마감
extension PolicyPeriod on Policy {
  bool get alwaysOpen => isNational;
  static final yearEnd = DateTime(2026, 12, 31);

  String get statusLabel => alwaysOpen ? '상시 접수' : '신청 접수';
  String get periodShort => alwaysOpen ? '상시 신청' : '신청 ~ 2026.12.31';
  String get periodLong => alwaysOpen ? '상시 신청 가능' : '2026년 12월 31일(목) 까지 · 예산 소진 시 마감';

  /// 배너 큰 제목: 괄호 앞 이름
  String get shortTitle {
    final i = name.indexOf('(');
    return (i > 4 ? name.substring(0, i) : name).trim();
  }

  /// 배너 한 줄 설명: 괄호 안 내용, 없으면 분야
  String get bannerLine {
    final m = RegExp(r'\(([^()]+)\)').firstMatch(name);
    return m?.group(1)?.trim() ?? '${category.label} 지원';
  }
}

/// 분야별 배너 색과 그림
({Color bg, Color bg2, Color accent, IconData icon}) policyStyle(PolicyCategory c) => switch (c) {
      PolicyCategory.wedding => (
          bg: const Color(0xFFFFE6EC), bg2: const Color(0xFFFFF7F9), accent: const Color(0xFFD9466B),
          icon: Icons.celebration_outlined),
      PolicyCategory.cash => (
          bg: const Color(0xFFFFF0D4), bg2: const Color(0xFFFFFAF0), accent: const Color(0xFFB86E00),
          icon: Icons.savings_outlined),
      PolicyCategory.housing => (
          bg: const Color(0xFFE2EAFF), bg2: const Color(0xFFF5F8FF), accent: const Color(0xFF3B5BDB),
          icon: Icons.apartment),
      PolicyCategory.health => (
          bg: const Color(0xFFDDF3E8), bg2: const Color(0xFFF4FBF7), accent: const Color(0xFF1B8A5A),
          icon: Icons.health_and_safety_outlined),
      PolicyCategory.education => (
          bg: const Color(0xFFECE6FF), bg2: const Color(0xFFF8F6FF), accent: const Color(0xFF6E4BD8),
          icon: Icons.school_outlined),
      PolicyCategory.etc => (
          bg: const Color(0xFFE9ECEF), bg2: const Color(0xFFF8F9FA), accent: const Color(0xFF495057),
          icon: Icons.volunteer_activism_outlined),
    };

/// 공고 배너: 기관 · 접수 상태 · 큰 제목 · 한 줄 설명 · 신청 기간, 오른쪽에 분야 그림
class PolicyBanner extends StatelessWidget {
  const PolicyBanner({super.key, required this.policy, this.showFavorite = true});

  final Policy policy;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final p = policy;
    final st = policyStyle(p.category);
    return AspectRatio(
      aspectRatio: 1.62,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [st.bg2, st.bg],
            ),
          ),
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final scale = (w / 330).clamp(0.75, 1.3);
            return Stack(children: [
              // 오른쪽 그림: 겹친 원 + 분야 아이콘
              Positioned(
                right: -w * 0.08,
                bottom: -w * 0.1,
                child: Container(
                  width: w * 0.55,
                  height: w * 0.55,
                  decoration: BoxDecoration(color: st.accent.withValues(alpha: 0.08), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                right: w * 0.06,
                bottom: w * 0.07,
                child: Container(
                  width: w * 0.3,
                  height: w * 0.3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: st.accent.withValues(alpha: 0.15), blurRadius: 18)],
                  ),
                  child: Icon(st.icon, size: w * 0.15, color: st.accent),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16 * scale, 14 * scale, w * 0.36, 14 * scale),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.agency,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11 * scale, color: const Color(0xFF4E5968))),
                  SizedBox(height: 6 * scale),
                  _pill(p.statusLabel, st.accent, Colors.white, scale),
                  SizedBox(height: 8 * scale),
                  Text(p.shortTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18 * scale,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B2A4A),
                      )),
                  SizedBox(height: 4 * scale),
                  Text(p.bannerLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w700, color: st.accent)),
                  const Spacer(),
                  _pill(p.periodShort, const Color(0xFF1B2A4A), Colors.white, scale),
                ]),
              ),
              if (showFavorite)
                Positioned(right: 4, top: 4, child: FavoriteButton(ref: 'policy:${p.id}', onImage: true)),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg, double scale) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            maxLines: 1,
            style: TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w700, color: fg)),
      );
}

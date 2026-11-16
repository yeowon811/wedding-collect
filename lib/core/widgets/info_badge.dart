import 'package:flutter/material.dart';

/// "온라인 예약", "대관료 무료", "확인 필요" 같은 작은 표시 배지.
/// 연한 면 + 같은 계열의 진한 글자, 모서리 6 (디자인 시안 A).
class InfoBadge extends StatelessWidget {
  const InfoBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.background,
  });

  final String label;
  final Color color; // 글자·아이콘 색
  final IconData? icon;
  final Color? background; // 없으면 [color]의 연한 면

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, height: 1.2),
          ),
        ],
      ),
    );
  }
}

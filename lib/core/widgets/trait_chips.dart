import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 예식장 속성 배지 (Red Team P1-4, 2026-11-20): 사진이 안 열려도 어떤 곳인지 보이게, 데이터로 분류한 속성만 작게.
/// 이모지 대신 앱의 Material 아이콘 (실내 대강당 · 야외·잔디 · 외부 케이터링/피로연 · 주차 가능 · 대관료 무료)
class TraitChips extends StatelessWidget {
  const TraitChips(this.labels, {super.key, this.onImage = false});

  final List<String> labels;
  final bool onImage; // 사진 위에 얹을 때 (흰 바탕 반투명)

  static IconData iconOf(String label) {
    if (label.contains('대관료')) return Icons.money_off_outlined;
    if (label.contains('야외')) return Icons.park_outlined;
    if (label.contains('실내')) return Icons.meeting_room_outlined;
    if (label.contains('케이터링') || label.contains('피로연')) return Icons.restaurant_outlined;
    if (label.contains('주차')) return Icons.local_parking_outlined;
    return Icons.label_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 4, runSpacing: 4, children: [
      for (final l in labels)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: onImage ? Colors.white.withValues(alpha: 0.92) : AppColors.fill,
            borderRadius: BorderRadius.circular(6),
            border: onImage ? null : Border.all(color: AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(iconOf(l), size: 12, color: l.contains('대관료') ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(l,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: l.contains('대관료') ? AppColors.primary : AppColors.textBody,
                  )),
            ),
          ]),
        ),
    ]);
  }
}

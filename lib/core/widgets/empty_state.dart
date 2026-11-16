import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 결과가 없을 때: 왜 없는지 + 바로 할 수 있는 다음 행동 버튼
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.search_off_rounded,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final IconData icon;
  final List<EmptyAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.fill, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.textHint, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (var i = 0; i < actions.length; i++) ...[
              SizedBox(
                width: double.infinity,
                child: i == 0
                    ? FilledButton(onPressed: actions[i].onTap, child: Text(actions[i].label))
                    : OutlinedButton(onPressed: actions[i].onTap, child: Text(actions[i].label)),
              ),
              if (i < actions.length - 1) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class EmptyAction {
  const EmptyAction(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

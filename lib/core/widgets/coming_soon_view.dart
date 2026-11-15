import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 아직 만들지 않은 기능 탭에 보여 주는 안내 화면.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.plannedItems,
  });

  final String title;
  final IconData icon;
  final String description;
  final List<String> plannedItems;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(icon, size: 56, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          const Text(
            '만들 예정인 기능',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          for (final item in plannedItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: AppColors.textSecondary)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

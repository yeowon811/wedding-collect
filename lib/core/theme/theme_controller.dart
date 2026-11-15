import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// 디자인 시안 전환 (시연·비교용). 확정 후에는 지워도 된다.
class ThemeController extends ValueNotifier<AppPalette> {
  ThemeController._() : super(AppColors.palette);

  static final instance = ThemeController._();

  void select(AppPalette palette) {
    AppColors.palette = palette;
    value = palette;
  }
}

/// 상단에 두는 "시안 바꾸기" 버튼
class PaletteButton extends StatelessWidget {
  const PaletteButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return PopupMenuButton<AppPalette>(
      tooltip: '디자인 시안 바꾸기',
      icon: Icon(Icons.palette_outlined, color: AppColors.primaryDark),
      onSelected: controller.select,
      itemBuilder: (_) => [
        for (final p in AppPalette.all)
          PopupMenuItem(
            value: p,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [p.headerStart, p.primary]),
                  ),
                ),
                const SizedBox(width: 10),
                Text(p.label),
                if (p.id == controller.value.id) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

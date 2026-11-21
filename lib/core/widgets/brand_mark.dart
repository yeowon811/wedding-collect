import 'package:flutter/material.dart';

import '../../app/main_shell.dart';

/// 화면 왼쪽 위 링 로고 (11-21 사용자 요청: 각 탭 왼쪽 위에 로고). 누르면 홈으로. AppBar leading 자리에 넣는다
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  // AppBar leading 칸은 크기가 고정이라 가운데 놓아 그림이 늘어나지 않게
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Center(
          child: Tooltip(
          message: '홈으로',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => MainShell.goTo(MainShell.home),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/images/brand/rings_rose.png',
                height: 22,
                semanticLabel: 'We Connect',
                errorBuilder: (_, _, _) => const SizedBox(width: 22),
              ),
            ),
          ),
          ),
        ),
      );
}

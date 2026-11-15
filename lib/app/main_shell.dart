import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../data/repositories/repositories.dart';
import '../features/chat/chat_screen.dart';
import '../features/checklist/checklist_screen.dart';
import '../features/policy/policy_screen.dart';
import '../features/vendor/vendor_screen.dart';
import '../features/venue/venue_home_screen.dart';

/// 하단 탭으로 기능을 나눈 앱의 기본 틀
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.palette});

  /// 시안이 바뀌어도 선택한 탭이 유지되도록 같은 키를 쓴다
  static final shellKey = GlobalKey<State<MainShell>>();

  final AppPalette palette;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 시안이 바뀌면 화면들을 새 색으로 다시 만든다. 탭 위치는 유지된다.
      body: KeyedSubtree(
        key: ValueKey(widget.palette.id),
        child: IndexedStack(
          index: _index,
          children: [
            VenueHomeScreen(repository: Repos.venue),
            PolicyScreen(repository: Repos.policy),
            const VendorScreen(),
            const ChecklistScreen(),
            const ChatScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.location_city_outlined),
            selectedIcon: Icon(Icons.location_city),
            label: '예식장',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism),
            label: '정책',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: '업체',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl),
            label: '체크리스트',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI 상담',
          ),
        ],
      ),
    );
  }
}

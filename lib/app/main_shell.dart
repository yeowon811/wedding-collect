import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'demo_links.dart';
import '../data/repositories/repositories.dart';
import '../features/chat/chat_screen.dart';
import '../features/checklist/checklist_screen.dart';
import '../features/policy/policy_screen.dart';
import '../features/vendor/vendor_screen.dart';
import '../features/venue/venue_home_screen.dart';

/// 하단 탭으로 기능을 나눈 앱의 기본 틀
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// 다른 화면에서 탭을 바꿀 때 사용 (예: 예식장 화면의 "AI 상담" 배너)
  static final tab = ValueNotifier<int>(
      (int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? 0).clamp(0, 4)); // 웹 ?tab=N (캡처·시연용)

  static void goTo(int index) => tab.value = index;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int get _index => MainShell.tab.value;

  @override
  void initState() {
    super.initState();
    MainShell.tab.addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => DemoLinks.openDetail(Navigator.of(context)));
  }

  @override
  void dispose() {
    MainShell.tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          VenueHomeScreen(repository: Repos.venue),
          PolicyScreen(repository: Repos.policy),
          const VendorScreen(),
          const ChecklistScreen(),
          const ChatScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: MainShell.goTo,
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
      ),
    );
  }
}

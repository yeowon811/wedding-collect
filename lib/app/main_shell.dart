import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'demo_links.dart';
import '../features/intro/lookbook_ad.dart';
import '../data/repositories/repositories.dart';
import '../features/browse/browse_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/checklist/checklist_screen.dart';
import '../features/home/home_screen.dart';
import '../features/policy/policy_screen.dart';

/// 하단 탭으로 기능을 나눈 앱의 기본 틀.
///
/// 탭 번호는 예전 그대로 둔다 (다른 화면·시연 링크 ?tab=N·공유 링크가 이 번호를 씀):
/// 0 예식장 · 1 정책 · 2 업체 · 3 체크리스트 · 4 AI 상담 · 5 홈 (링크 없이 열면 홈).
/// 예식장(0)과 업체(2)는 한 탭 '예식장·업체'(BrowseScreen)의 두 쪽이다 (11-21 합침):
/// goTo(0)은 공공예식장 쪽, goTo(2)는 웨딩업체 쪽을 연다. 아래 탭을 직접 누르면 마지막에 본 쪽 그대로.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const home = 5;
  static const vendor = 2;

  /// 지금 보이는 탭 번호 (2는 쓰지 않는다: 0 + 웨딩업체 쪽으로 바꿈)
  static final tab = ValueNotifier<int>(_initial());

  static int _initial() {
    final t = (int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? home).clamp(0, 5); // 웹 ?tab=N (캡처·시연용)
    if (t == vendor) {
      BrowseScreen.segment.value = 1;
      return 0;
    }
    return t;
  }

  /// 다른 화면에서 탭을 바꿀 때 (0 = 공공예식장 쪽, 2 = 웨딩업체 쪽)
  static void goTo(int index) {
    if (index == 0 || index == vendor) {
      BrowseScreen.segment.value = index == vendor ? 1 : 0;
      tab.value = 0;
      return;
    }
    tab.value = index;
  }

  /// 아래 탭 순서 → 탭 번호
  static const navOrder = [home, 0, 1, 3, 4];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int get _index => MainShell.tab.value == MainShell.vendor ? 0 : MainShell.tab.value;

  @override
  void initState() {
    super.initState();
    MainShell.tab.addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DemoLinks.openDetail(Navigator.of(context));
      // 로그인(또는 둘러보기)하고 앱에 들어오면 룩북 광고 (앱을 켤 때 한 번)
      if (mounted) LookbookAd.showIfNeeded(context);
    });
  }

  @override
  void dispose() {
    MainShell.tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    // tab.value = 2를 직접 넣은 경우도 웨딩업체 쪽으로
    if (MainShell.tab.value == MainShell.vendor) {
      MainShell.goTo(MainShell.vendor);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const BrowseScreen(), // 0 예식장·업체
          PolicyScreen(repository: Repos.policy),
          const SizedBox.shrink(), // 2 업체: 0의 웨딩업체 쪽
          const ChecklistScreen(),
          const ChatScreen(),
          const HomeScreen(),
        ],
      ),
      // 모바일에서 키보드가 올라와 있으면 하단 탭을 숨겨 대화가 보이는 영역을 넓힌다
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        child: NavigationBar(
        selectedIndex: MainShell.navOrder.indexOf(_index).clamp(0, MainShell.navOrder.length - 1),
        // 아래 탭을 직접 누르면 쪽(예식장/업체)은 그대로 두고 탭만 바꾼다
        onDestinationSelected: (i) => MainShell.tab.value = MainShell.navOrder[i],
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_city_outlined),
            selectedIcon: Icon(Icons.location_city),
            label: '예식장·업체',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism),
            label: '정책',
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

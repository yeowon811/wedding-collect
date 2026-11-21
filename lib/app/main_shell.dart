import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'demo_links.dart';
import '../features/intro/lookbook_ad.dart';
import '../data/repositories/repositories.dart';
import '../features/chat/chat_screen.dart';
import '../features/checklist/checklist_screen.dart';
import '../features/home/home_screen.dart';
import '../features/policy/policy_screen.dart';
import '../features/vendor/vendor_screen.dart';
import '../features/venue/venue_home_screen.dart';

/// 하단 탭으로 기능을 나눈 앱의 기본 틀.
///
/// 탭 번호는 예전 그대로 둔다 (다른 화면·시연 링크 ?tab=N·공유 링크가 이 번호를 씀):
/// 0 예식장 · 1 정책 · 2 업체 · 3 체크리스트 · 4 AI 상담 · 5 홈 (2026-11-21 추가, 링크 없이 열면 홈).
/// 아래 탭에는 홈 · 예식장 · 정책 · 체크리스트 · AI 상담만 두고, 업체(2)는 홈 바로가기에서 화면으로 연다.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const home = 5;
  static const vendor = 2;

  /// 다른 화면에서 탭을 바꿀 때 사용 (예: 예식장 화면의 "AI 상담" 배너)
  static final tab = ValueNotifier<int>(
      (int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? home).clamp(0, 5)); // 웹 ?tab=N (캡처·시연용)

  static void goTo(int index) => tab.value = index;

  /// 아래 탭 순서 → 탭 번호
  static const navOrder = [home, 0, 1, 3, 4];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int get _index => MainShell.tab.value;
  int _lastTab = MainShell.home; // 업체 화면을 닫으면 돌아갈 탭

  @override
  void initState() {
    super.initState();
    if (_index != MainShell.vendor) _lastTab = _index;
    MainShell.tab.addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_index == MainShell.vendor) _openVendor();
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
    if (_index == MainShell.vendor) {
      _openVendor();
      return;
    }
    _lastTab = _index;
    setState(() {});
  }

  /// 업체는 아래 탭에 없어 화면으로 연다 (뒤로 가기 = 원래 탭)
  void _openVendor() {
    MainShell.tab.value = _lastTab;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VendorScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _index == MainShell.vendor ? _lastTab : _index;
    return Scaffold(
      body: IndexedStack(
        index: shown,
        children: [
          VenueHomeScreen(repository: Repos.venue),
          PolicyScreen(repository: Repos.policy),
          const SizedBox.shrink(), // 2 업체: 화면으로 연다
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
        selectedIndex: MainShell.navOrder.indexOf(shown).clamp(0, MainShell.navOrder.length - 1),
        onDestinationSelected: (i) => MainShell.goTo(MainShell.navOrder[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
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

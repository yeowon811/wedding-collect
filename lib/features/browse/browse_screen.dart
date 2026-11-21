import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/repositories/repositories.dart';
import '../auth/login_screen.dart';
import '../favorites/favorites_screen.dart';
import '../vendor/vendor_screen.dart';
import '../venue/venue_home_screen.dart';

/// 예식장·업체 찾기 (11-21 사용자 요청: 예식장·업체 탭 합침).
/// 제목 아래 전환 버튼 [공공예식장 | 웨딩업체]로 한 쪽 목록만 보여 준다. 두 화면은 그대로 살려 두어(IndexedStack)
/// 전환해도 검색어·지역·항목 선택이 남는다. 다른 화면에서 업체를 열면(MainShell.goTo(2)) 웨딩업체 쪽이 열린다.
class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  /// 0 공공예식장 · 1 웨딩업체 (마지막에 본 쪽을 기억)
  static final segment = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 4, 0),
            child: SizedBox(
              height: 48,
              child: NavigationToolbar(
                centerMiddle: true,
                middleSpacing: 8,
                leading: const SizedBox(width: 56, child: BrandMark()), // 다른 탭 AppBar의 leadingWidth와 같게
                middle: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '예식장·업체 찾기',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                trailing: const Row(mainAxisSize: MainAxisSize.min, children: [FavoritesAction(), AccountButton()]),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: _SegmentSwitch(),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: segment,
              builder: (context, i, _) => IndexedStack(
                index: i,
                children: [
                  VenueHomeScreen(repository: Repos.venue, embedded: true),
                  const VendorScreen(embedded: true),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// [공공예식장 | 웨딩업체] 전환 버튼 (연한 면 위에 고른 쪽만 흰 칸 + 포인트 글자)
class _SegmentSwitch extends StatelessWidget {
  const _SegmentSwitch();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BrowseScreen.segment,
      builder: (context, at, _) => Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (final (i, label, icon) in const [
            (0, '공공예식장', Icons.location_city_outlined),
            (1, '웨딩업체', Icons.storefront_outlined),
          ])
            Expanded(
              child: Semantics(
                selected: at == i,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => BrowseScreen.segment.value = i,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: at == i ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: at == i ? Border.all(color: AppColors.border) : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 18, color: at == i ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: at == i ? FontWeight.w800 : FontWeight.w600,
                            color: at == i ? AppColors.primary : AppColors.textSecondary,
                          )),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

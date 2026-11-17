import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/grid.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/region.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/repositories/repositories.dart';
import 'compare_screen.dart';
import 'demo_vendor_detail_screen.dart';
import 'real_vendor_detail_screen.dart';
import 'widgets/vendor_cards.dart';

/// 업체 찾기: 지역 → 항목 → 한 목록. 실제 연계업체(공식전담 먼저)와 시연용 업체(가격·후기·상담)를 함께 보여준다.
class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  static String? _savedSido;
  static VendorCategory? _savedCategory;

  late final Future<(List<DemoVendor>, List<RealVendor>)> _future = () async {
    return (await Repos.vendor.demoVendors(), await Repos.vendor.realVendors());
  }();

  String _sido = _savedSido ?? AppState.instance.plan.sido;
  VendorCategory? _category = _savedCategory;
  String _sort = 'rating'; // rating / price

  void _set(void Function() f) => setState(() {
        f();
        _savedSido = _sido;
        _savedCategory = _category;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('업체 찾기'),
        actions: const [AccountButton()],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('데이터를 불러오지 못했어요\n${snap.error}'));
          if (!snap.hasData) return const SkeletonList(header: false);
          final (demo, real) = snap.data!;
          return Column(
            children: [
              _sidoChips(),
              _categoryChips(),
              Expanded(child: _list(demo, real)),
              _compareBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _sidoChips() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          for (final s in kSidoList)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(s),
                selected: _sido == s,
                showCheckmark: false,
                onSelected: (_) => _set(() => _sido = s),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    const cats = VendorCategory.vendorChips;
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('전체 항목'),
              selected: _category == null,
              showCheckmark: false,
              onSelected: (_) => _set(() => _category = null),
            ),
          ),
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: Icon(c.icon, size: 16),
                label: Text(c.label),
                selected: _category == c,
                showCheckmark: false,
                onSelected: (_) => _set(() => _category = _category == c ? null : c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _list(List<DemoVendor> allDemo, List<RealVendor> allReal) {
    final demo = allDemo
        .where((v) => v.sido == _sido && (_category == null || v.category == _category))
        .toList();
    if (_sort == 'price') {
      demo.sort((a, b) => a.priceMin.compareTo(b.priceMin));
    } else {
      demo.sort((a, b) => b.rating.compareTo(a.rating));
    }
    // 실제 연계업체: 공식전담 먼저, 그다음 대표 사진이 있는 곳
    int rank(RealVendor v) => (v.isOfficial ? 2 : 0) + (v.image != null ? 1 : 0);
    final real = allReal
        .where((v) => sidoMatches(v.sido, _sido) && (_category == null || _category!.coversReal(v.category)))
        .toList()
      ..sort((a, b) => rank(b) - rank(a));
    final total = demo.length + real.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(
            children: [
              Text('$_sido ${_category?.label ?? '전체'} $total곳',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              DropdownButton<String>(
                value: _sort,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'rating', child: Text('평점순')),
                  DropdownMenuItem(value: 'price', child: Text('낮은 가격순')),
                ],
                onChanged: (v) => setState(() => _sort = v!),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            real.isEmpty
                ? '시연용 가상 업체예요 (가격·평점 임의 생성)'
                : '실제 연계 업체 ${real.length}곳 먼저 · [시연] 업체는 가격·평점을 임의로 만든 가상 업체예요',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        if (total == 0)
          EmptyState(
            icon: Icons.storefront_outlined,
            title: '$_sido에는 이 항목 업체가 없어요',
            message: '다른 항목이나 가까운 지역을 골라 보세요.',
            actions: [EmptyAction('전체 항목 보기', () => _set(() => _category = null))],
          ),
        TileGrid(children: [
          for (final v in real)
            RealVendorTile(
              vendor: v,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RealVendorDetailScreen(vendor: v)),
              ),
            ),
          for (final v in demo)
            DemoVendorCard(
              vendor: v,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DemoVendorDetailScreen(vendor: v)),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _compareBar() {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (state.compare.isEmpty) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.compare.first.category.label} ${state.compare.length}곳 담음 (최대 3곳)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(onPressed: state.clearCompare, child: const Text('비우기')),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
                  onPressed: state.compare.length < 2
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CompareScreen()),
                          ),
                  child: const Text('비교하기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

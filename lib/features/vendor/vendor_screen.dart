import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../favorites/favorites_screen.dart';
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

/// 업체 찾기: 지역 → 항목 → 한 목록. [시연] 업체 6곳 → 실제 연계업체(공식전담 먼저) → 나머지 [시연] 업체 순으로 함께 보여준다.
class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key, this.embedded = false});

  /// 예식장·업체 둘러보기 화면 안에 들어갈 때: 제목 줄(AppBar)은 그 화면이 그린다 (11-21 합침)
  final bool embedded;

  /// 체크리스트 등에서 "이 항목 업체 찾기"로 열 때 고를 항목
  static final categoryRequest = ValueNotifier<VendorCategory?>(null);

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

  void _onCategoryRequest() {
    final c = VendorScreen.categoryRequest.value;
    if (c == null) return;
    VendorScreen.categoryRequest.value = null;
    _set(() {
      _category = c;
      if (AppState.instance.plan.hasSido) _sido = AppState.instance.plan.sido;
    });
  }

  @override
  void initState() {
    super.initState();
    VendorScreen.categoryRequest.addListener(_onCategoryRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCategoryRequest());
  }

  @override
  void dispose() {
    VendorScreen.categoryRequest.removeListener(_onCategoryRequest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('업체 찾기'),
              actions: const [FavoritesAction(), AccountButton()],
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
                label: Text(c.vendorLabel),
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
    // 순서 (11-21 사용자 요청): [시연] 업체 6곳을 맨 위에 → 실제 연계업체 → 나머지 [시연] 업체.
    // 실제 업체는 가격·상담 정보가 없어 둘러보기 어렵고, 시연 업체로 가격 비교·상담 흐름을 먼저 보여 준다
    const demoFirst = 6;
    final demoTop = demo.take(demoFirst).toList();
    final demoRest = demo.skip(demoFirst).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(
            children: [
              Text('$_sido ${_category?.vendorLabel ?? '전체'} $total곳',
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
                : '[시연] 업체 ${demoTop.length}곳 먼저, 그다음 실제 연계 업체 ${real.length}곳 · [시연] 업체는 가격·평점을 임의로 만든 가상 업체예요',
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
          for (final v in demoTop) _demoCard(v),
          for (final v in real)
            RealVendorTile(
              vendor: v,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RealVendorDetailScreen(vendor: v)),
              ),
            ),
          for (final v in demoRest) _demoCard(v),
        ]),
      ],
    );
  }

  Widget _demoCard(DemoVendor v) => DemoVendorCard(
        vendor: v,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DemoVendorDetailScreen(vendor: v)),
        ),
      );

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
                    '${state.compare.first.category.vendorLabel} ${state.compare.length}곳 담음 (최대 3곳)',
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

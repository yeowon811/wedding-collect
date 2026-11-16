import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/region.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/repositories/repositories.dart';
import 'compare_screen.dart';
import 'demo_vendor_detail_screen.dart';
import 'real_vendor_detail_screen.dart';
import 'widgets/vendor_cards.dart';

enum VendorMode { demo, real }

/// 업체 찾기: 지역 → 항목 → 목록. 시연용(가격 비교·상담)과 실제 연계업체를 나눠 보여준다.
class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  static VendorMode _savedMode = VendorMode.demo;
  static String? _savedSido;
  static VendorCategory? _savedCategory;

  late final Future<(List<DemoVendor>, List<RealVendor>)> _future = () async {
    return (await Repos.vendor.demoVendors(), await Repos.vendor.realVendors());
  }();

  VendorMode _mode = _savedMode;
  String _sido = _savedSido ?? AppState.instance.plan.sido;
  VendorCategory? _category = _savedCategory;
  String _sort = 'rating'; // rating / price

  void _set(void Function() f) => setState(() {
        f();
        _savedMode = _mode;
        _savedSido = _sido;
        _savedCategory = _category;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('업체 찾기'),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('데이터를 불러오지 못했어요\n${snap.error}'));
          if (!snap.hasData) return const SkeletonList(header: false);
          final (demo, real) = snap.data!;
          return Column(
            children: [
              _modeSwitch(),
              _sidoChips(),
              _categoryChips(),
              Expanded(
                child: _mode == VendorMode.demo ? _demoList(demo) : _realList(real),
              ),
              _compareBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _modeSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SegmentedButton<VendorMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: VendorMode.demo,
            icon: Icon(Icons.price_change_outlined),
            label: Text('가격 비교 (시연용)'),
          ),
          ButtonSegment(
            value: VendorMode.real,
            icon: Icon(Icons.verified_outlined),
            label: Text('실제 연계 업체'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (s) => _set(() {
          _mode = s.first;
          _category = null;
        }),
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
    final cats = _mode == VendorMode.demo ? VendorCategory.planItems : VendorCategory.realGroups;
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

  Widget _demoList(List<DemoVendor> all) {
    final list = all
        .where((v) => v.sido == _sido && (_category == null || v.category == _category))
        .toList();
    if (_sort == 'price') {
      list.sort((a, b) => a.priceMin.compareTo(b.priceMin));
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(
            children: [
              Text('$_sido ${_category?.label ?? '전체'} ${list.length}곳',
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            '가격·평점은 시연을 위해 임의로 만든 값이에요. 실제 업체가 아니에요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        for (final v in list)
          DemoVendorCard(
            vendor: v,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DemoVendorDetailScreen(vendor: v)),
            ),
          ),
      ],
    );
  }

  Widget _realList(List<RealVendor> all) {
    final list = all
        .where((v) => sidoMatches(v.sido, _sido) && (_category == null || v.category == _category))
        .toList()
      ..sort((a, b) => (b.isOfficial ? 1 : 0) - (a.isOfficial ? 1 : 0));
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text('$_sido 실제 연계 업체 ${list.length}곳',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            '공공예식장과 연계된 실제 업체예요. 가격은 공개 정보가 없어 표시하지 않아요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.storefront_outlined,
            title: '$_sido에는 등록된 실제 연계 업체가 없어요',
            message: '위에서 가까운 지역을 고르거나, 시연용 가격 비교로 업체를 살펴보세요.',
            actions: [
              EmptyAction('가격 비교(시연용) 보기', () => _set(() => _mode = VendorMode.demo)),
            ],
          ),
        for (final v in list)
          RealVendorCard(
            vendor: v,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RealVendorDetailScreen(vendor: v)),
            ),
          ),
      ],
    );
  }

  Widget _compareBar() {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (state.compare.isEmpty || _mode != VendorMode.demo) return const SizedBox.shrink();
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

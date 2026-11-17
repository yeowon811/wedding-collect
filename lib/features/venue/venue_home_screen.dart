import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/grid.dart';
import '../../core/widgets/inputs.dart';
import '../favorites/favorites_screen.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/app_state.dart';
import '../../data/models/venue.dart';
import '../../data/repositories/venue_repository.dart';
import 'venue_detail_screen.dart';
import 'widgets/venue_card.dart';

/// 공공예식장 찾기: 검색 + AI 추천 배너 + 시도 → 시군구(서울이면 강남구·강동구 …) + 목록
class VenueHomeScreen extends StatefulWidget {
  const VenueHomeScreen({super.key, required this.repository});

  final VenueRepository repository;

  @override
  State<VenueHomeScreen> createState() => _VenueHomeScreenState();
}

class _VenueHomeScreenState extends State<VenueHomeScreen> {
  late final Future<List<Venue>> _future = widget.repository.loadAll();

  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? _sido; // null = 전체
  String? _sigungu; // null = 시도 전체

  List<Venue> _apply(List<Venue> all) {
    final q = _query.trim();
    return all.where((v) {
      if (_sido != null && v.sido != _sido) return false;
      if (_sigungu != null && v.sigungu != _sigungu) return false;
      if (q.isNotEmpty &&
          !v.name.contains(q) &&
          !v.address.contains(q) &&
          !v.region.contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _selectSido(String? sido) => setState(() {
    _sido = sido;
    _sigungu = null; // 시도가 바뀌면 시군구 선택은 초기화
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Venue>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('데이터를 불러오지 못했어요\n${snap.error}'));
            }
            if (!snap.hasData) {
              return const SkeletonList(kind: SkeletonKind.photoCard, count: 2);
            }
            final all = snap.data!;
            final shown = _apply(all);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(all)),
                SliverToBoxAdapter(child: _searchBar()),
                SliverToBoxAdapter(child: _aiBanner()),
                SliverToBoxAdapter(child: _sidoChips(all)),
                SliverToBoxAdapter(child: _resultBar(shown.length)),
                if (shown.isEmpty)
                  SliverToBoxAdapter(child: _empty())
                else
                  // 2열 격자 (넓은 화면에서는 열이 늘어남). 칸 높이 = 카드 폭(정사각형 사진) + 글자 영역
                  SliverLayoutBuilder(builder: (context, box) {
                    final spec = GridSpec.of(box.crossAxisExtent);
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(GridSpec.sidePadding, 12, GridSpec.sidePadding, 0),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: spec.columns,
                          crossAxisSpacing: GridSpec.gap,
                          mainAxisSpacing: 20,
                          mainAxisExtent: spec.tileWidth + VenueCard.textHeight,
                        ),
                        itemCount: shown.length,
                        itemBuilder: (context, i) => VenueCard(
                          venue: shown[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: shown[i])),
                          ),
                        ),
                      ),
                    );
                  }),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(List<Venue> all) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'We Connect',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const FavoritesAction(),
              const AccountButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: '예식장 이름, 지역 검색',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
  }

  /// 내 조건으로 AI 추천받기 → AI 상담 탭
  Widget _aiBanner() {
    final app = AppState.instance;
    final summary = app.profileDone ? app.profile.summary : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => MainShell.goTo(4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '내 조건으로 추천받기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.isEmpty
                            ? '지역·하객 수·예산을 알려주면 AI가 골라 드려요'
                            : summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => MainShell.goTo(4),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('AI 상담'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidoChips(List<Venue> all) {
    // 예식장이 많은 지역부터
    final counts = <String, int>{};
    for (final v in all) {
      counts[v.sido] = (counts[v.sido] ?? 0) + 1;
    }
    final sidos = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
        children: [
          _choice('전체', _sido == null, () => _selectSido(null)),
          for (final s in sidos)
            _choice(
              // 고른 시군구가 있으면 칩에 함께 표시: "서울 · 강남구 ▾"
              _sido == s && _sigungu != null ? '$s · $_sigungu' : '$s ${counts[s]}',
              _sido == s,
              () => _pickRegion(all, s),
              hasMenu: true,
            ),
        ],
      ),
    );
  }

  /// 시도 칩을 누르면: 시군구가 2곳 이상이면 선택창(고르고 확인), 아니면 바로 적용
  Future<void> _pickRegion(List<Venue> all, String sido) async {
    final counts = <String, int>{};
    for (final v in all.where((v) => v.sido == sido && v.sigungu.isNotEmpty)) {
      counts[v.sigungu] = (counts[v.sigungu] ?? 0) + 1;
    }
    if (counts.length < 2) {
      _selectSido(sido);
      return;
    }
    final total = all.where((v) => v.sido == sido).length;
    final picked = await showModalBottomSheet<(String?,)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RegionSheet(
        sido: sido,
        total: total,
        counts: counts,
        initial: _sido == sido ? _sigungu : null,
      ),
    );
    if (picked == null || !mounted) return; // 닫기·취소
    setState(() {
      _sido = sido;
      _sigungu = picked.$1;
    });
  }

  /// 시도 칩: 회색 알약, 선택되면 검정
  Widget _choice(String label, bool selected, VoidCallback onTap, {bool hasMenu = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: hasMenu && selected
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more, size: 18, color: Colors.white),
              ])
            : Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  /// 결과가 없을 때: 원인에 맞는 다음 행동을 제안한다
  Widget _empty() {
    final where = [
      if (_sido != null) _sido!,
      if (_sigungu != null) _sigungu!,
    ].join(' ');
    final q = _query.trim();
    return EmptyState(
      title: q.isNotEmpty ? "'$q' 검색 결과가 없어요" : '$where에는 등록된 공공예식장이 없어요',
      message: q.isNotEmpty
          ? '이름의 일부만 적거나(예: "시청") 지역 이름으로 찾아보세요.'
          : '가까운 지역의 공공예식장을 살펴보거나, AI 상담에서 조건에 맞는 곳을 물어보세요.',
      actions: [
        if (q.isNotEmpty)
          EmptyAction('검색어 지우기', () {
            _search.clear();
            setState(() => _query = '');
          }),
        if (_sigungu != null)
          EmptyAction('$_sido 전체 보기', () => setState(() => _sigungu = null)),
        if (_sido != null) EmptyAction('전국 보기', () => _selectSido(null)),
        EmptyAction('AI 상담에서 물어보기', () => MainShell.goTo(4)),
      ],
    );
  }

  Widget _resultBar(int count) {
    final where = [
      if (_sido != null) _sido!,
      if (_sigungu != null) _sigungu!,
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
      child: Row(
        children: [
          Text(
            where.isEmpty ? '전체 $count곳' : '$where $count곳',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (_sido != null)
            TextButton(
              onPressed: () => _selectSido(null),
              child: const Text('지역 초기화'),
            ),
        ],
      ),
    );
  }
}

/// 시군구 선택창: 하나 고르고 [확인]. 결과는 (시군구 또는 null=시도 전체,)
class _RegionSheet extends StatefulWidget {
  const _RegionSheet({required this.sido, required this.total, required this.counts, this.initial});

  final String sido;
  final int total;
  final Map<String, int> counts;
  final String? initial;

  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  late String? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final names = widget.counts.keys.toList()..sort();
    Widget option(String? value, String label, int n) {
      final on = _picked == value;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _picked = value),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.ink : AppColors.fill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              TextSpan(text: ' $n', style: TextStyle(color: on ? Colors.white70 : AppColors.textSecondary)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('${widget.sido} 시·군·구 선택',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: [
                option(null, '${widget.sido} 전체', widget.total),
                for (final g in names) option(g, g, widget.counts[g]!),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: ActionPair(
              secondary: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              primary: FilledButton(
                onPressed: () => Navigator.pop(context, (_picked,)),
                child: const Text('확인'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

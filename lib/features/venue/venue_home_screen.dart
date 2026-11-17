import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/grid.dart';
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
                if (_sido != null)
                  SliverToBoxAdapter(child: _sigunguChips(all)),
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
    final free = all.where((v) => v.isFree).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '공공예식장',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const AccountButton(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '전국 ${all.length}곳 · 대관료 무료 $free곳',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
              '$s ${counts[s]}',
              _sido == s,
              () => _selectSido(_sido == s ? null : s),
            ),
        ],
      ),
    );
  }

  /// 선택한 시도 안의 시군구 (가나다순). 시군구가 하나뿐인 지역(세종 등)은 보여주지 않는다.
  Widget _sigunguChips(List<Venue> all) {
    final counts = <String, int>{};
    for (final v in all.where((v) => v.sido == _sido && v.sigungu.isNotEmpty)) {
      counts[v.sigungu] = (counts[v.sigungu] ?? 0) + 1;
    }
    if (counts.length < 2) return const SizedBox.shrink();
    final names = counts.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$_sido 시·군·구 ${names.length}곳',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _subChip(
                '전체',
                _sigungu == null,
                () => setState(() => _sigungu = null),
              ),
              for (final g in names)
                _subChip(
                  '$g ${counts[g]}',
                  _sigungu == g,
                  () => setState(() => _sigungu = _sigungu == g ? null : g),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 시도 칩: 회색 알약, 선택되면 검정
  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  /// 시군구 칩: 흰 바탕 + 테두리, 선택되면 진한 테두리 (시도 칩보다 한 단계 낮은 선택)
  Widget _subChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.white,
      selectedColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(
        color: selected ? AppColors.ink : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.ink : AppColors.textBody,
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

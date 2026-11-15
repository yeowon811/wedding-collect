import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/models/venue.dart';
import '../../data/repositories/venue_repository.dart';
import 'venue_detail_screen.dart';
import 'widgets/venue_card.dart';

/// 공공예식장 찾기: 검색 + 시도 → 시군구(서울이면 강남구·강동구 …) + 목록
class VenueHomeScreen extends StatefulWidget {
  const VenueHomeScreen({super.key, required this.repository});

  final VenueRepository repository;

  @override
  State<VenueHomeScreen> createState() => _VenueHomeScreenState();
}

class _VenueHomeScreenState extends State<VenueHomeScreen> {
  late final Future<List<Venue>> _future = widget.repository.loadAll();

  String _query = '';
  String? _sido; // null = 전체
  String? _sigungu; // null = 시도 전체

  List<Venue> _apply(List<Venue> all) {
    final q = _query.trim();
    return all.where((v) {
      if (_sido != null && v.sido != _sido) return false;
      if (_sigungu != null && v.sigungu != _sigungu) return false;
      if (q.isNotEmpty && !v.name.contains(q) && !v.address.contains(q) && !v.region.contains(q)) {
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
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!;
            final shown = _apply(all);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(all.length)),
                SliverToBoxAdapter(child: _searchBar()),
                SliverToBoxAdapter(child: _sidoChips(all)),
                if (_sido != null) SliverToBoxAdapter(child: _sigunguChips(all)),
                SliverToBoxAdapter(child: _resultBar(shown.length)),
                if (shown.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('조건에 맞는 예식장이 없어요')),
                  )
                else
                  SliverList.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) => VenueCard(
                      venue: shown[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VenueDetailScreen(venue: shown[i]),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '공공예식장 찾기',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const PaletteButton(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '전국 $total곳 · 지역을 고르면 시·군·구별로 볼 수 있어요',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: '예식장 이름, 지역, 주소로 검색',
          prefixIcon: Icon(Icons.search, color: AppColors.primary),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
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
    final sidos = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _choice('전체', _sido == null, () => _selectSido(null)),
          for (final s in sidos)
            _choice('$s ${counts[s]}', _sido == s, () => _selectSido(_sido == s ? null : s)),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text('$_sido 시·군·구 ${names.length}곳',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              _choice('전체', _sigungu == null, () => setState(() => _sigungu = null), pad: false),
              for (final g in names)
                _choice('$g ${counts[g]}', _sigungu == g,
                    () => setState(() => _sigungu = _sigungu == g ? null : g),
                    pad: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap, {bool pad = true}) {
    return Padding(
      padding: EdgeInsets.only(right: pad ? 6 : 0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: pad ? null : VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _resultBar(int count) {
    final where = [if (_sido != null) _sido!, if (_sigungu != null) _sigungu!].join(' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Text(
            where.isEmpty ? '$count곳' : '$where $count곳',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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

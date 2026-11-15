import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/app_state.dart';
import '../../data/models/venue.dart';
import '../../data/repositories/venue_repository.dart';
import 'venue_detail_screen.dart';
import 'widgets/booking_type_style.dart';
import 'widgets/venue_card.dart';

/// 공공예식장 찾기: 검색 + 지역·예약유형 필터 + 목록
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
  final Set<BookingType> _types = {};
  bool _fitGuests = false; // 내 하객 수 이상 수용
  bool _freeOnly = false; // 무료 대관
  bool _photoOnly = false; // 사진 있는 곳

  bool get _anyFilter => _sido != null || _types.isNotEmpty || _fitGuests || _freeOnly || _photoOnly;

  List<Venue> _apply(List<Venue> all) {
    final q = _query.trim();
    final guests = AppState.instance.plan.guests;
    final list = all.where((v) {
      // 값을 모르는 곳은 빼지 않고 아래로 보낸다 (확실히 안 맞는 곳만 제외)
      if (_fitGuests && v.fits(guests) == false) return false;
      if (_freeOnly && v.rentalFee != null && v.rentalFee! > 0) return false;
      if (_photoOnly && v.images.isEmpty) return false;
      if (_sido != null && v.sido != _sido) return false;
      if (_types.isNotEmpty && !_types.contains(v.bookingType)) return false;
      if (q.isNotEmpty &&
          !v.name.contains(q) &&
          !v.address.contains(q) &&
          !v.region.contains(q)) {
        return false;
      }
      return true;
    }).toList();
    if (_fitGuests || _freeOnly) {
      int unknown(Venue v) =>
          ((_fitGuests && v.capacity == null) ? 1 : 0) + ((_freeOnly && v.rentalFee == null) ? 1 : 0);
      list.sort((a, b) => unknown(a).compareTo(unknown(b)));
    }
    return list;
  }

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
                SliverToBoxAdapter(child: _typeChips()),
                SliverToBoxAdapter(child: _conditionChips()),
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
            '전국 $total곳 · 예약 방법을 한눈에 비교해요',
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
    final sidos = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _choice('전체', _sido == null, () => setState(() => _sido = null)),
          for (final s in sidos)
            _choice('$s ${counts[s]}', _sido == s,
                () => setState(() => _sido = _sido == s ? null : s)),
        ],
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _typeChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final t in BookingType.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                avatar: Icon(t.icon, size: 16, color: t.color),
                label: Text(t.label),
                selected: _types.contains(t),
                showCheckmark: false,
                onSelected: (on) => setState(() {
                  on ? _types.add(t) : _types.remove(t);
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _conditionChips() {
    final guests = AppState.instance.plan.guests;
    Widget chip(String label, IconData icon, bool on, ValueChanged<bool> set) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            avatar: Icon(icon, size: 16),
            label: Text(label),
            selected: on,
            showCheckmark: false,
            onSelected: (v) => setState(() => set(v)),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          chip('하객 $guests명 수용', Icons.groups_outlined, _fitGuests, (v) => _fitGuests = v),
          chip('무료 대관', Icons.money_off, _freeOnly, (v) => _freeOnly = v),
          chip('사진 있음', Icons.photo_outlined, _photoOnly, (v) => _photoOnly = v),
        ],
      ),
    );
  }

  Widget _resultBar(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Text(
            '$count곳',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const Spacer(),
          if (_anyFilter)
            TextButton(
              onPressed: () => setState(() {
                _sido = null;
                _types.clear();
                _fitGuests = _freeOnly = _photoOnly = false;
              }),
              child: const Text('필터 초기화'),
            ),
        ],
      ),
    );
  }
}

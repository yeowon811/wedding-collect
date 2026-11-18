import 'app_state.dart';
import 'models/wedding_plan.dart';
import 'repositories/repositories.dart';

/// 체크리스트 준비 항목에 담은 한 곳 (업체·예식장·직접 추가)
class CandidateInfo {
  const CandidateInfo({required this.ref, required this.name, required this.sub, this.price, required this.priceText});

  final String ref; // 'venue:H078' · 'vendor:D0001' · 'real:V003'
  final String name;
  final String sub;
  final int? price; // 만원, 모르면 null (실제 업체는 가격 공개 정보 없음)
  final String priceText;
}

/// 준비 항목마다 체크리스트에 담은 업체·예식장(+직접 추가)을 모아 준다 (데이터를 읽어 둔 뒤 바로 계산)
class Candidates {
  Candidates._();

  static List<CandidateInfo> forItem(PlanItem item, AppState s) {
    final fav = s.checklistRefs; // 체크리스트에 담은 곳 (찜과는 따로)
    if (item.id == AppState.venueItemId) {
      final venues = Repos.venue.cached ?? const [];
      return [
        for (final m in s.manualPlaces)
          if (m.itemId == item.id)
            CandidateInfo(
              ref: 'manual:${m.id}',
              name: m.name,
              sub: '직접 추가',
              price: m.amount,
              priceText: m.amount == null ? '금액 미입력' : '${m.amount}만원',
            ),
        for (final v in venues)
          if (fav.contains('venue:${v.id}'))
            CandidateInfo(
              ref: 'venue:${v.id}',
              name: v.name,
              sub: '${v.region} · ${v.capacityLabel}',
              price: v.rentalFee == null ? null : (v.rentalFee! / 10000).round(),
              priceText: v.feeLabel,
            ),
      ];
    }
    final manual = [
      for (final m in s.manualPlaces)
        if (m.itemId == item.id)
          CandidateInfo(
            ref: 'manual:${m.id}',
            name: m.name,
            sub: '직접 추가',
            price: m.amount,
            priceText: m.amount == null ? '금액 미입력' : '${m.amount}만원',
          ),
    ];
    final c = item.category;
    if (c == null) return manual;
    final guests = s.plan.guests;
    return [
      ...manual,
      for (final v in Repos.vendor.demoCached ?? const [])
        if (v.category == c && fav.contains('vendor:${v.id}'))
          CandidateInfo(
            ref: 'vendor:${v.id}',
            name: v.name.replaceFirst('[시연] ', ''),
            sub: '${v.sido} · ★${v.rating} · ${v.tier}',
            price: v.estimate(guests: guests),
            priceText: v.priceText,
          ),
      for (final v in Repos.vendor.realCached ?? const [])
        if (c.coversReal(v.category) && fav.contains('real:${v.id}'))
          CandidateInfo(
            ref: 'real:${v.id}',
            name: v.name,
            sub: '${v.sido} · ${v.isOfficial ? v.official : '실제 업체'}',
            priceText: '가격 문의',
          ),
    ];
  }

  /// "후보 2곳 · 120~180만원"
  static String summary(List<CandidateInfo> list) {
    final prices = [for (final c in list) if (c.price != null) c.price!]..sort();
    final range = prices.isEmpty
        ? ''
        : (prices.first == prices.last ? ' · ${prices.first}만원' : ' · ${prices.first}~${prices.last}만원');
    return '후보 ${list.length}곳$range';
  }
}

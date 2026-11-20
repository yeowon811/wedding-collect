import 'dart:math';

import '../../../core/utils/region.dart';
import '../../../data/models/venue.dart';

/// 범위 넓히기 (R9): 내가 고른 구 → 맞닿은 구 → 시 전체 → 가까운 시도.
/// 행정구역 경계 데이터가 없어 예식장 좌표의 평균(구·시도 중심)끼리 거리로 '가까운 곳'을 정한다.
class VenueScope {
  /// 두 좌표의 거리 (km, 하버사인)
  static double km(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(min(1.0, sqrt(a)));
  }

  static bool _valid(Venue v) => v.lat != 0 && v.lng != 0;

  /// 데이터의 '광주·전남'(2026 통합) 예식장을 시·군·구로 광주/전남에 나눠 센다
  static String sidoOf(Venue v) =>
      v.sido == '광주·전남' ? ((kSigunguBySido['광주'] ?? const []).contains(v.sigungu) ? '광주' : '전남') : v.sido;

  /// (시도, 구) → 예식장 좌표 평균
  static Map<(String, String), (double, double)> townCenters(List<Venue> all) {
    final sum = <(String, String), (double, double, int)>{};
    for (final v in all.where(_valid)) {
      final k = (v.sido, v.sigungu);
      final s = sum[k] ?? (0.0, 0.0, 0);
      sum[k] = (s.$1 + v.lat, s.$2 + v.lng, s.$3 + 1);
    }
    return {for (final e in sum.entries) e.key: (e.value.$1 / e.value.$3, e.value.$2 / e.value.$3)};
  }

  static Map<String, (double, double)> sidoCenters(List<Venue> all) {
    final sum = <String, (double, double, int)>{};
    for (final v in all.where(_valid)) {
      final s = sum[sidoOf(v)] ?? (0.0, 0.0, 0);
      sum[sidoOf(v)] = (s.$1 + v.lat, s.$2 + v.lng, s.$3 + 1);
    }
    return {for (final e in sum.entries) e.key: (e.value.$1 / e.value.$3, e.value.$2 / e.value.$3)};
  }

  /// [towns]와 가장 가까운(예식장이 있는) 같은 시도의 다른 구 [n]개.
  /// 구 중심끼리가 아니라 '내 구 예식장 ↔ 그 구 예식장' 중 가장 가까운 거리로 본다 (예식장이 한쪽 끝에 몰린 구도 맞게)
  static List<String> adjacentTowns(List<Venue> all, String sido, List<String> towns, {int n = 2}) {
    if (sido == '서울' && towns.every(_seoul.containsKey)) {
      // 서울은 구청 기준 중심 좌표로 (한강 건너 예식장이 더 가까워 보이는 문제를 피함)
      final have = {for (final v in all) if (v.sido == '서울') v.sigungu};
      final cands = [
        for (final e in _seoul.entries)
          if (!towns.contains(e.key) && have.contains(e.key))
            (e.key, towns.map((t) => km(_seoul[t]!.$1, _seoul[t]!.$2, e.value.$1, e.value.$2)).reduce(min)),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      return [for (final c in cands.take(n)) c.$1];
    }
    final mine = [for (final v in all) if (sidoMatches(v.sido, sido) && towns.contains(v.sigungu) && _valid(v)) v];
    if (mine.isEmpty) return const [];
    final best = <String, double>{};
    for (final o in all) {
      if (!sidoMatches(o.sido, sido) || towns.contains(o.sigungu) || o.sigungu.isEmpty || !_valid(o)) continue;
      for (final v in mine) {
        final d = km(v.lat, v.lng, o.lat, o.lng);
        if (d < (best[o.sigungu] ?? double.infinity)) best[o.sigungu] = d;
      }
    }
    final cands = best.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return [for (final c in cands.take(n)) c.key];
  }

  /// [sido]와 가까운(예식장이 있는) 시도 [n]개와 각 예식장 수. [sido]에 예식장이 없으면 행정구역 대표 좌표로 본다
  static List<(String, int)> nearbySidos(List<Venue> all, String sido, {int n = 3}) {
    final centers = sidoCenters(all);
    final me = centers[sido] ?? _sidoFallback[sido];
    if (me == null) return const [];
    final counts = <String, int>{};
    for (final v in all) {
      counts[sidoOf(v)] = (counts[sidoOf(v)] ?? 0) + 1;
    }
    final cands = [
      for (final e in centers.entries)
        if (e.key != sido) (e.key, km(me.$1, me.$2, e.value.$1, e.value.$2)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final c in cands.take(n)) (c.$1, counts[c.$1] ?? 0)];
  }

  /// 서울 25개 구 중심(대략, 구청 근처) 좌표
  static const _seoul = {
    '강남구': (37.4959, 127.0664), '강동구': (37.5492, 127.1464), '강북구': (37.6469, 127.0147), '강서구': (37.5612, 126.8228),
    '관악구': (37.4654, 126.9438), '광진구': (37.5481, 127.0857), '구로구': (37.4954, 126.8581), '금천구': (37.4600, 126.9001),
    '노원구': (37.6552, 127.0771), '도봉구': (37.6658, 127.0317), '동대문구': (37.5838, 127.0507), '동작구': (37.4965, 126.9443),
    '마포구': (37.5622, 126.9087), '서대문구': (37.5820, 126.9356), '서초구': (37.4769, 127.0378), '성동구': (37.5506, 127.0409),
    '성북구': (37.6057, 127.0176), '송파구': (37.5048, 127.1144), '양천구': (37.5270, 126.8561), '영등포구': (37.5206, 126.9139),
    '용산구': (37.5311, 126.9810), '은평구': (37.6176, 126.9227), '종로구': (37.5990, 126.9861), '중구': (37.5579, 126.9941),
    '중랑구': (37.5953, 127.0939),
  };

  /// 공공예식장이 없는 시도의 대표 좌표 (시청·도청 근처)
  static const _sidoFallback = {
    '대전': (36.3504, 127.3845),
    '제주': (33.4996, 126.5312),
  };

  /// 구 이름을 칩용으로 짧게 ("송파구" → "송파", "수원시 장안구" → "장안")
  static String shortTown(String t) {
    final last = t.split(' ').last;
    return last.length > 2 ? last.replaceAll(RegExp(r'(구|시|군)$'), '') : last;
  }
}

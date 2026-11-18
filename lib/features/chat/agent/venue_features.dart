import '../../../data/models/venue.dart';

/// 예식장 원문(주차·피로연·실내외) → 상담에서 거를 수 있는 값. 원문 문구가 짧고 종류가 적어
/// 규칙으로 정리하고(검수 표: tools/venue_features_report.py), 판단할 수 없으면 unknown으로 둔다.
enum Avail { yes, no, unknown }

class Parking {
  const Parking(this.ok, {this.spaces, this.paid = false, this.text});
  final Avail ok;
  final int? spaces; // 원문에 적힌 대수 (가장 큰 수)
  final bool paid;
  final String? text;

  String get label => switch (ok) {
        Avail.yes => '주차 가능${spaces != null ? ' $spaces대' : ''}${paid ? '(유료)' : ''}',
        Avail.no => '주차 불가',
        Avail.unknown => text == null ? '주차 정보 없음' : '주차: $text',
      };
}

class Reception {
  const Reception(this.ok, {this.kinds = const [], this.text});
  final Avail ok;
  final List<String> kinds; // 케이터링·도시락·뷔페·인근 식당
  final String? text;

  String get label => switch (ok) {
        Avail.yes => '피로연 ${kinds.join('·')}',
        Avail.no => '피로연 불가${kinds.isEmpty ? '' : '(${kinds.join('·')})'}',
        Avail.unknown => '피로연 정보 없음',
      };
}

class VenueFeatures {
  static Parking parking(Venue v) {
    final t = v.parking?.trim();
    if (t == null || t.isEmpty) return const Parking(Avail.unknown);
    final nums = [
      for (final m in RegExp(r'(\d+)\s*(?:대|면)').allMatches(t)) int.parse(m[1]!),
    ];
    final spaces = nums.isEmpty ? null : nums.reduce((a, b) => a > b ? a : b);
    final paid = t.contains('유료');
    if (RegExp(r'불가|없음|X').hasMatch(t) && spaces == null) return Parking(Avail.no, text: t);
    if (spaces != null || t.contains('가능') || t.contains('주차장')) {
      return Parking(Avail.yes, spaces: spaces, paid: paid, text: t);
    }
    return Parking(Avail.unknown, text: t);
  }

  static Reception reception(Venue v) {
    final t = v.reception?.trim();
    if (t == null || t.isEmpty) return const Reception(Avail.unknown);
    final kinds = [
      if (t.contains('케이터링')) '케이터링',
      if (t.contains('도시락')) '도시락',
      if (t.contains('뷔페') && !t.contains('케이터링')) '뷔페',
      if (t.contains('식당')) '인근 식당',
    ];
    final onSite = kinds.where((k) => k != '인근 식당').toList();
    if (onSite.isEmpty && RegExp(r'불가|^X|제한').hasMatch(t)) return Reception(Avail.no, kinds: kinds, text: t);
    if (onSite.isNotEmpty) return Reception(Avail.yes, kinds: onSite, text: t);
    return Reception(Avail.unknown, text: t);
  }

  static const _outdoorWords = ['잔디', '공원', '광장', '마당', '정원', '야외', '숲', '루프탑', '가든', '무대', '쉼터'];

  /// 야외 예식 가능 여부. 실내외 칸이 비어 있으면 이름으로 추정(guessed=true)
  static ({Avail ok, bool guessed}) outdoor(Venue v) {
    final io = v.indoorOutdoor;
    if (io != null && io.contains('실외')) return (ok: Avail.yes, guessed: false);
    if (io != null && io.contains('실내')) return (ok: Avail.no, guessed: false);
    if (_outdoorWords.any(v.name.contains)) return (ok: Avail.yes, guessed: true);
    return (ok: Avail.unknown, guessed: true);
  }
}

/// 이름 비교용: 공백·기호를 뺀다
String normName(String s) => s.replaceAll(RegExp(r'[\s()\[\]·,.\-_/舊前]'), '').toLowerCase();

/// 여러 곳 이름에 흔히 들어가는 말: 이것만 맞으면 특정 예식장으로 보지 않는다
const _generic = [
  '공공예식장', '예식장', '웨딩홀', '웨딩가든', '대강당', '강당', '잔디마당', '야외마당', '앞마당', '다목적홀', '국제회의장',
  '컨벤션홀', '공연장', '대회의실', '회의실', '체육관', '전통마당', '공원', '광장', '정원', '그랜드홀',
];

/// 질문(또는 Gemini가 뽑은 이름)에 나온 예식장 찾기. 이름의 괄호 앞/안 부분도 본다(4글자 이상).
List<Venue> findVenuesByName(List<Venue> all, String text, {List<String> names = const []}) {
  final q = normName(text);
  final asked = [for (final n in names) normName(n)].where((n) => n.length >= 3).toList();
  final hits = <Venue>[];
  for (final v in all) {
    final full = normName(v.name);
    final parts = {
      full,
      normName(v.name.split('(').first),
      if (v.name.contains('(')) normName(v.name.split('(')[1].split(')').first),
    }.where((p) => p.length >= 4 && !_generic.any((g) => p == g || (p.length <= g.length + 2 && p.contains(g))));
    final byText = parts.any(q.contains);
    final byName = asked.any((n) => full.contains(n) || (n.length >= 6 && n.contains(normName(v.name.split('(').first))));
    if (byText || byName) hits.add(v);
  }
  // 질문에 나온 순서대로
  int pos(Venue v) {
    final i = q.indexOf(normName(v.name.split('(').first));
    return i < 0 ? 999 : i;
  }

  return hits..sort((a, b) => pos(a).compareTo(pos(b)));
}

/// 예식장의 날짜별 예약 현황 (수집 시점 스냅샷, tools/collect_booking_status.py)
///
/// - 공유누리: 예약 달력의 가능/불가. 불가는 '이미 예약됨·휴관·접수 기간 아님'을 사이트가 구분하지 않는다
/// - 서울마이웨딩: 공석 표시(오전·오후) = 가능, '예약확정'·'예약불가' = 예약됨, 빈칸 = 그날 예식 접수 없음(정보 없음)
/// - 수집 범위(from~to) 밖이거나 기록이 없는 날은 [DayBooking.unknown]
enum DayBooking {
  open('예약 가능'),
  closed('예약 불가'),
  unknown('정보 없음');

  const DayBooking(this.label);
  final String label;
}

class BookingStatus {
  BookingStatus({
    required this.venueId,
    required this.source,
    required this.sourceUrl,
    required this.checkedAt,
    required this.from,
    required this.to,
    required this.open,
    required this.closed,
    required this.slots,
    required this.closedMeaning,
  });

  final String venueId;
  final String source; // 공유누리 / 서울마이웨딩
  final String sourceUrl;
  final DateTime checkedAt; // 수집한 날
  final DateTime from;
  final DateTime to;
  final Set<String> open; // yyyy-MM-dd
  final Set<String> closed;
  final Map<String, List<String>> slots; // 서울마이웨딩: 날짜별 공석 (예: 오전)
  final String closedMeaning;

  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DayBooking on(DateTime d) {
    final k = key(d);
    if (open.contains(k)) return DayBooking.open;
    if (closed.contains(k)) return DayBooking.closed;
    return DayBooking.unknown;
  }

  /// 그날 공석 이름 (서울마이웨딩만, 없으면 빈 목록)
  List<String> slotsOn(DateTime d) => slots[key(d)] ?? const [];

  bool covers(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(from) && !day.isAfter(to);
  }

  /// 해당 기간(포함)의 예약 가능한 날
  List<DateTime> openBetween(DateTime start, DateTime end) {
    final out = <DateTime>[];
    for (final k in open) {
      final d = DateTime.parse(k);
      if (!d.isBefore(start) && !d.isAfter(end)) out.add(d);
    }
    out.sort();
    return out;
  }

  /// '11/19 확인 · 공유누리'
  String get checkedLabel => '${checkedAt.month}/${checkedAt.day} 확인 · $source';

  /// 날짜 글자 → 공석 이름 (서울마이웨딩). Y는 가능하지만 이름 없음
  static const _slotCode = {'Y': <String>[], 'A': ['오전'], 'P': ['오후'], 'B': ['오전', '오후']};

  /// 저장 형식: months = {"2026-11": "NNNY…"} — 그 달 1일부터 하루 한 글자
  /// (Y 가능 / A 오전 공석 / P 오후 공석 / B 오전·오후 공석 / N 불가 / . 정보 없음)
  factory BookingStatus.fromJson(String id, Map<String, dynamic> j) {
    final months = (j['months'] as Map<String, dynamic>).cast<String, String>();
    final keys = months.keys.toList()..sort();
    final open = <String>{}, closed = <String>{};
    final slots = <String, List<String>>{};
    for (final m in keys) {
      final s = months[m]!;
      for (var i = 0; i < s.length; i++) {
        final k = '$m-${(i + 1).toString().padLeft(2, '0')}';
        final named = _slotCode[s[i]];
        if (named != null) {
          open.add(k);
          if (named.isNotEmpty) slots[k] = named;
        } else if (s[i] == 'N') {
          closed.add(k);
        }
      }
    }
    return BookingStatus(
      venueId: id,
      source: j['source'] as String,
      sourceUrl: j['sourceUrl'] as String,
      checkedAt: DateTime.parse(j['checkedAt'] as String),
      from: DateTime.parse('${keys.first}-01'),
      to: DateTime.parse('${keys.last}-${months[keys.last]!.length.toString().padLeft(2, '0')}'),
      open: open,
      closed: closed,
      slots: slots,
      closedMeaning: (j['closedMeaning'] as String?) ?? '예약 불가',
    );
  }
}

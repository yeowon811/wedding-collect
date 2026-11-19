import '../../../data/models/booking_status.dart';
import '../../../data/models/venue.dart';

/// 예식장 날짜 판단 결과
enum DateFit { possible, impossible, unknown }

class DateJudgement {
  const DateJudgement(this.fit, this.reason);

  final DateFit fit;
  final String reason; // 원문 근거 (짧게)
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
String weekdayOf(DateTime d) => _weekdays[d.weekday - 1];
String dateLabel(DateTime d) => '${d.month}월 ${d.day}일(${weekdayOf(d)})';

/// 질문 속 날짜: "12/20", "12월 20일", "2027년 3월 7일". 연도가 없으면 오늘 이후 가장 가까운 날.
DateTime? parseAskDate(String text, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final t0 = DateTime(today.year, today.month, today.day);
  DateTime? make(int? y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    var date = DateTime(y ?? t0.year, m, d);
    if (date.month != m) return null; // 2/30 같은 날
    if (y == null && date.isBefore(t0)) date = DateTime(t0.year + 1, m, d);
    return date;
  }

  final full = RegExp(r'(20\d\d)\s*[년.\-/]\s*(\d{1,2})\s*[월.\-/]\s*(\d{1,2})').firstMatch(text);
  if (full != null) return make(int.parse(full[1]!), int.parse(full[2]!), int.parse(full[3]!));
  final kor = RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일').firstMatch(text);
  if (kor != null) return make(null, int.parse(kor[1]!), int.parse(kor[2]!));
  final slash = RegExp(r'(?<![\d/])(\d{1,2})\s*/\s*(\d{1,2})(?![\d/])').firstMatch(text);
  if (slash != null) return make(null, int.parse(slash[1]!), int.parse(slash[2]!));
  return null;
}

/// 이 예식장의 날짜 관련 원문 (해당 연도의 예식 가능일·불가일, 이용 기간·시간). 없으면 null
String? dateTextOf(Venue v, DateTime date) {
  final parts = [
    if (date.year == 2026 && v.availableDates2026 != null) '예식 가능일: ${v.availableDates2026}',
    if (date.year == 2027 && v.availableDates2027 != null) '예식 가능일: ${v.availableDates2027}',
    if (date.year == 2026 && v.unavailableDates2026 != null) '예식 불가일: ${v.unavailableDates2026}',
    if (v.operatingPeriod != null) '이용 기간: ${v.operatingPeriod}',
    if (v.hoursText != null) '이용 시간: ${v.hoursText}',
    if (date.weekday == DateTime.saturday && v.hoursSaturday != null) '토요일: ${v.hoursSaturday}',
    if (date.weekday == DateTime.sunday && v.hoursHoliday != null) '일요일·공휴일: ${v.hoursHoliday}',
  ];
  return parts.isEmpty ? null : parts.join(' / ');
}

/// 수집한 예약 현황(공유누리·서울마이웨딩 달력)으로 그날을 판단. 현황이 없거나 수집 범위 밖이면 null → 원문 판단으로
/// - 가능: 수집 시점에 그 날짜가 비어 있었음 (서울마이웨딩은 공석 이름 함께)
/// - 불가: 이미 예약됨(공유누리는 휴관·접수 기간 아님 포함)
/// - 서울마이웨딩 달력에서 빈칸인 날: 그날 예식 접수 없음 → 불가
DateJudgement? bookingJudge(BookingStatus? b, DateTime date) {
  if (b == null || !b.covers(date)) return null;
  final when = '${b.checkedAt.month}/${b.checkedAt.day} ${b.source} 달력';
  switch (b.on(date)) {
    case DayBooking.open:
      final slots = b.slotsOn(date);
      return DateJudgement(DateFit.possible, '$when: 비어 있음${slots.isEmpty ? '' : ' (${slots.join('·')})'}');
    case DayBooking.closed:
      return DateJudgement(DateFit.impossible, '$when: 예약 불가');
    case DayBooking.unknown:
      return b.source == '서울마이웨딩' ? DateJudgement(DateFit.impossible, '$when: 그날 예식 접수 없음') : null;
  }
}

/// Gemini가 없을 때의 단순 규칙 판단 (예식 가능일 원문의 월 범위·요일·불가 날짜만 본다)
DateJudgement ruleJudgeDate(Venue v, DateTime date) {
  final avail = date.year == 2026 ? v.availableDates2026 : (date.year == 2027 ? v.availableDates2027 : null);
  final unavail = date.year == 2026 ? v.unavailableDates2026 : null;
  if (avail == null && unavail == null) {
    return const DateJudgement(DateFit.unknown, '예식 가능일 정보 없음');
  }
  final m = date.month, d = date.day;
  // 불가일: "9월26일~27일", "10월 3일", "4월4일~5월15일"
  if (unavail != null) {
    for (final r in RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일?(?:\s*~\s*(?:(\d{1,2})\s*월\s*)?(\d{1,2})\s*일?)?')
        .allMatches(unavail)) {
      final m1 = int.parse(r[1]!), d1 = int.parse(r[2]!);
      final m2 = r[4] == null ? m1 : int.parse(r[3] ?? r[1]!), d2 = r[4] == null ? d1 : int.parse(r[4]!);
      final key = m * 100 + d;
      if (key >= m1 * 100 + d1 && key <= m2 * 100 + d2) {
        return DateJudgement(DateFit.impossible, '불가일: ${r[0]!.trim()}');
      }
    }
  }
  if (avail == null) return const DateJudgement(DateFit.unknown, '예식 가능일 정보 없음');
  // 월 범위 "3월~12월"
  final range = RegExp(r'(\d{1,2})\s*월\s*~\s*(\d{1,2})\s*월').firstMatch(avail);
  if (range != null) {
    final a = int.parse(range[1]!), b = int.parse(range[2]!);
    if (m < a || m > b) return DateJudgement(DateFit.impossible, '$a월~$b월에만 예식');
  }
  // 요일 "토(1식) 일(1식)", "매주 토", "토․일"
  final noMonths = avail.replaceAll(RegExp(r'\d+\s*월'), '').replaceAll(RegExp(r'\d+\s*일'), '');
  final days = {
    for (final x in RegExp(r'([월화수목금토일])(?=\s*(?:\(|·|․|,|요일|$|\s))').allMatches(noMonths)) x[1]!,
  };
  if (days.isNotEmpty && !days.contains(weekdayOf(date))) {
    return DateJudgement(DateFit.impossible, '${days.join('·')}요일에만 예식');
  }
  if (avail.contains('지정일') || avail.contains('별도')) {
    return const DateJudgement(DateFit.unknown, '지정일만 예식 (기관 확인)');
  }
  return DateJudgement(DateFit.possible, '예식 가능일 조건에 맞음 (${avail.length > 24 ? '${avail.substring(0, 24)}…' : avail})');
}

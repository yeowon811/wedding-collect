import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/models/booking_status.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/date_check.dart';

/// 예약 현황(달력 스냅샷): 압축 형식 읽기, 날짜 판단, 수집 범위 밖은 모름
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2026-12: 1일 Y(서울은 A = 오전 공석), 2일 N, 3일 ., 나머지 N / 2027-01: 전부 Y (31일)
  BookingStatus make(String source, {String first = 'Y'}) => BookingStatus.fromJson('X', {
        'source': source,
        'sourceUrl': 'https://example.org',
        'checkedAt': '2026-11-19',
        'closedMeaning': '예약됨',
        'months': {'2026-12': '${first}N.${'N' * 28}', '2027-01': 'Y' * 31},
      });

  test('압축 형식(달마다 한 글자)을 날짜별 상태로 읽는다', () {
    final b = make('공유누리');
    expect(b.on(DateTime(2026, 12, 1)), DayBooking.open);
    expect(b.on(DateTime(2026, 12, 2)), DayBooking.closed);
    expect(b.on(DateTime(2026, 12, 3)), DayBooking.unknown);
    expect(b.from, DateTime(2026, 12, 1));
    expect(b.to, DateTime(2027, 1, 31));
    expect(b.covers(DateTime(2027, 2, 1)), isFalse);
    expect(b.openBetween(DateTime(2026, 12, 1), DateTime(2027, 1, 3)).length, 4);
  });

  test('예약 현황 판단: 가능·불가는 확정, 범위 밖이나 공유누리 빈칸은 원문 판단으로 넘긴다', () {
    final e = make('공유누리');
    expect(bookingJudge(e, DateTime(2026, 12, 1))!.fit, DateFit.possible);
    expect(bookingJudge(e, DateTime(2026, 12, 1))!.reason, contains('11/19 공유누리 달력'));
    expect(bookingJudge(e, DateTime(2026, 12, 2))!.fit, DateFit.impossible);
    expect(bookingJudge(e, DateTime(2026, 12, 3)), isNull);
    expect(bookingJudge(e, DateTime(2027, 3, 1)), isNull);
    expect(bookingJudge(null, DateTime(2026, 12, 1)), isNull);
  });

  test('서울마이웨딩: 공석 이름을 붙이고, 빈칸은 그날 예식 접수 없음', () {
    final s = make('서울마이웨딩', first: 'B');
    expect(s.slotsOn(DateTime(2026, 12, 1)), ['오전', '오후']);
    expect(bookingJudge(s, DateTime(2026, 12, 1))!.fit, DateFit.possible);
    expect(bookingJudge(s, DateTime(2026, 12, 1))!.reason, contains('오전·오후'));
    final blank = bookingJudge(s, DateTime(2026, 12, 3))!;
    expect(blank.fit, DateFit.impossible);
    expect(blank.reason, contains('접수 없음'));
  });

  test('앱에 넣은 예약 현황 파일을 읽을 수 있다', () async {
    final all = await Repos.booking.loadAll();
    expect(all, isNotEmpty);
    expect(all.values.every((b) => !b.to.isBefore(b.from)), isTrue);
  });
}

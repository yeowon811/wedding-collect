import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';

/// 탐색 질문(test/eval/probe_cases.dart, 2026-11-19)에서 틀렸던 답을 고친 것 (Gemini 없이 규칙 경로)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('기간 질문 읽기', () {
    final now = DateTime(2026, 11, 19);
    test('"내년 3월"은 3월 1일 하루가 아니라 3월 주말 전체', () {
      final p = ConsultAgent.periodDates('원덕읍복지회관 웨딩홀 내년 3월에 자리 있어?', now: now)!;
      expect(p.label, '2027년 3월 주말');
      expect(p.dates.length, 8); // 2027년 3월 토·일
      expect(p.dates.every((d) => d.month == 3 && d.weekday >= 6), isTrue);
    });
    test('"다음 달"·"4월 토요일"·"예약 현황"', () {
      expect(ConsultAgent.periodDates('다음 달에 결혼하는데 예약 되는 곳', now: now)!.label, '2026년 12월 주말');
      final apr = ConsultAgent.periodDates('그중에 내년 4월 토요일 비어 있는 곳', now: now)!;
      expect(apr.label, '2027년 4월 토요일');
      expect(apr.dates.every((d) => d.weekday == DateTime.saturday), isTrue);
      expect(ConsultAgent.periodDates('세종 공공예식장 예약 현황 알려줘', now: now)!.label, '앞으로 3개월 주말');
    });
    test('날짜까지 있거나 "몇 개월"은 기간 질문이 아니다', () {
      expect(ConsultAgent.periodDates('12월 20일 예약 가능한 곳', now: now), isNull);
      expect(ConsultAgent.periodDates('결혼식까지 6개월 남았는데 뭐부터 해?', now: now), isNull);
      expect(ConsultAgent.periodDates('12월 둘째주 토요일 비어있는 곳', now: now), isNull);
    });
  });

  group('대화 (서울·만 29세·예비부부·하객 150명)', () {
    setUpAll(() async {
      await Repos.venue.loadAll();
      await Repos.policy.loadAll();
      await Repos.booking.loadAll();
    });
    setUp(() => AppState.instance.saveProfile(const UserProfile(
        sido: '서울', age: 29, stage: MarriageStage.engaged, guests: 150, budget: 3000)));
    tearDown(() => AppState.instance.resetProfile());

    test('P09 예식장 이름 + 달: 그 달 주말의 빈 날을 알려 준다', () async {
      final m = await ConsultAgent().reply('원덕읍복지회관 웨딩홀 내년 3월에 자리 있어?');
      expect(m.text, contains('2027년 3월 주말'));
      expect(m.text, isNot(contains('3월 1일')));
    });

    test('P12 다른 시도 지원: 사는 곳이 아니라 물은 시도의 거주 조건', () async {
      final m = await ConsultAgent().reply('경기도 사는데 서울시 결혼 지원 받을 수 있어?');
      expect(m.text, contains('서울에 살지 않아도'));
    });

    test('P15 장려금 많은 지역: 대출은 빼고 현금 지원을 금액 순으로', () async {
      final m = await ConsultAgent().reply('결혼 장려금 제일 많이 주는 지역은 어디야?');
      expect(m.text, contains('대출·이자 지원은 빌리는 한도라 뺐어요'));
      expect(m.text, isNot(contains('디딤돌')));
    });

    test('P25 그중에 제일 큰 곳: 정원 큰 순', () async {
      final agent = ConsultAgent();
      await agent.reply('인천 공공예식장 알려줘');
      final m = await agent.reply('그중에 제일 큰 곳은?');
      expect(m.trace.join(' '), contains('정원 큰 순'));
      expect(m.text, isNot(contains('반영하지 못했어요')));
    });

    test('P28 날짜까지 며칠: 질문 속 날짜로 센다 (계산식·저장된 예식일 아님)', () async {
      final now = DateTime.now();
      final target = DateTime(now.year + 1, 4, 10);
      final days = target.difference(DateTime(now.year, now.month, now.day)).inDays;
      final m = await ConsultAgent().reply('${target.year}년 4월 10일 결혼이면 며칠 남았어?');
      expect(m.text, contains('$days일 남았어요'));
      expect(m.text, contains('${target.year}.04.10'));
      expect(m.text, isNot(contains('−'))); // 날짜 숫자로 만든 빼기 식이 아님
    });

    test('D04 "내년"만 있어도 내년 주말의 빈 날을 본다', () async {
      final m = await ConsultAgent().reply('북서울꿈의숲 내년 예약 아직 남아 있어?');
      expect(m.text, contains('${DateTime.now().year + 1}년 주말'));
    });

    test('I03 예약을 묻지 않은 후속 질문(주차)에는 예약 현황 안내를 붙이지 않는다', () async {
      final agent = ConsultAgent();
      await agent.reply('예식장 추천해줘');
      final m = await agent.reply('두 번째 거 주차 돼?');
      expect(m.text, isNot(contains('예약 현황')));
    });

    test('I04 돈 제일 많이 주는 거: 대출보다 받는 돈(현금 지원)을 먼저', () async {
      final agent = ConsultAgent();
      await agent.reply('받을 수 있는 정책 알려줘');
      final m = await agent.reply('그중에 돈 제일 많이 주는 거');
      final firstLoan = m.cards.indexWhere((c) => RegExp(r'대출|이자').hasMatch(c.title));
      final firstCash = m.cards.indexWhere((c) => !RegExp(r'대출|이자|융자|보증').hasMatch(c.title));
      if (firstLoan >= 0 && firstCash >= 0) expect(firstCash, lessThan(firstLoan));
    });

    test('P29 국립공원: 앱의 국립공원 예식장 데이터로 답한다', () async {
      final m = await ConsultAgent().reply('국립공원 숲 결혼식 신청 방법 알려줘');
      expect(m.text, contains('국립공원 예식장은'));
      expect(m.cards, isNotEmpty);
    });
  });
}

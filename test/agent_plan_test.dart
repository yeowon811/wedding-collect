import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/calc.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/policy_text.dart';

/// 예상 질문 평가(docs/ai-eval/predicted_report.md)에서 틀렸던 질문: 계획(질문 종류·조건)대로 도구를 쓰는지
/// Gemini 없이 규칙만으로도 되는 부분을 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppState.instance.saveProfile(const UserProfile(
      sido: '서울', age: 29, stage: MarriageStage.engaged, guests: 150, budget: 3000)));
  tearDown(() => AppState.instance.resetProfile());

  test('계산 도구', () {
    expect(evalExpr('65000*150'), 9750000);
    expect(evalExpr('(100+50)*2'), 300);
    expect(evalExpr('1/0'), isNull);
    expect(evalExpr('alert(1)'), isNull);
    expect(parseWon('6만5천원'), 65000);
    expect(parseWon('200만원'), 2000000);
    expect(ruleCalc('식대 1인 6만5천원에 하객 150명이면 얼마야?'), '65000*150');
    expect(wonLabel(9750000), '9,750,000원 (약 975만원)');
  });

  test('H02 계산: 목록이 아니라 계산한 값', () async {
    final m = await ConsultAgent().reply('식대 1인 6만5천원에 하객 150명이면 얼마야?');
    expect(m.text, contains('9,750,000원'));
    expect(m.cards, isEmpty);
  });

  test('H01 비교: 이름이 나온 두 곳을 나란히', () async {
    final m = await ConsultAgent().reply('SETEC 컨벤션홀이랑 한강공원 광나루 장미원 중에 어디가 나아?');
    expect(m.cards.map((c) => c.title), ['SETEC 컨벤션홀', '한강공원 광나루 장미원']);
    expect(m.text, contains('주차'));
  });

  test('D04 특정 예식장: 그곳 정보 + 예약 현황(있으면 수집 날짜와 함께, 없으면 모른다고)', () async {
    final m = await ConsultAgent().reply('북서울꿈의숲 내년 예약 아직 남아 있어?');
    expect(m.cards.single.title, startsWith('북서울 꿈의숲'));
    expect(m.text, anyOf(contains('예약 현황('), contains('예약 현황이 공개되지 않아')));
    expect(m.text, contains('확인해 주세요'));
  });

  test('C01 총비용: 업체_요소 단가로 공공·일반 비교', () async {
    final m = await ConsultAgent().reply('공공예식장 대관료 말고 실제로 총 얼마 들어?');
    expect(m.text, contains('공공예식장·실속으로 준비하면'));
    expect(m.text, contains('일반 웨딩홀'));
  });

  test('F01 드레스 추가금: 단가표의 추가금 내역', () async {
    final m = await ConsultAgent().reply('드레스 추가금은 보통 뭐가 붙어?');
    expect(m.text, contains('피팅비'));
  });

  test('F05 스드메 200만원: 세 항목 최저가 합계를 예산과 비교', () async {
    final m = await ConsultAgent().reply('200만원 안으로 스드메 할 수 있는 곳 있어?');
    expect(m.cards.length, 3);
    expect(m.text, contains('말씀하신 200만원'));
  });

  test('H03 제외: 강남구는 빼고, 내 시군구로 저장하지 않음', () async {
    final m = await ConsultAgent().reply('강남구 말고 다른 구 예식장 알려줘');
    expect(m.text, contains('강남구 제외'));
    expect(m.cards.every((c) => !c.subtitle.contains('강남구')), isTrue);
  });

  test('C04 주차: 원문으로 거르고 대수 많은 순', () async {
    final m = await ConsultAgent().reply('주차 넓은 서울 공공예식장 있어?');
    expect(m.text, contains('주차 가능(원문 기준)'));
    expect(m.cards.first.subtitle, contains('주차 가능'));
  });

  test('G01 6개월 남음: 예식일을 되묻지 않음', () async {
    final m = await ConsultAgent().reply('결혼식까지 6개월 남았는데 뭐부터 해야 돼?');
    expect(m.isQuestion, isFalse);
  });

  test('J03 가리킬 답이 없는 "거기 어때?"는 되묻기', () async {
    final m = await ConsultAgent().reply('거기 어때?');
    expect(m.text, contains('어느 곳을 말씀하시는'));
  });

  test('H05 예식장이랑 정책 같이: 두 답을 이어 붙임', () async {
    final m = await ConsultAgent().reply('부산 공공예식장이랑 부산 결혼 지원 정책 같이 알려줘');
    expect(m.text, anyOf(contains('[공공예식장]'), contains('[지원 정책]')));
  });

  test('정책 원문 숫자 읽기', () {
    expect(incomeCap('부부합산 연소득 7.5천만원 이하, 순자산 3.37억원 이하'), 7500);
    expect(incomeCap('부부합산 연소득 1.3억원 이하(맞벌이 2억원 이하)'), 13000);
    expect(maxAmount('(수도권 최대 3억원, 비수도권 2억원)'), 30000);
    expect(maxAmount('비품비 최대 100만 원 지원'), 100);
    expect(incomeFromQuestion('부부 합산 소득 7천만원이면'), 7000);
    expect(manwonLabel(13000), '1억 3,000만원');
  });

  test('E01 거주: 이용 대상 원문과 지원 정책 거주 조건', () async {
    final m = await ConsultAgent().reply('서울에 안 살아도 서울 공공예식장 쓸 수 있어?');
    expect(m.text, contains('이용 대상'));
    expect(m.text, contains('거주 조건'));
  });

  test('D02 내년 봄 토요일: 그 기간 토요일 전부 확인', () async {
    final m = await ConsultAgent().reply('내년 봄 토요일에 되는 예식장 있어?');
    expect(m.text, contains('봄(3~5월) 토요일'));
    // '10/10일 가능'은 10월 10일처럼 읽혀서 쓰지 않는다 → '13일 모두 가능' / '13일 중 9일 가능'
    expect(m.cards.first.badge, isNot(matches(RegExp(r'\d+/\d+'))));
    expect(m.cards.first.badge, matches(RegExp(r'^\d+일 (중 \d+일|모두) 가능$')));
  });

  test('E04 소득: 원문 소득 상한과 비교', () async {
    final m = await ConsultAgent().reply('부부 합산 소득 7천만원이면 받을 수 있는 정책 뭐 있어?');
    expect(m.text, contains('연소득 7,000만원 기준'));
  });

  test('I04 돈 많이 주는 순: 원문 최대 금액', () async {
    final m = await ConsultAgent().reply('받을 수 있는 정책 중에 돈 제일 많이 주는 거 알려줘');
    expect(m.text, contains('최대 금액'));
  });

  test('E02 비품비: 이름에 그 말이 있는 정책', () async {
    final m = await ConsultAgent().reply('공공예식장 비품비 지원 정책 알려줘');
    expect(m.cards.first.title, contains('더 아름다운 결혼식'));
  });
}

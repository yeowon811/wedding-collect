import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/models/policy.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';
import 'package:wedding_collect/features/chat/agent/understanding.dart';

/// Gemini 응답을 그대로 믿지 않도록 하는 안전장치 테스트 (네트워크 없이)
void main() {
  test('질문 이해 JSON을 검사해서 받아들인다', () {
    final r = GeminiClient.parseUnderstanding({
      'intent': 'policy',
      'topic': 'housing',
      'facts': {'age': 20, 'ageMax': 29, 'sido': '서울', 'stage': 'married', 'homeless': true},
    })!;
    expect(r.isAnswer, isFalse);
    expect(r.u.intent, ConsultIntent.policy);
    expect(r.u.topic, PolicyCategory.housing);
    expect(r.u.facts.sido, '서울');
    expect(r.u.facts.ageLabel, '만 20~29세');
    expect(r.u.facts.stage, MarriageStage.married);
    expect(r.u.facts.homeless, isTrue);
  });

  test('범위를 벗어나거나 모르는 값은 버린다', () {
    final r = GeminiClient.parseUnderstanding({
      'intent': 'vendor',
      'item': 'host', // 실제 업체 분류라 추천 항목이 아님
      'facts': {'sido': '서울특별시', 'age': 200, 'guests': 3, 'budget': 3000},
    })!;
    expect(r.u.item, isNull);
    expect(r.u.facts.sido, isNull);
    expect(r.u.facts.age, isNull);
    expect(r.u.facts.guests, isNull);
    expect(r.u.facts.budget, 3000);
    expect(GeminiClient.parseUnderstanding({'intent': 'hack'}), isNull);
  });

  test('되묻기 답변은 answer로 받는다', () {
    final r = GeminiClient.parseUnderstanding({'intent': 'answer', 'facts': {'sido': '부산'}})!;
    expect(r.isAnswer, isTrue);
    expect(r.u.facts.sido, '부산');
  });

  test('외부로 보내기 전에 개인정보 형태를 가린다', () {
    final masked = GeminiClient.maskPersonalInfo(
        '제 번호는 010-1234-5678, 메일은 a.b@test.com, 주민번호 900101-1234567이에요');
    expect(masked, isNot(contains('5678')));
    expect(masked, isNot(contains('test.com')));
    expect(masked, isNot(contains('1234567')));
    expect(masked, contains('[전화번호]'));
  });

  test('조회 결과에 없는 숫자가 있으면 AI 답변을 쓰지 않는다', () {
    const draft = '받을 수 있는 정책을 12건 찾았어요. 서울 · 만 20~29세. 임차보증금 이자 최대 4,500만원';
    expect(GeminiClient.numbersAreGrounded('정책 12건, 최대 4500만원이에요', draft), isTrue);
    expect(GeminiClient.numbersAreGrounded('정책 15건을 찾았어요', draft), isFalse);
  });

  test('조회 결과에 없는 표시어(시연용·예비부부 등)를 붙이면 AI 답변을 쓰지 않는다', () {
    const venue = '기준: 경기 · 하객 200명\n정원·요금을 모르는 곳은 기관에 확인이 필요해요.';
    expect(GeminiClient.termsAreGrounded('정원을 모르면 기관에 확인해 주세요', venue), isTrue);
    expect(GeminiClient.termsAreGrounded('시연용 가상 데이터이니 확인해 주세요', venue), isFalse);
    const married = '기준: 경기 · 만 33세 · 신혼부부(혼인 2년 이내)';
    expect(GeminiClient.termsAreGrounded('예비부부님, 정책을 찾았어요', married), isFalse);
    const vendor = '(가격·평점은 시연용 가상 데이터예요)';
    expect(GeminiClient.termsAreGrounded('가격은 시연용 가상 데이터예요', vendor), isTrue);
    expect(GeminiClient.termsAreGrounded('자세한 건 기관 확인 필요', vendor), isFalse);
  });
}

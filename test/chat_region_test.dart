import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/core/utils/region.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/understanding.dart';

/// AI 상담 되묻기: 시도 → 시·군·구, 글로 적은 시군구, 직접 입력 버튼
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppState.instance.resetProfile());

  test('문장에서 시군구 찾기: 하나로 정해질 때만', () {
    expect(findSigungu('강남구 살아요'), ('서울', '강남구'));
    expect(findSigungu('수원이에요'), ('경기', '수원시'));
    expect(findSigungu('중구에 살아요'), isNull); // 여러 시도에 있음
    expect(findSigungu('중구에 살아요', sido: '부산'), ('부산', '중구'));
    expect(findSigungu('동대문구', sido: '서울'), ('서울', '동대문구')); // 동구보다 긴 이름
    expect(findSigungu('그냥 알려줘'), isNull);
  });

  test('지역을 글로 답하면 시군구까지 읽고, 시군구 질문은 건너뛴다', () async {
    final agent = ConsultAgent();
    var m = await agent.reply('받을 수 있는 정책 알려줘');
    expect(agent.asking, Slot.sido);
    m = await agent.reply('서울 강남구 살아요');
    expect(agent.asking, isNot(Slot.sigungu)); // 이미 알았으니 다시 묻지 않음
    expect(m.basis, contains('서울 강남구'));
  });

  test('시군구를 알면 그 시군구 예식장을 먼저 추천한다', () async {
    final agent = ConsultAgent();
    final m = await agent.reply('서울 강남구 사는데 하객 150명 공공예식장 추천해줘');
    expect(m.isQuestion, isFalse);
    expect(m.cards.first.subtitle, startsWith('서울 강남구'));
  });

  test('시군구를 모르면 건너뛸 수 있고, 숫자 질문에는 직접 입력 버튼이 있다', () async {
    final agent = ConsultAgent();
    var m = await agent.reply('공공예식장 추천해줘');
    m = await agent.choose(m.quickReplies.firstWhere((r) => r.label == '부산'));
    expect(agent.asking, Slot.sigungu);
    m = await agent.reply('잘 모르겠어요');
    expect(agent.asking, Slot.guests);
    expect(m.quickReplies.any((r) => r.action == 'input' && r.label == '직접 입력'), isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/chat_agent.dart';

/// 대화 흐름: 이전 대화를 이어받는 질문을 (Gemini 없이 규칙만으로도) 제대로 처리하는지
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppState.instance.saveProfile(const UserProfile(
        sido: '서울',
        age: 29,
        stage: MarriageStage.engaged,
        guests: 150,
        budget: 3000,
      )));
  tearDown(() => AppState.instance.resetProfile());

  test('"두 번째 거", "그중에 무료만", "그럼 부산은?"을 이전 대화로 이해한다', () async {
    final agent = ConsultAgent();
    final list = await agent.reply('서울 공공예식장 추천해줘');
    expect(list.cards.length, 3);

    final second = await agent.reply('두 번째 거 자세히 알려줘');
    expect(second.text, contains(list.cards[1].title));
    expect(second.cards.single.ref, list.cards[1].ref);
    expect(second.trace.any((t) => t.startsWith('대화 흐름') && t.contains('2번째')), isTrue);

    // 상세 답변 뒤에도 "세 번째"는 같은 예식장 목록을 가리킨다
    final third = await agent.reply('세 번째 거는?');
    expect(third.text, contains(list.cards[2].title));

    final free = await agent.reply('그중에 무료인 곳만');
    expect(free.trace.any((t) => t.contains('대관료 무료인 곳')), isTrue);

    final busan = await agent.reply('그럼 부산은?');
    expect(busan.basis, contains('부산'));
    expect(busan.cards.first.ref, startsWith('venue:'));
  });

  test('업체 질문 뒤 "더 싼 데는 없어?"는 같은 항목을 싼 순으로 다시 고른다', () async {
    final agent = ConsultAgent();
    await agent.reply('드레스 추천해줘');
    final cheaper = await agent.reply('더 싼 데는 없어?');
    expect(cheaper.text, contains('가격이 낮은 순'));
    expect(cheaper.cards.first.ref, startsWith('vendor:'));
  });

  test('준비 항목에 금액을 정하면 그 예산 안의 업체를 먼저 추천한다', () async {
    final app = AppState.instance;
    final dress = app.itemFor(VendorCategory.dress)!;
    app.updateItem(dress, clearAmount: true);
    final none = await ConsultAgent().reply('드레스 추천해줘');
    expect(none.text, contains('드레스 금액을 정하면'));
    expect(none.text, isNot(contains('추천 예산')));
    expect(none.cards.every((c) => c.badge == null), isTrue);

    app.updateItem(dress, amount: 200);
    final set = await ConsultAgent().reply('드레스 추천해줘');
    expect(set.text, contains('예산 200만원 안의 업체'));
    expect(set.cards.first.badge, '예산 안');
    app.updateItem(dress, clearAmount: true);
  });

  test('예산 질문은 준비 항목에 정한 금액·합계·남은 예산을 보여준다', () async {
    final app = AppState.instance;
    final dress = app.itemFor(VendorCategory.dress)!;
    final food = app.itemFor(VendorCategory.meal)!;
    for (final i in app.items) {
      app.updateItem(i, clearAmount: true);
    }
    final empty = await ConsultAgent().reply('예산 어떻게 나누면 돼?');
    expect(empty.text, contains('아직 예산 관리 목록에 금액을 정하지 않았어요'));
    expect(empty.quickReplies.map((q) => q.action), contains('open_checklist'));

    app.updateItem(dress, amount: 200);
    app.updateItem(food, amount: 900);
    final m = await ConsultAgent().reply('예산 어떻게 나누면 돼?');
    expect(m.text, contains('드레스 200만원'));
    expect(m.text, contains('남은 예산 1,900만원'));
    expect(m.text, isNot(contains('%')));
    app.updateItem(dress, clearAmount: true);
    app.updateItem(food, clearAmount: true);
  });

  test('이어서 하기: 저장된 대화로 기억을 되살려 "첫 번째 거"를 찾는다', () async {
    final first = ConsultAgent();
    final user = const ChatMessage(fromUser: true, text: '서울 공공예식장 추천해줘');
    final answer = await first.reply(user.text);

    final resumed = ConsultAgent()..restore([user, answer]);
    final pick = await resumed.reply('첫 번째 거 자세히');
    expect(pick.text, contains(answer.cards.first.title));
  });
}

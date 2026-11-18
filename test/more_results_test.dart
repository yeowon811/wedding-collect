import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';

/// AI 상담 추천의 [더 보기]: 처음 3개 다음부터 3개씩
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

  test('예식장 추천 뒤 더 보기를 누르면 다음 3곳, 글로 "더 보여줘"도 된다', () async {
    final agent = ConsultAgent();
    final first = await agent.reply('서울 공공예식장 추천해줘');
    expect(first.cards.length, 3);
    final more = first.quickReplies.firstWhere((r) => r.action == 'more');
    expect(more.label, startsWith('더 보기 ('));

    final second = await agent.choose(more);
    expect(second.cards.length, 3);
    expect(second.text, contains('4~6번째'));
    final firstRefs = {for (final c in first.cards) c.ref};
    expect(second.cards.every((c) => !firstRefs.contains(c.ref)), isTrue);
    expect(second.quickReplies.any((r) => r.action == 'open_tab'), isTrue);

    final third = await agent.reply('더 보여줘');
    expect(third.text, contains('7~9번째'));
  });

  test('업체 추천의 더 보기는 실제 연계 업체로 이어진다', () async {
    final agent = ConsultAgent();
    final first = await agent.reply('드레스 추천해줘');
    final more = first.quickReplies.where((r) => r.action == 'more').firstOrNull;
    expect(more, isNotNull);
    final next = await agent.choose(more!);
    expect(next.cards.first.ref, startsWith('real:'));
  });

  test('남은 결과가 없으면 더 보기 대신 탭에서 전체 보기', () async {
    final agent = ConsultAgent();
    var m = await agent.reply('서울 공공예식장 추천해줘');
    while (m.quickReplies.any((r) => r.action == 'more')) {
      m = await agent.choose(m.quickReplies.firstWhere((r) => r.action == 'more'));
    }
    expect(m.text, contains('여기까지가 전부예요'));
    expect(m.quickReplies.single.action, 'open_tab');
  });
}

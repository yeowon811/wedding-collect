import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';

/// 그 분야 정책이 0건이면 전체 정책으로 조용히 바꾸지 않고 '없다'고 말한다 (2026-11-20, 인천 장려금 같은 답 반복)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;

  setUpAll(() async {
    await Repos.venue.loadAll();
    await Repos.policy.loadAll();
    await Repos.booking.loadAll();
  });
  setUp(() => app.saveProfile(
      UserProfile(sido: '인천', age: 29, weddingDate: DateTime(2025, 10, 1), guests: 150, homeless: true)));
  tearDown(() => app.resetProfile());

  test('인천 장려금: 0건이면 "없어요"라고 말하고 같은 정책 목록을 다시 보여 주지 않는다', () async {
    final agent = ConsultAgent();
    final first = await agent.reply('받을 수 있는 정책 알려줘');
    // 인천에는 장려금 정책이 없으므로 '장려금' 칩을 보여 주지 않는다
    expect(first.quickReplies.map((r) => r.label).any((l) => l.contains('장려금')), isFalse);

    final m = await agent.reply('결혼 장려금 정책 알려줘');
    expect(m.text, contains('인천에는 결혼 장려금 정책이 없어요'));
    expect(m.text, isNot(contains('조건을 바꿔도 앞과 같은 결과')));
    expect(m.cards, isEmpty);
    // 대신 갈 수 있는 길: 전체 정책 · 결과가 있는 다른 분야(건수 포함)
    final labels = m.quickReplies.map((r) => r.label).toList();
    expect(labels.any((l) => l.startsWith('전체 정책 ')), isTrue);
    expect(labels.any((l) => RegExp(r'^주거 지원 \d+건$').hasMatch(l)), isTrue);
  });

  test('결과가 있는 분야는 그대로 그 분야만 보여 준다', () async {
    final m = await ConsultAgent().reply('신혼집 주거 지원 정책 알려줘');
    expect(m.text, contains('주거·대출 정책을'));
    expect(m.cards, isNotEmpty);
  });
}

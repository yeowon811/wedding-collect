import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';

/// AI 상담에서 말한 내 이야기(사는 곳·하객 수 등)는 내 정보·체크리스트에 자동 반영 (2026-11-19 피드백)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;

  setUpAll(() async {
    await Repos.venue.loadAll();
    await Repos.policy.loadAll();
    await Repos.booking.loadAll();
  });
  setUp(() => app.saveProfile(const UserProfile(sido: '서울', age: 29, guests: 150, budget: 3000)));
  tearDown(() => app.resetProfile());

  test('"강남구 살아요" → 사는 곳으로 저장하고 무엇을 바꿨는지 알린다', () async {
    final m = await ConsultAgent().reply('강남구 살아요. 하객 200명 정도 예식장 추천해줘');
    expect(app.profile.sigungu, '강남구');
    expect(app.profile.guests, 200);
    expect(app.plan.guests, 200); // 체크리스트 결혼 정보도 같은 값
    expect(m.text, contains('내 정보에 반영했어요'));
    expect(m.quickReplies.any((r) => r.action == 'undo_profile'), isTrue);
  });

  test('찾는 지역("부산 예식장")은 사는 곳으로 저장하지 않는다', () async {
    await ConsultAgent().reply('부산 공공예식장 알려줘');
    expect(app.profile.sido, '서울');
  });

  test('"경기도 사는데 서울시 지원…"은 사는 곳(경기)만 저장', () async {
    await ConsultAgent().reply('경기도 사는데 서울시 결혼 지원 받을 수 있어?');
    expect(app.profile.sido, '경기');
  });

  test('[되돌리기]로 반영 전 값으로 돌아간다', () async {
    final agent = ConsultAgent();
    final m = await agent.reply('하객 300명이야');
    expect(app.profile.guests, 300);
    await agent.choose(m.quickReplies.firstWhere((r) => r.action == 'undo_profile'));
    expect(app.profile.guests, 150);
    expect(app.plan.guests, 150);
  });

  test('바뀐 게 없으면 반영 안내를 붙이지 않는다', () async {
    final m = await ConsultAgent().reply('하객 150명 기준 서울 예식장 추천해줘');
    expect(m.text, isNot(contains('내 정보에 반영했어요')));
  });
}

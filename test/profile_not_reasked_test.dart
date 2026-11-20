import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/understanding.dart';

/// 처음 입력 폼을 건너뛰었어도 저장된 내 정보(체크리스트·공유 링크 등)는 다시 묻지 않는다 (2026-11-21)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;
  setUpAll(() async {
    await Repos.venue.loadAll();
    await Repos.policy.loadAll();
    await Repos.booking.loadAll();
  });
  tearDown(() => app.resetProfile());

  for (final skipped in [false, true]) {
    test('하객·지역을 이미 알면 예식장 추천에서 다시 묻지 않는다 (폼 건너뜀=$skipped)', () async {
      if (skipped) {
        app.resetProfile();
        app.skipProfile();
        app.updateProfileDraft(const UserProfile(sido: '인천', age: 29, guests: 150));
      } else {
        app.saveProfile(const UserProfile(sido: '인천', age: 29, guests: 150));
      }
      final a = ConsultAgent();
      final hello = await a.start();
      expect(hello.text, contains('무엇부터'), reason: '아는 정보가 있으면 정보에 맞춘 인사');
      final m = await a.reply('공공예식장 추천해줘');
      expect(a.asking, isNull);
      expect(a.asking, isNot(Slot.guests));
      expect(m.text, contains('인천'));
    });
  }

  test('아는 정보가 하나도 없으면 일반 인사', () async {
    app.resetProfile();
    app.skipProfile();
    final hello = await ConsultAgent().start();
    expect(hello.text, contains('궁금한 걸 편하게'));
  });
}

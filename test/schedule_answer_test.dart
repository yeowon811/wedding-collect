import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';

/// 준비 순서 답변: 예식일이 가까우면 권장 시기가 지난 일을 따로 표시한다
void main() {
  tearDown(() => AppState.instance.resetProfile());

  test('예식 99일 전이면 D-365 같은 일은 "시기 지남"으로 표시한다', () async {
    AppState.instance.saveProfile(UserProfile(
      sido: '경기',
      weddingDate: DateTime.now().add(const Duration(days: 100)),
    ));
    final m = await ConsultAgent().reply('뭐부터 해야 해?');
    expect(m.isQuestion, isFalse);
    expect(m.text, contains('권장 시기가 지난 일이'));
    expect(m.text, contains('(권장 D-365, 시기 지남)'));
    expect(m.text, isNot(contains('• D-365')));
  });

  test('예식이 충분히 남았으면 지난 일 안내가 없다', () async {
    AppState.instance.saveProfile(UserProfile(
      sido: '경기',
      weddingDate: DateTime.now().add(const Duration(days: 400)),
    ));
    final m = await ConsultAgent().reply('뭐부터 해야 해?');
    expect(m.text, isNot(contains('시기 지남')));
    expect(m.text, contains('• D-365'));
  });
}

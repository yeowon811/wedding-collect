import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/date_check.dart';

/// "12/20에 예약 가능한 예식장": 날짜를 읽고, 예식 가능일 원문으로 판단하고, 모르는 건 모른다고 한다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('질문 속 날짜를 읽는다 (연도 없으면 다가오는 날)', () {
    final now = DateTime(2026, 11, 18);
    expect(parseAskDate('12/20일날 예약 가능한 예식장', now: now), DateTime(2026, 12, 20));
    expect(parseAskDate('12월 20일에 되는 곳', now: now), DateTime(2026, 12, 20));
    expect(parseAskDate('3/7 예식장', now: now), DateTime(2027, 3, 7));
    expect(parseAskDate('2027년 5월 1일', now: now), DateTime(2027, 5, 1));
    expect(parseAskDate('서울 예식장 추천해줘', now: now), isNull);
  });

  group('대화', () {
    setUp(() => AppState.instance.saveProfile(const UserProfile(
          sido: '서울', age: 29, stage: MarriageStage.engaged, guests: 150, budget: 3000)));
    tearDown(() => AppState.instance.resetProfile());

    test('예식장 추천 뒤 날짜를 물으면 다른 답: 날짜로 나누고, 정보 없음·예약 현황 모름을 알린다', () async {
      final agent = ConsultAgent();
      final first = await agent.reply('예식장 추천해줘');
      final second = await agent.reply('12/20일날 예약 가능한 예식장은 뭐야?');
      expect(second.text, isNot(first.text));
      expect(second.text, contains('12월 20일'));
      expect(second.text, contains('예약이 잡혔는지는 앱에서 알 수 없어요'));
      expect(second.text, contains('예식 가능일 정보가 앱에 없는 곳'));
      expect(second.trace.any((t) => t.startsWith('날짜 조건')), isTrue);
      for (final c in second.cards) {
        expect(c.badge, anyOf('12월 20일(일) 가능일', '기관 확인 필요', '날짜 정보 없음'));
      }
    });
  });
}

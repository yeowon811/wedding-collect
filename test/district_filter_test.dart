import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/core/utils/region.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';

/// 2026-11-19 피드백: 질문에서 찾는 구가 있으면 그 구만 (내 정보의 구는 먼저 보여 주기만)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;

  test('문장 속 시·군·구를 모두 나온 순서대로', () {
    expect(findSigungus('강남구 말고 송파구', sido: '서울').map((e) => e.$2), ['강남구', '송파구']);
    expect(findSigungus('동대문구 예식장', sido: '서울').map((e) => e.$2), ['동대문구']);
  });

  group('대화 (서울·강남구 거주)', () {
    setUpAll(() async {
      await Repos.venue.loadAll();
      await Repos.booking.loadAll();
    });
    setUp(() => app.saveProfile(const UserProfile(sido: '서울', sigungu: '강남구', age: 29, guests: 150)));
    tearDown(() => app.resetProfile());

    bool allIn(List<String> subtitles, String town) => subtitles.every((s) => s.contains(town));

    test('"강남구 말고 송파구" → 송파구만 (강남 제외가 아니라)', () async {
      final m = await ConsultAgent().reply('혹시 강남구 말고 송파구의 결혼식장도 알려줄 수 있어?');
      expect(m.cards, isNotEmpty);
      expect(allIn([for (final c in m.cards) c.subtitle], '송파구'), isTrue);
      expect(m.trace.join(' '), contains('송파구만'));
    });

    test('"송파구의 결혼식장만" → 더 보기도 송파구 안에서만', () async {
      final m = await ConsultAgent().reply('송파구의 결혼식장만 보여줘');
      final songpa = (await Repos.venue.loadAll()).where((v) => v.sido == '서울' && v.sigungu == '송파구').length;
      final more = m.quickReplies.where((r) => r.action == 'more').firstOrNull;
      if (songpa <= 3) {
        expect(more, isNull);
      } else {
        expect(more!.label, contains('${songpa - 3}곳'));
      }
    });

    test('짧은 후속 질문("그중에 무료만")은 앞의 구를 이어받는다', () async {
      final agent = ConsultAgent();
      await agent.reply('송파구 예식장 알려줘');
      final m = await agent.reply('그중에 무료만');
      expect(allIn([for (final c in m.cards) c.subtitle], '송파구'), isTrue);
    });

    test('구 이름 없이 "서울 예식장"이면 내 구(강남구)로 거르지 않는다', () async {
      final m = await ConsultAgent().reply('서울 예식장 추천해줘');
      expect(m.quickReplies.any((r) => r.action == 'more'), isTrue);
      expect(m.trace.join(' '), isNot(contains('강남구만')));
    });

    test('그 구에 예식장이 없으면 시도 전체에서 찾고 알려 준다', () async {
      final none = kSigunguBySido['서울']!.firstWhere(
          (g) => !Repos.venue.cached!.any((v) => v.sido == '서울' && v.sigungu == g));
      final m = await ConsultAgent().reply('$none 예식장 알려줘');
      expect(m.text, contains('$none에는 등록된 공공예식장이 없어서'));
    });
  });
}

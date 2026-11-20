import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/consult_tools.dart';
import 'package:wedding_collect/features/chat/agent/tool_planner.dart';
import 'package:wedding_collect/features/chat/answer/answer_ai.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_facts.dart';
import 'package:wedding_collect/features/chat/chat_agent.dart';

/// 2026-11-20 7차: 목록 답의 카드와 순서는 앱이 정한다 (실행마다 같게)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('예식장 순서: 내 구 → 하객 수용 → 무료 → 정원 큰 곳 → ID (끝까지 정해짐)', () async {
    final list = await ConsultTools.searchVenues(sido: '서울', guests: 120, sigungu: '강남구');
    for (var i = 0; i + 1 < list.length; i++) {
      final a = list[i], b = list[i + 1];
      int score(v) =>
          (v.sigungu == '강남구' ? 0 : 16) + (v.fits(120) == true ? 0 : (v.fits(120) == null ? 4 : 8)) + (v.isFree ? 0 : 2) + (v.isLimited ? 1 : 0);
      expect(score(a) <= score(b), isTrue);
      if (score(a) == score(b)) {
        final ca = a.capacity ?? -1, cb = b.capacity ?? -1;
        expect(ca > cb || (ca == cb && a.id.compareTo(b.id) < 0), isTrue, reason: '${a.id} ${b.id}');
      }
    }
    // 강남구: 하객 120명 되는 무료 두 곳 중 정원 큰 곳(주택도시개발공사 400명)이 먼저
    expect(list.take(2).map((v) => v.id), ['H080', 'H078']);
  });

  test('목록 답: Gemini가 다른 id·순서를 골라도 앱 순서 그대로', () async {
    final all = await Repos.venue.loadAll();
    const scope = QueryScope(sidos: ['서울'], towns: ['강남구'], guests: 120);
    final items = [for (final v in all.where((v) => v.sido == '서울' && v.sigungu == '강남구')) venueFact(v, scope: scope)];
    fillReasons(items, guests: 120);
    final f = AnswerFacts(question: 'q', kind: AnswerKind.venueList, scope: scope, items: items);
    final a = AnswerAi.resolve({
      'blocks': [
        {'type': 'headline', 'title_kind': 'app'},
        {'type': 'cards', 'ids': [items[3].id, items[2].id]},
      ],
    }, f);
    final b = AnswerAi.resolve({
      'blocks': [
        {'type': 'headline', 'title_kind': 'app'},
      ],
    }, f); // 카드 블록을 빼먹어도 앱이 붙임
    expect(a.allCards.map((c) => c.ref), [for (final i in items.take(3)) i.ref]);
    expect(b.allCards.map((c) => c.ref), [for (final i in items.take(3)) i.ref]);
  });

  test("계산 숫자('식대 6만원 120명')는 내 하객·예산으로 받지 않는다", () {
    final p = ToolPlanner.parse('calculate', {'expression': '30000000-60000*120', 'user_facts': 'guests=120; budget_manwon=3000'})!;
    final g = ToolPlanner.grounded(p.self, '3000만원에서 식대 6만원 120명 빼면?');
    expect(g.profile.guests, isNull);
    expect(g.profile.budget, isNull);
    final g2 = ToolPlanner.grounded(p.self, '총예산 3000만원이고 하객 120명이에요');
    expect(g2.profile.guests, 120);
    expect(g2.profile.budget, 3000);
  });

  test('목록 답에 Gemini 순위 블록은 붙지 않는다 (카드 되풀이)', () async {
    final all = await Repos.venue.loadAll();
    final items = [for (final v in all.where((v) => v.sigungu == '송파구' && v.sido == '서울')) venueFact(v)];
    final f = AnswerFacts(question: '그중에 주차 넓은 곳', kind: AnswerKind.venueList, items: items);
    final b = AnswerAi.resolve({
      'blocks': [
        {'type': 'headline', 'title_kind': 'app'},
        {'type': 'ranking', 'ids': [items[1].id, items[0].id]},
        {'type': 'cards'},
      ],
    }, f);
    expect(b.firstOf(BlockType.ranking), isNull);
    expect(b.allCards, isNotEmpty);
  });

  test('비교 답은 그대로 Gemini가 고른다', () async {
    final all = await Repos.venue.loadAll();
    final items = [for (final v in all.where((v) => v.sigungu == '강남구' && v.sido == '서울')) venueFact(v)];
    final f = AnswerFacts(question: 'q', kind: AnswerKind.venueCompare, items: items);
    final b = AnswerAi.resolve({
      'blocks': [
        {'type': 'headline', 'title_kind': 'app'},
        {'type': 'cards', 'ids': [items[2].id]},
      ],
    }, f);
    expect(b.allCards.map((c) => c.ref), [items[2].ref]);
  });

  test('여러 구를 물으면 구마다 번갈아 (강남구·송파구)', () async {
    await Repos.venue.loadAll();
    await Repos.booking.loadAll();
    AppState.instance.saveProfile(const UserProfile(sido: '서울', sigungu: '강남구', guests: 120));
    final agent = ConsultAgent();
    final m = await agent.choose(const QuickReply('강남구·송파구', action: 'refine', value: {
      'set': {
        'sido': ['서울'],
        'sigungu': ['강남구', '송파구'],
      },
      'remove': <String>[],
    }));
    final towns = [for (final c in m.blocks.allCards) c.values.first];
    expect(towns.take(2), ['강남구', '송파구']);
    AppState.instance.resetProfile();
  });
}

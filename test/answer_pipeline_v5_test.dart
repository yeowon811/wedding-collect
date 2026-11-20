import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/tool_planner.dart';
import 'package:wedding_collect/features/chat/answer/answer_ai.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_checks.dart';
import 'package:wedding_collect/features/chat/answer/answer_composer.dart';
import 'package:wedding_collect/features/chat/answer/answer_facts.dart';
import 'package:wedding_collect/features/chat/chat_agent.dart';

/// 2026-11-20 5차 수정: 도구 가드 · 제목은 앱이 · 카드 종류 · K6~K8 · 꼭 넣는 칩 · 앱 캐시 · 위험한 답만 검토 · 미리 부르던 이해 없앰
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('도구 가드', () {
    AgentPlan plan(String tool, [Map<String, Object?> a = const {}]) => ToolPlanner.parse(tool, a)!;

    test('예식장 질문에 전체 추천 → 예식장 검색', () {
      final g = ToolPlanner.guard(plan('recommend_overview'), '공공예식장 추천해줘');
      expect(g.plan.tool, 'search_venues');
      expect(g.note, isNotNull);
    });
    test("'한꺼번에·전부'면 전체 추천 그대로", () {
      final g = ToolPlanner.guard(plan('recommend_overview'), '예식장이랑 정책 전부 한꺼번에 추천해줘');
      expect(g.plan.tool, 'recommend_overview');
      expect(g.note, isNull);
    });
    test('P03 "대관료 제일 싼 서울 예식장" → 예식장 검색 + 대관료 낮은 순 + 서울', () {
      final g = ToolPlanner.guard(plan('search_policies', {'topic': 'wedding'}), '대관료 제일 싼 서울 예식장 3개만 알려줘');
      expect(g.plan.tool, 'search_venues');
      expect(g.plan.venue!.sort, 'fee_low');
      expect(g.plan.venue!.sidos, ['서울']);
    });
    test('예식장 검색인데 "싼"이면 대관료 낮은 순을 더함', () {
      final g = ToolPlanner.guard(plan('search_venues', {'sido': ['부산']}), '부산에서 대관료 싼 예식장');
      expect(g.plan.venue!.sort, 'fee_low');
      expect(g.plan.venue!.sidos, ['부산']);
    });
    test('정책 말이 있으면 정책 검색 그대로', () {
      final g = ToolPlanner.guard(plan('search_policies', {'topic': 'wedding'}), '공공예식장 비품비 지원 정책 알려줘');
      expect(g.plan.tool, 'search_policies');
    });
    test('"그중에 주차 넓은 곳"에 번호 없는 앞 목록 가리키기 → 앞 예식장 검색 고치기(주차)', () {
      final r = ToolPlanner.referToRefine(plan('refer_previous', {'index': 0}), '그중에 주차 넓은 곳');
      expect(r!.tool, 'search_venues');
      expect(r.args['refine_previous'], true);
      expect(r.venue!.needs, ['parking']);
      expect(ToolPlanner.referToRefine(plan('refer_previous', {'index': 2}), '두 번째 거 자세히'), isNull);
    });
    test("'말고' 붙은 구는 뺄 구로", () {
      final g = ToolPlanner.guard(plan('recommend_overview'), '서울 강남구 말고 송파구 예식장 추천해줘');
      expect(g.plan.venue!.towns, ['송파구']);
      expect(g.plan.venue!.excludeTowns, ['강남구']);
    });
  });

  group('제목·카드·칩·검사', () {
    late List<FactItem> venues;
    late FactItem policy;
    const scope = QueryScope(sidos: ['서울'], towns: ['강남구'], guests: 120);
    setUpAll(() async {
      final all = await Repos.venue.loadAll();
      venues = [for (final v in all.where((v) => v.sido == '서울' && v.sigungu == '강남구')) venueFact(v, scope: scope)];
      policy = policyFact((await Repos.policy.loadAll()).first);
    });

    NextOption opt(String label, String kind) => NextOption(QuickReply(label, text: label), kind: kind);

    AnswerFacts facts({AnswerKind kind = AnswerKind.venueList, List<FactItem>? items, bool followUp = false, String? templateOnly}) =>
        AnswerFacts(
          question: '공공예식장 추천해줘',
          kind: kind,
          scope: scope,
          items: items ?? venues,
          headBadges: headBadgesFor(kind, items ?? venues, scope),
          options: [
            opt('서초·송파까지', 'widen'),
            opt('서울 전체', 'widen'),
            opt('부산 9곳', 'widen'),
            opt('1곳 더 보기', 'more'),
            opt('이 지역 지원 정책', 'next'),
            opt('식대 업체 추천', 'next'),
          ],
          followUp: followUp,
          templateOnly: templateOnly,
        );

    test('Gemini가 쓴 숫자 제목은 쓰지 않고 앱 제목(범위·건수)으로', () {
      final f = facts();
      final b = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title_kind': 'custom', 'title': '공공예식장 5곳'},
        ],
      }, f);
      expect(b.first.title, '강남구 공공예식장 ${venues.length}곳');
    });

    test('비교 답은 숫자 없는 Gemini 제목을 쓸 수 있다', () {
      final f = facts(kind: AnswerKind.venueCompare, items: venues.take(2).toList());
      final ok = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title_kind': 'custom', 'title': '인원은 주택공사, 주차는 SETEC'},
        ],
      }, f);
      expect(ok.first.title, '인원은 주택공사, 주차는 SETEC');
      final digits = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title_kind': 'custom', 'title': '2곳 중 SETEC'},
        ],
      }, f);
      expect(digits.first.title, '예식장 2곳 비교');
    });

    test('꼭 넣는 칩(넓히기 2개·더 보기)이 먼저, 최대 4개', () {
      final b = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title_kind': 'app'},
          {'type': 'next', 'items': ['식대 업체 추천', '이 지역 지원 정책']},
        ],
      }, facts());
      expect(b.firstOf(BlockType.next)!.items, ['서초·송파까지', '서울 전체', '1곳 더 보기', '식대 업체 추천']);
    });

    test('Gemini가 칩을 빼먹어도 꼭 넣는 칩은 붙는다', () {
      final b = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title_kind': 'app'},
        ],
      }, facts());
      expect(b.firstOf(BlockType.next)!.items, ['서초·송파까지', '서울 전체', '1곳 더 보기']);
    });

    test('K7: 예식장 질문에 정책 카드는 앱이 뺀다', () {
      final f = facts(items: [...venues, policy]);
      final out = AnswerChecks.run([
        AnswerBlock(BlockType.headline, title: '강남구 공공예식장 ${f.count}곳'),
        AnswerBlock(BlockType.cards, cards: [venues.first.toCard(), policy.toCard()]),
      ], f);
      expect(out.blocks.allCards.map((c) => c.ref), [venues.first.ref]);
      expect(out.fixed.join(), contains('K7'));
    });

    test('K6: 제목 건수가 앱이 센 값과 다르면 걸린다', () {
      final out = AnswerChecks.run([const AnswerBlock(BlockType.headline, title: '강남구 공공예식장 9곳')], facts());
      expect(out.issues.map((i) => i.code), contains('K6'));
    });

    test('K8: 찾은 구가 제목에 없으면 걸린다', () {
      final out = AnswerChecks.run([AnswerBlock(BlockType.headline, title: '서울 공공예식장 ${venues.length}곳')], facts());
      expect(out.issues.map((i) => i.code), contains('K8'));
      final ok = AnswerChecks.run([AnswerBlock(BlockType.headline, title: '강남구 공공예식장 ${venues.length}곳')], facts());
      expect(ok.issues.where((i) => i.code == 'K6' || i.code == 'K8'), isEmpty);
    });

    test('앱 캐시: 같은 조건·결과면 Gemini를 다시 부르지 않는다', () async {
      var writes = 0;
      final composer = AnswerComposer.fake(write: (_) async {
        writes++;
        return {
          'blocks': [
            {'type': 'headline', 'title_kind': 'app', 'badges': ['all_free']},
            {'type': 'cards', 'ids': [venues.first.id]},
          ],
        };
      });
      final a = await composer.compose(facts());
      final b = await composer.compose(facts());
      expect(writes, 1);
      expect(a.path, 'ai');
      expect(b.path, 'ai_cached');
      expect(b.calls, 0);
      expect(b.blocks.headline, a.blocks.headline);
    });

    test('위험한 답만 검토: 예식장 목록은 생략, 정책·후속 질문은 검토', () async {
      var reviews = 0;
      Future<Map<String, Object?>?> review(String _) async {
        reviews++;
        return {'answers_question': true, 'scope_ok': true, 'context_ok': true, 'repeats_previous': false};
      }

      Future<Map<String, Object?>?> write(String _) async => {
            'blocks': [
              {'type': 'headline', 'title_kind': 'app'},
            ],
          };
      await AnswerComposer.fake(write: write, reviewer: review).compose(facts());
      expect(reviews, 0);
      await AnswerComposer.fake(write: write, reviewer: review).compose(facts(followUp: true));
      expect(reviews, 1);
      final pf = AnswerFacts(question: '받을 수 있는 정책', kind: AnswerKind.policyList, items: [policy]);
      await AnswerComposer.fake(write: write, reviewer: review).compose(pf);
      expect(reviews, 2);
    });

    test('더 보기처럼 기본 틀로 정한 답은 Gemini를 부르지 않는다', () async {
      var writes = 0;
      final c = await AnswerComposer.fake(write: (_) async {
        writes++;
        return null;
      }).compose(facts(templateOnly: '더 보기: 앞 결과의 다음 장'));
      expect(writes, 0);
      expect(c.path, 'template');
    });

    test('Gemini 입력은 짧게: 긴 글·표 내용 없이 ID·핵심 값·건수·범위', () {
      final f = facts();
      final json = AnswerAi.factsJson(f);
      expect(json, contains('"app_headline"'));
      expect(json, contains('"place":"강남구"'));
      expect(json, isNot(contains('"fields"'))); // 목록 답엔 표 칸 이름도 보내지 않음
      expect(json.length, lessThan(2500));
    });
  });

  test('E2: 내 정보에 소득이 있어도(판정에서 이미 빠져도) 이름이 나온 대출은 "대상이 아니에요"', () async {
    await Repos.venue.loadAll();
    AppState.instance.saveProfile(UserProfile(
        sido: '서울', sigungu: '강남구', age: 29, guests: 120, homeless: true, income: 8000, weddingDate: DateTime(2027, 5, 15)));
    final m = await ConsultAgent().reply('부부 합쳐 연봉 8천인데 신혼부부 전세대출 돼?');
    expect(m.blocks.headline, '그 대출은 대상이 아니에요');
    expect(m.blocks.allCards.first.badge!.text, '소득 초과');
    expect(m.text, contains('상한을 넘는 정책: 신혼부부전용 전세자금 대출(연 7,500만원)')); // "0건 뺐어요"와 어긋나지 않게
    expect(m.text, isNot(contains('0건은 뺐어요')));
    AppState.instance.resetProfile();
  });

  test('질문 이해를 미리 함께 부르던 호출이 없다 (도구 고르기 실패 때만 이해 호출)', () {
    final src = File('lib/features/chat/agent/consult_agent.dart').readAsStringSync();
    expect(src, isNot(contains('_prefetched')));
    expect(src, contains('final planned = await _planned(text);'));
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/tool_planner.dart';
import 'package:wedding_collect/features/chat/agent/venue_features.dart';
import 'package:wedding_collect/features/chat/answer/answer_ai.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_facts.dart';

/// 2026-11-20 6차: 카드 이유는 앱이 데이터로 · 도구 선언 줄이기(user_facts 한 줄) · "3개만" 카드 수
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('카드 이유 (앱이 데이터로)', () {
    late List<FactItem> items;
    const scope = QueryScope(sidos: ['서울'], towns: ['강남구'], guests: 120);
    setUpAll(() async {
      final all = await Repos.venue.loadAll();
      items = [for (final v in all.where((v) => v.sido == '서울' && v.sigungu == '강남구')) venueFact(v, scope: scope)];
      fillReasons(items, guests: 120);
    });

    test('데이터로 참인 이유만, 18자 이내', () {
      final caps = [for (final i in items) if (i.venue!.capacity != null) i.venue!.capacity!];
      final maxCap = caps.reduce((a, b) => a > b ? a : b);
      for (final i in items) {
        final v = i.venue!;
        expect(i.reasons.containsKey('biggest'), v.capacity == maxCap, reason: v.name);
        expect(i.reasons.containsKey('free'), v.rentalFee == 0, reason: v.name);
        expect(i.reasons.containsKey('fits'), v.fits(120) == true, reason: v.name);
        final p = VenueFeatures.parking(v);
        if (p.ok == Avail.yes) expect(i.reasons['parking'], p.spaces != null ? '주차 ${p.spaces}대' : '주차 가능');
        if (p.ok != Avail.yes) expect(i.reasons.containsKey('parking'), isFalse);
        for (final r in i.reasons.values) {
          expect(r.length, lessThanOrEqualTo(18), reason: r);
        }
      }
    });

    AnswerFacts facts({int? limit}) => AnswerFacts(
          question: '공공예식장 추천해줘',
          kind: AnswerKind.venueList,
          scope: scope,
          items: items,
          headBadges: headBadgesFor(AnswerKind.venueList, items, scope),
          cardLimit: limit,
        );

    test('Gemini는 키만: 키에 맞는 앱 문장, 모르는 키·자유 글은 버림', () {
      // 목록 답은 앱이 첫 카드를 정하고(7차), Gemini의 이유 키는 그 카드에 붙는다
      final first = items.first;
      final key = first.reasons.keys.first;
      final ok = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title_kind': 'app'},
          {'type': 'cards', 'reason_key': key},
        ],
      }, facts());
      expect(ok.allCards.first.ref, first.ref);
      expect(ok.allCards.first.reason, first.reasons[key]);
      final made = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title_kind': 'app'},
          {'type': 'cards', 'ids': [items.last.id], 'reason': '주차 공간이 여유로워요', 'reason_key': 'roomy'},
        ],
      }, facts());
      expect(made.allCards.first.reason, isNull);
    });

    test('Gemini에 보내는 결과에 이유 키 목록', () {
      final j = jsonDecode(AnswerAi.factsJson(facts())) as Map;
      expect((j['items'] as List).any((x) => (x as Map)['reasons'] != null), isTrue);
    });

    test('"2곳만"이면 Gemini가 1곳만 골라도 앱이 2곳으로 채운다', () {
      final b = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title_kind': 'app'},
          {'type': 'cards', 'ids': [items.first.id]},
        ],
      }, facts(limit: 2));
      expect(b.allCards.length, 2);
    });
  });

  test('답의 주인공 카드(pinned)는 Gemini가 안 골라도 맨 앞, 앱 제목이면 앱 배지', () async {
    final ps = await Repos.policy.loadAll();
    final over = policyFact(ps[0], miss: true, missReason: '소득 초과');
    final others = [for (final p in ps.skip(1).take(3)) policyFact(p)];
    final f = AnswerFacts(
      question: '신혼부부 전세대출 돼?',
      kind: AnswerKind.policyList,
      items: [...others, over],
      pinned: [over.ref],
      hint: const AnswerHint(
          kind: AnswerKind.policyList, headline: '그 대출은 대상이 아니에요', headBadges: [BlockBadge('소득 상한 연 7,500만원', Tone.no)]),
    );
    final b = AnswerAi.resolve({
      'blocks': [
        {'type': 'headline', 'title_kind': 'app', 'badges': ['likely_count']},
        {'type': 'cards', 'ids': [others[0].id, others[1].id]},
      ],
    }, f);
    expect(b.allCards.first.ref, over.ref);
    expect(b.first.badges.first.text, '소득 상한 연 7,500만원');
  });

  group('도구 선언 줄이기', () {
    test('user_facts는 한 줄 글 (도구마다 객체를 반복하지 않음)', () {
      final decl = jsonEncode([for (final d in ToolPlanner.declarations) d.toJson()]);
      expect(decl.length, lessThan(9000)); // 5차 18,346자 → 6차 약 6,900자
      expect(decl, isNot(contains('income_manwon')));
      expect(ToolPlanner.prompt, contains('income_manwon'));
    });

    test('한 줄 user_facts를 읽는다 (숫자·참거짓·시군구)', () {
      final p = ToolPlanner.parse('search_policies', {
        'topic': 'housing',
        'user_facts': 'lives_sido=경기; lives_sigungu=수원시; guests=100; income_manwon=8,000; homeless=true',
      })!;
      expect(p.self.profile.sido, '경기');
      expect(p.self.profile.sigungu, '수원시');
      expect(p.self.profile.guests, 100);
      expect(p.self.profile.income, 8000);
      expect(p.self.profile.homeless, isTrue);
      expect(p.self.livesGiven, isTrue);
    });

    test('예전 객체 형식도 그대로 읽는다', () {
      final p = ToolPlanner.parse('search_venues', {
        'user_facts': {'age': 29},
      })!;
      expect(p.self.profile.age, 29);
    });
  });

  group('"N개만" 카드 수', () {
    test('질문 속 카드 수', () {
      expect(ConsultAgent.cardLimitOf('대관료 제일 싼 서울 예식장 3개만 알려줘'), 3);
      expect(ConsultAgent.cardLimitOf('두 곳만 보여줘'), 2);
      expect(ConsultAgent.cardLimitOf('5곳 추천해줘'), 5);
      expect(ConsultAgent.cardLimitOf('결혼식까지 3개월 남았어'), isNull);
      expect(ConsultAgent.cardLimitOf('2곳 비교해줘'), isNull);
      expect(ConsultAgent.cardLimitOf('13곳만'), isNull);
    });

    test('"강남구 예식장 2곳만" → 카드 2장, 더 보기 없음, 넓히기는 그대로', () async {
      await Repos.venue.loadAll();
      await Repos.booking.loadAll();
      AppState.instance.saveProfile(const UserProfile(sido: '서울', sigungu: '강남구', guests: 120));
      final m = await ConsultAgent().reply('강남구 예식장 2곳만 알려줘');
      expect(m.blocks.allCards.length, 2);
      expect(m.quickReplies.any((r) => r.action == 'more'), isFalse);
      expect(m.quickReplies.map((r) => r.label), contains('서울 전체'));
      AppState.instance.resetProfile();
    });
  });
}

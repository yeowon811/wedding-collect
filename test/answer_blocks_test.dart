import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/core/utils/korean.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/data/user_data_codec.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/answer/answer_ai.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_checks.dart';
import 'package:wedding_collect/features/chat/answer/answer_facts.dart';
import 'package:wedding_collect/features/chat/answer/answer_template.dart';
import 'package:wedding_collect/features/chat/answer/venue_scope.dart';
import 'package:wedding_collect/features/chat/chat_agent.dart';

/// 2026-11-20 새 답 화면 (블록) · 검사 K1~K5 · 범위 넓히기 · 조사 고치기
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('조사 고치기', () {
    test('받침에 맞는 조사', () {
      expect(withJosa('강남구', '이/가'), '강남구가');
      expect(withJosa('송파구', '을/를'), '송파구를');
      expect(withJosa('컨벤션홀', '을/를'), '컨벤션홀을');
      expect(withJosa('컨벤션홀', '으로/로'), '컨벤션홀로'); // ㄹ 받침
      expect(withJosa('서울숲', '으로/로'), '서울숲으로');
      expect(withJosa('부산', '은/는'), '부산은');
      expect(withJosa('SETEC', '이/가'), 'SETEC이'); // C → 받침 없음? 영문은 대략: c는 받침 없음
      expect(withJosa('3', '이/가'), '3이');
      expect(withJosa('2', '이/가'), '2가');
      expect(withJosa('한성백제홀(송파)', '을/를'), '한성백제홀(송파)을');
    });
    test('을(를) 표기와 틀린 조사 고치기', () {
      expect(fixJosa('강남구을(를) 골랐어요'), '강남구를 골랐어요');
      expect(fixJosa('예식장이(가) 없어요'), '예식장이 없어요');
      expect(fixJosaAfter('마루공원를 추천해요', ['마루공원']), '마루공원을 추천해요');
      expect(fixJosaAfter('마루공원이에요', ['마루공원']), '마루공원이에요'); // 이어지는 말은 그대로
    });
  });

  group('블록 저장', () {
    test('JSON으로 바꿨다 되돌려도 같다', () {
      final blocks = [
        const AnswerBlock(BlockType.headline, title: '강남구 공공예식장 4곳', badges: [BlockBadge('모두 무료', Tone.good)]),
        const AnswerBlock(BlockType.filters, filters: [FilterChipData('강남구', remove: 'sigungu')]),
        const AnswerBlock(BlockType.cards, cards: [
          BlockCard(ref: 'venue:H078', title: 'A', badge: BlockBadge('120명 OK', Tone.good), values: ['강남구', '100~200명', '무료'], reason: '인원 여유'),
        ]),
        const AnswerBlock(BlockType.table, columns: ['', 'A', 'B'], rows: [['정원', '1', '2']]),
        const AnswerBlock(BlockType.fold, sources: ['s'], log: ['l'], detail: 'd'),
      ];
      final back = [for (final b in blocks) AnswerBlock.fromJson(b.toJson())!];
      expect(back.plainText, blocks.plainText);
      expect(back[2].cards.first.badge, const BlockBadge('120명 OK', Tone.good));
      expect(back[1].filters.first.remove, 'sigungu');
    });

    test('대화 저장(계정)에도 블록이 남는다', () async {
      final app = AppState.instance;
      app.clearChat();
      app.addChat(const ChatMessage(fromUser: false, text: '글', blocks: [AnswerBlock(BlockType.headline, title: '제목')]));
      final saved = UserDataCodec.encode(app);
      final copy = AppState.instance;
      UserDataCodec.apply(copy, saved.cast<String, dynamic>(), const []);
      expect(copy.chat.last.blocks.first.title, '제목');
      app.clearChat();
    });
  });

  group('검사 K1~K5', () {
    late List<FactItem> items;
    late QueryScope scope;
    setUpAll(() async {
      final all = await Repos.venue.loadAll();
      scope = const QueryScope(sidos: ['서울'], towns: ['송파구'], guests: 120);
      items = [
        for (final v in all.where((v) => v.sido == '서울' && v.sigungu == '송파구')) venueFact(v, scope: scope),
        venueFact(all.firstWhere((v) => v.sido == '서울' && v.sigungu == '강남구'), scope: scope),
      ];
    });

    AnswerFacts facts({PrevAnswer? prev, String q = '송파구 예식장'}) =>
        AnswerFacts(
            question: q,
            kind: AnswerKind.venueList,
            scope: scope,
            items: items,
            previous: prev,
            total: items.length - 1,
            headBadges: headBadgesFor(AnswerKind.venueList, items, scope));

    test('K1: 고른 구 밖의 카드는 앱이 뺀다', () {
      final f = facts();
      final out = AnswerChecks.run([
        const AnswerBlock(BlockType.headline, title: '송파구 공공예식장'),
        AnswerBlock(BlockType.cards, cards: [for (final i in items.reversed.take(2)) i.toCard()]),
      ], f);
      expect(out.blocks.allCards.every((c) => !c.ref.endsWith(items.last.id)), isTrue);
      expect(out.fixed.join(), contains('K1'));
    });

    test('K2: 결과에 없는 숫자는 다시 쓰게 한다', () {
      final out = AnswerChecks.run([const AnswerBlock(BlockType.headline, title: '송파구 예식장 97곳')], facts());
      expect(out.issues.map((i) => i.code), contains('K2'));
    });

    test('K5: 긴 제목·칩 5개·긴 칩·두 문장 (짧은 형식 freeText=false)', () {
      AnswerAi.freeText = false;
      addTearDown(() => AnswerAi.freeText = true);
      final out = AnswerChecks.run([
        const AnswerBlock(BlockType.headline, title: '송파구에 있는 공공예식장을 모두 정리해서 보여 드릴게요'),
        const AnswerBlock(BlockType.text, text: '모두 무료예요. 주차도 돼요.'),
        const AnswerBlock(BlockType.next, items: ['a', 'b', 'c', 'd', '아주아주아주아주긴칩이름이에요']),
      ], facts());
      final msgs = out.issues.map((i) => i.message).join(' / ');
      expect(msgs, contains('제목'));
      expect(msgs, contains('칩 5개'));
      expect(msgs, contains('문장'));
    });

    test('K5: 첫 블록은 headline 또는 ask', () {
      final out = AnswerChecks.run([const AnswerBlock(BlockType.text, text: '안녕하세요.')], facts());
      expect(out.issues.any((i) => i.message.contains('첫 블록')), isTrue);
    });

    test('K3: 후속 질문인데 앞 답과 같으면 앱이 "같은 결과" 문장을 넣는다 (다시 쓰기 없음)', () {
      final cards = [for (final i in items.take(2)) i.toCard()];
      final prev = PrevAnswer(question: '송파구 예식장', headline: '송파구 3곳', ids: [for (final c in cards) c.ref.split(':').last]);
      final out = AnswerChecks.run([
        const AnswerBlock(BlockType.headline, title: '송파구 3곳'),
        AnswerBlock(BlockType.cards, cards: cards),
      ], facts(prev: prev, q: '그중에 주차 되는 곳'));
      expect(out.issues.map((i) => i.code), isNot(contains('K3')));
      expect(out.fixed.join(), contains('K3'));
      expect(out.blocks[1].text, '조건을 바꿔도 앞과 같은 결과예요.');
    });

    test('K4: 정원이 빈 곳은 주황 배지 + 문의처', () async {
      final all = await Repos.venue.loadAll();
      final v = all.firstWhere((v) => v.capacity == null);
      final f = venueFact(v, scope: const QueryScope(guests: 100));
      expect(f.badge!.tone, Tone.check);
      expect(f.contact, contains(v.bookingContact));
      expect(f.empty, contains('정원'));
    });

    test('Gemini JSON → 블록: 모르는 id·배지 키는 버리고 값은 앱이 채운다', () {
      final f = facts();
      final blocks = AnswerAi.resolve({
        'blocks': [
          {'type': 'headline', 'title': '송파구 예식장', 'badges': ['fit_count', 'made_up']},
          {'type': 'cards', 'ids': [items.first.id, 'H999'], 'reason': '넓어요'},
          {'type': 'caution', 'text': '허용되지 않은 블록'},
          {'type': 'next', 'items': ['직접 만든 칩', '두번째 만든 칩']},
        ],
      }, f);
      expect(blocks.first.type, BlockType.headline);
      expect(blocks.first.badges.length, 1); // fit_count만
      // 7차: 목록 답은 앱이 카드와 순서를 정한다 (Gemini ids는 쓰지 않음)
      expect(blocks.allCards.map((c) => c.ref), [for (final i in items.take(3)) i.ref]);
      expect(blocks.allCards.first.values, items.first.values);
      expect(blocks.where((b) => b.type == BlockType.filters), isNotEmpty); // 조건 칩은 앱이 붙임
      expect(blocks.firstOf(BlockType.next)!.items, ['직접 만든 칩']); // 새 칩은 1개까지
    });

    test('기본 틀은 형식 검사를 통과한다', () {
      final f = facts();
      final t = AnswerTemplate.build(f);
      final out = AnswerChecks.run(t, f);
      expect(out.issues.where((i) => i.code == 'K5'), isEmpty, reason: out.issues.join('\n'));
      expect(t.first.type, BlockType.headline);
      expect(t.last.type, BlockType.fold);
    });
  });

  group('범위 넓히기 (R9)', () {
    test('맞닿은 구는 좌표로 가까운 구', () async {
      final all = await Repos.venue.loadAll();
      final adj = VenueScope.adjacentTowns(all, '서울', ['강남구']);
      expect(adj.length, 2);
      expect(adj, isNot(contains('강남구')));
      // 강남구 옆: 서초·송파·성동·광진·강동 중에서
      expect(adj.every((t) => ['서초구', '송파구', '성동구', '광진구', '강동구', '용산구', '동작구'].contains(t)), isTrue, reason: '$adj');
    });

    test('공공예식장이 없는 대전 → 가까운 시도', () async {
      final all = await Repos.venue.loadAll();
      final near = VenueScope.nearbySidos(all, '대전').map((e) => e.$1).toList();
      expect(near, contains('세종'));
      expect(near.every((s) => ['세종', '충남', '충북', '전북'].contains(s)), isTrue, reason: '$near');
    });
  });

  group('상담 답이 블록으로 (규칙 경로, Gemini 없음)', () {
    final app = AppState.instance;
    setUpAll(() async {
      await Repos.venue.loadAll();
      await Repos.booking.loadAll();
    });
    setUp(() => app.saveProfile(const UserProfile(sido: '서울', sigungu: '강남구', age: 29, guests: 120)));
    tearDown(() => app.resetProfile());

    test('장소 없이 물으면 내 구부터 + 조건 칩 + 넓히기 칩', () async {
      final agent = ConsultAgent();
      final m = await agent.reply('공공예식장 추천해줘');
      expect(m.blocks.first.type, BlockType.headline);
      expect(m.blocks.first.title, contains('강남구'));
      final filters = m.blocks.firstOf(BlockType.filters)!.filters.map((f) => f.label);
      expect(filters, containsAll(['강남구', '하객 120명']));
      expect(m.blocks.allCards, isNotEmpty);
      expect(m.blocks.allCards.length, lessThanOrEqualTo(3));
      for (final c in m.blocks.allCards) {
        expect(c.values.first, '강남구');
      }
      expect(m.quickReplies.map((r) => r.label), contains('서울 전체'));
      expect(m.quickReplies.length, lessThanOrEqualTo(5));

      // 넓히기: 서울 전체 (Gemini 없이 앱이 조건을 고쳐 다시 찾음)
      final wide = await agent.choose(m.quickReplies.firstWhere((r) => r.label == '서울 전체'));
      expect(wide.blocks.first.title, startsWith('서울 공공예식장'));
      expect(wide.blocks.firstOf(BlockType.filters)!.filters.map((f) => f.label), isNot(contains('강남구')));

      // 조건 칩 ✕: 하객 빼기
      final noGuests = await agent.choose(const QuickReply('하객 120명 빼고', action: 'refine', value: {'set': <String, Object?>{}, 'remove': ['guests']}));
      expect(noGuests.blocks.firstOf(BlockType.filters)!.filters.map((f) => f.label), isNot(contains('하객 120명')));
    });

    test('"서울 예식장"처럼 시도를 말하면 내 구로 좁히지 않는다', () async {
      final m = await ConsultAgent().reply('서울 예식장 추천해줘');
      expect(m.blocks.first.title, startsWith('서울 공공예식장'));
    });

    test('대전(0곳) → 가까운 시도 칩', () async {
      final m = await ConsultAgent().reply('대전 공공예식장 알려줘');
      expect(m.blocks.first.title, contains('대전'));
      expect(m.quickReplies.any((r) => r.label.startsWith('세종')), isTrue);
    });

    test('상담 시작은 제목 + 추천 칩', () async {
      final m = await ConsultAgent().start();
      expect(m.blocks.first.title, '무엇부터 알아볼까요?');
      expect(m.quickReplies, isNotEmpty);
    });

    test('되묻기는 ask 블록', () async {
      app.resetProfile();
      final m = await ConsultAgent().reply('받을 수 있는 정책 알려줘');
      expect(m.isQuestion, isTrue);
      expect(m.blocks.first.type, BlockType.ask);
    });

    test('기본 틀 답은 형식 검사 K5를 통과한다 (여러 질문)', () async {
      for (final q in [
        '공공예식장 추천해줘',
        '받을 수 있는 정책 알려줘',
        '드레스 업체 추천해줘',
        '식대 1인 6만5천원, 150명이면?',
        '뭐부터 해야 해?',
        '2027년 5월 15일에 예약 가능한 예식장 있어?',
        '송파구 무료 예식장',
      ]) {
        final agent = ConsultAgent();
        final m = await agent.reply(q);
        final f = agent.lastFacts!;
        final issues = AnswerChecks.format(m.blocks, f);
        expect(issues, isEmpty, reason: '$q → ${issues.join(' / ')}\n${m.blocks.plainText}');
      }
    });
  });
}

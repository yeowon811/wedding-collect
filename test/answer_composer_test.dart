import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/answer/answer_ai.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_composer.dart';
import 'package:wedding_collect/features/chat/answer/answer_facts.dart';

/// ④ Gemini 작성 → ⑤ 앱 검사 + Gemini 검토 → 한 번 다시 → 기본 틀 (가짜 Gemini로 확인)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AnswerFacts f;
  setUpAll(() async {
    final all = await Repos.venue.loadAll();
    const scope = QueryScope(sidos: ['서울'], towns: ['강남구'], guests: 120);
    final items = [for (final v in all.where((v) => v.sigungu == '강남구' && v.sido == '서울')) venueFact(v, scope: scope)];
    f = AnswerFacts(
      question: '공공예식장 추천해줘',
      kind: AnswerKind.venueList,
      scope: scope,
      items: items,
      headBadges: headBadgesFor(AnswerKind.venueList, items, scope),
    );
    fillReasons(items, guests: 120);
  });

  AnswerFacts follow() => AnswerFacts(
        question: '그중에 무료만',
        kind: f.kind,
        scope: f.scope,
        items: f.items,
        headBadges: f.headBadges,
        followUp: true,
      );

  Map<String, Object?> good() => {
        'blocks': [
          {'type': 'headline', 'title': '강남구 공공예식장 ${f.count}곳', 'badges': ['all_free']},
          {'type': 'cards', 'ids': [f.items.first.id, f.items[1].id], 'reason_key': 'free'},
        ],
      };
  Map<String, Object?> tooLong() => {
        'blocks': [
          {'type': 'headline', 'title_kind': 'app'},
          {'type': 'text', 'text': '모두 무료예요. 주차도 돼요. 정원도 넉넉해요.'},
        ],
      };
  const pass = <String, Object?>{'answers_question': true, 'scope_ok': true, 'context_ok': true, 'repeats_previous': false};

  test('작성·검사·검토 통과 → Gemini 답', () async {
    final c = await AnswerComposer.fake(write: (_) async => good(), reviewer: (_) async => pass).compose(f);
    expect(c.path, 'ai');
    expect(c.calls, 1); // 위험 낮은 예식장 목록 → 검토 생략 (앱 검사만)
    expect(c.blocks.last.log.join(), contains('검토 생략'));
    expect(c.blocks.first.title, startsWith('강남구'));
    expect(c.blocks.allCards.first.reason, '대관료 무료'); // 이유 문장은 앱이 데이터로
    expect(c.blocks.last.type, BlockType.fold);
  });

  test('형식 검사(K5)에 걸리면 고칠 점을 붙여 한 번 다시 쓴다 (짧은 형식 freeText=false)', () async {
    AnswerAi.freeText = false;
    addTearDown(() => AnswerAi.freeText = true);
    final inputs = <String>[];
    var n = 0;
    final c = await AnswerComposer.fake(
      write: (input) async {
        inputs.add(input);
        return n++ == 0 ? tooLong() : good();
      },
      reviewer: (_) async => pass,
    ).compose(f);
    expect(c.path, 'ai_rewrite');
    expect(inputs.last, contains('고칠 점'));
    expect(inputs.last, contains('문장'));
  });

  test('검토가 두 번 막으면 기본 틀 (후속 질문이라 검토함)', () async {
    final c = await AnswerComposer.fake(
      write: (_) async => good(),
      reviewer: (_) async => {...pass, 'scope_ok': false, 'fix': '범위를 질문대로'},
    ).compose(follow());
    expect(c.path, 'template_after_ai');
    expect(c.calls, 4);
    expect(c.blocks.first.type, BlockType.headline);
    expect(c.blocks.last.log.join(), contains('범위'));
  });

  test('Gemini 응답이 없으면 기본 틀 (R14)', () async {
    final c = await AnswerComposer.fake(write: (_) async => null).compose(f);
    expect(c.path, 'template_after_ai');
    expect(c.blocks.allCards, isNotEmpty);
  });
}

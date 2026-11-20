import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/answer/answer_ai.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_checks.dart';
import 'package:wedding_collect/features/chat/answer/answer_facts.dart';
import 'package:wedding_collect/features/chat/answer/answer_template.dart';

/// 2026-11-20 설명 글 제한 풀기 (AnswerAi.freeText): 길이·문장 수는 보지 않고, 숫자·이름·건수·범위·카드 순서 검사는 그대로
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<FactItem> items;
  const scope = QueryScope(sidos: ['서울'], towns: ['강남구'], guests: 120);
  setUpAll(() async {
    final all = await Repos.venue.loadAll();
    items = [for (final v in all.where((v) => v.sido == '서울' && v.sigungu == '강남구')) venueFact(v, scope: scope)];
    fillReasons(items, guests: 120);
    AnswerChecks.knownNames = {for (final v in all) if (v.name.split('(').first.trim().length >= 5) v.name.split('(').first.trim()};
  });
  tearDownAll(() => AnswerChecks.knownNames = {});

  AnswerFacts facts() => AnswerFacts(question: '공공예식장 추천해줘', kind: AnswerKind.venueList, scope: scope, items: items);
  final long = '사시는 강남구부터 찾았어요. 하객 수가 들어가는 곳을 먼저 놓았어요. 마루공원은 정원 정보가 없어 문의가 필요해요. '
      '더 넓게 보려면 서초·송파까지 넓혀 보세요. 예약 현황은 수집한 날 기준이라 바뀔 수 있어요.';

  test('긴 설명·여러 문장은 K5에 걸리지 않는다', () {
    expect(AnswerAi.freeText, isTrue);
    final out = AnswerChecks.run([
      AnswerBlock(BlockType.headline, title: '강남구 공공예식장 ${items.length}곳'),
      AnswerBlock(BlockType.text, text: long),
    ], facts());
    expect(out.issues, isEmpty, reason: out.issues.join(' / '));
  });

  test('설명에 결과에 없는 숫자·예식장 이름이 나오면 K2', () {
    final out = AnswerChecks.run([
      AnswerBlock(BlockType.headline, title: '강남구 공공예식장 ${items.length}곳'),
      const AnswerBlock(BlockType.text, text: '한강공원 광나루 장미원도 좋아요. 정원은 777명이에요.'),
    ], facts());
    final msgs = out.issues.where((i) => i.code == 'K2').map((i) => i.message).join(' / ');
    expect(msgs, contains('777'));
    expect(msgs, contains('한강공원 광나루 장미원'));
  });

  test('카드마다 이유 (앱 문장, 키 순서대로)', () {
    final first3 = AnswerTemplate.cardItems(facts()).take(3).toList();
    final keys = [for (final i in first3) i.reasons.keys.firstOrNull ?? ''];
    final b = AnswerAi.resolve({
      'blocks': [
        {'type': 'headline', 'title_kind': 'app'},
        {'type': 'text', 'text': long},
        {'type': 'cards', 'reason_keys': keys},
      ],
    }, facts());
    expect([for (final c in b.allCards) c.reason], [for (final (k, i) in first3.indexed) i.reasons[keys[k]]]);
    expect(b.firstOf(BlockType.text)!.text, long);
  });

  test('제목은 여전히 앱이 (Gemini 숫자 제목은 안 씀)', () {
    final b = AnswerAi.resolve({
      'blocks': [
        {'type': 'headline', 'title_kind': 'custom', 'title': '추천 5곳'},
      ],
    }, facts());
    expect(b.first.title, '강남구 공공예식장 ${items.length}곳');
  });
}

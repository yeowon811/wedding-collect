import '../../../core/utils/region.dart';
import 'answer_blocks.dart';
import 'answer_facts.dart';

/// 답 검사 K1~K5 (docs/ai-design/answer_design_blaze.md 3-2장 가).
/// - K1 조건 충족: 카드가 질문 조건을 실제로 만족하는지 → 아니면 카드를 뺀다(앱이 고침)
/// - K2 숫자·이름 출처: 제목·설명·이유·단계·칩의 숫자가 조회 결과에 있는지 → 다시 쓰기
/// - K3 직전 답과 같은지 → 후속 질문인데 같으면 다시 쓰기
/// - K4 빈 값 안내: 비어 있는 값이 있는 카드에 문의처가 있는지 → 앱이 붙임
/// - K5 형식(F1~F14): 첫 블록·글자 수·문장 수·칩 수·카드 수·제목 숫자 반복 → 다시 쓰기
class CheckIssue {
  const CheckIssue(this.code, this.message);

  final String code; // K1 … K5
  final String message;

  @override
  String toString() => '$code $message';
}

class CheckResult {
  const CheckResult(this.blocks, this.issues, this.fixed);

  final List<AnswerBlock> blocks; // K1·K4를 앱이 고친 블록
  final List<CheckIssue> issues; // 다시 쓰기가 필요한 문제
  final List<String> fixed; // 앱이 고친 것 (기록용)

  bool get ok => issues.isEmpty;
}

class AnswerChecks {
  static const titleMax = 24; // F1 20자 안팎
  static const textMax = 60; // F2·F3 한 줄
  static const chipMax = 12; // F7
  static const chipCount = 4;
  static const reasonMax = 18; // 15자 안팎
  static const stepMax = 20; // 단계당 15자 안팎
  static const askMax = 32;

  static final _num = RegExp(r'\d+(?:\.\d+)?');

  static Set<String> numbers(String s) => _num.allMatches(s.replaceAll(',', '')).map((m) => m[0]!).toSet();

  /// 문장 수 (요./다./?/! 기준)
  static int sentences(String s) {
    final t = s.trim();
    if (t.isEmpty) return 0;
    final n = RegExp(r'(요|다|죠|까)[.?!]?(\s|$)|[.?!](\s|$)').allMatches(t).length;
    return n == 0 ? 1 : n;
  }

  static CheckResult run(List<AnswerBlock> input, AnswerFacts f, {bool strictFormat = true}) {
    final issues = <CheckIssue>[];
    final fixed = <String>[];
    var blocks = [...input];

    // ── K7 카드 종류 = 질문 목적 (예식장 질문엔 예식장 카드만). 전체 추천·두 목적 질문만 섞을 수 있다 → 앱이 뺀다 ──
    if (!f.allowMixed) {
      final first = blocks.allCards.firstOrNull;
      final want = f.expectedCardKind ?? (first == null ? null : AnswerFacts.cardKindOf(first.ref));
      if (want != null) {
        blocks = [
          for (final b in blocks)
            if (b.type != BlockType.cards)
              b
            else
              b.copyWith(cards: [
                for (final c in b.cards)
                  if (AnswerFacts.cardKindOf(c.ref) == want)
                    c
                  else
                    ...() {
                      fixed.add('K7 질문 목적과 다른 카드 뺌: ${c.title}');
                      return const <BlockCard>[];
                    }(),
              ]),
        ].where((b) => b.type != BlockType.cards || b.cards.isNotEmpty).toList();
      }
    }

    // ── K1 조건 충족 + 카드 id가 결과에 있는지 ──
    blocks = [
      for (final b in blocks)
        if (b.type != BlockType.cards)
          b
        else
          () {
            final keep = <BlockCard>[];
            for (final c in b.cards) {
              final item = f.byId(c.ref);
              if (item == null) {
                fixed.add('K1 결과에 없는 카드 뺌: ${c.title}');
                continue;
              }
              final why = violates(item, f.scope, f.kind);
              if (why != null) {
                fixed.add('K1 조건에 안 맞아 뺌: ${item.name} ($why)');
                continue;
              }
              keep.add(c);
            }
            return b.copyWith(cards: keep);
          }(),
    ].where((b) => b.type != BlockType.cards || b.cards.isNotEmpty).toList();

    // ── K4 빈 값 안내: 값이 빈 카드에는 주황 배지 + 문의처 ──
    blocks = [
      for (final b in blocks)
        if (b.type != BlockType.cards)
          b
        else
          b.copyWith(cards: [
            for (final c in b.cards)
              () {
                final item = f.byId(c.ref)!;
                if (item.empty.isEmpty || (c.contact != null && c.badge != null)) return c;
                fixed.add('K4 빈 값(${item.empty.join('·')}) 문의처 붙임: ${item.name}');
                return BlockCard(
                  ref: c.ref,
                  title: c.title,
                  badge: c.badge ?? item.badge,
                  values: c.values,
                  reason: c.reason,
                  contact: c.contact ?? item.contact,
                );
              }(),
          ]),
    ];

    // ── K2 숫자 출처 ──
    final ground = numbers(f.groundText);
    void checkNums(String where, String? s) {
      if (s == null) return;
      final extra = numbers(s).difference(ground);
      if (extra.isNotEmpty) issues.add(CheckIssue('K2', '$where에 조회 결과에 없는 숫자 ${extra.join(', ')}'));
    }

    for (final b in blocks) {
      switch (b.type) {
        case BlockType.headline:
        case BlockType.ask:
          checkNums('제목', b.title);
        case BlockType.text:
          checkNums('설명', b.text);
        case BlockType.cards:
          for (final c in b.cards) {
            checkNums('카드 이유', c.reason);
          }
        case BlockType.steps:
          for (final s in b.items) {
            checkNums('단계', s);
          }
        case BlockType.next:
          // 앱이 만든 칩('71곳 더 보기', '세종 10곳')은 앱 값이므로 Gemini가 새로 만든 칩만 본다
          for (final s in b.items.where((x) => !f.options.any((o) => o.label == x))) {
            checkNums('칩', s);
          }
        default:
          break;
      }
    }

    // ── K3 직전 답과 같은지 ──
    final prev = f.previous;
    if (prev != null && prev.question.trim() != f.question.trim()) {
      final ids = [for (final c in blocks.allCards) c.ref.split(':').last];
      final sameIds = ids.isNotEmpty && ids.length == prev.ids.length && ids.every(prev.ids.contains);
      final head = blocks.headline ?? '';
      if (sameIds && head == prev.headline) {
        // 제목·카드는 앱 값이라 다시 써도 같다 → 앱이 제목 바로 뒤에 "결과가 같다" 문장을 넣는다 (다시 쓰기 없음)
        const same = AnswerBlock(BlockType.text, text: '조건을 바꿔도 앞과 같은 결과예요.');
        final at = blocks.indexWhere((b) => b.type == BlockType.headline) + 1;
        blocks = [
          ...blocks.take(at),
          same,
          ...blocks.skip(at).where((b) => b.type != BlockType.text),
        ];
        fixed.add('K3 앞 답과 결과가 같아 안내 문장을 넣음');
      }
    }

    // ── K6 제목 건수 = 앱이 센 값 · K8 찾은 범위가 제목에 ──
    issues.addAll(headlineChecks(blocks, f));

    // ── K5 형식 ──
    if (strictFormat) issues.addAll(format(blocks, f));

    return CheckResult(blocks, issues, fixed);
  }

  /// K6·K8: 제목의 건수와 범위를 앱 값과 맞춰 본다
  static List<CheckIssue> headlineChecks(List<AnswerBlock> blocks, AnswerFacts f) {
    final head = blocks.firstOf(BlockType.headline);
    if (head == null) return const [];
    final title = head.title ?? '';
    final out = <CheckIssue>[];
    // K6: 'N곳·N건·N개' 숫자는 앱이 센 건수거나 앱 제목에 있는 숫자여야 한다
    final allowed = {...f.appCounts.map((n) => '$n'), ...numbers(f.hint?.headline ?? '')};
    for (final m in RegExp(r'(\d+)\s*(곳|건|개)(?!월)').allMatches(title.replaceAll(',', ''))) {
      if (!allowed.contains(m[1])) out.add(CheckIssue('K6', '제목 건수 ${m[1]}${m[2]}가 앱이 센 값(${f.count})과 다름'));
    }
    // K8: 예식장 목록·날짜 답은 찾은 범위(구 또는 시도)가 제목에 나와야 한다 (결과가 있을 때)
    final s = f.scope;
    if ((f.kind == AnswerKind.venueList || f.kind == AnswerKind.venueDate) && s != null && f.count > 0 && f.templateOnly == null) {
      String stem(String x) => x.length > 2 ? x.replaceAll(RegExp(r'(구|시|군)$'), '') : x;
      final places = s.towns.isNotEmpty ? s.towns : s.sidos;
      if (places.isNotEmpty && !places.any((p) => title.contains(stem(p)))) {
        out.add(CheckIssue('K8', '제목에 찾은 범위(${places.join('·')})가 없음'));
      }
    }
    return out;
  }

  /// K1: 이 결과가 조건을 어기는지 (어기면 이유, 아니면 null). 하객 수는 배지로 보여 주므로 빼지 않는다
  static String? violates(FactItem item, QueryScope? s, AnswerKind kind) {
    final v = item.venue;
    if (v == null || s == null) return null;
    if (kind == AnswerKind.venueDetail || kind == AnswerKind.venueCompare) return null; // 이름으로 고른 곳
    if (s.towns.isNotEmpty && !s.towns.contains(v.sigungu)) return '고른 구 밖';
    if (s.towns.isEmpty && s.sidos.isNotEmpty && !s.sidos.any((sd) => sidoMatches(v.sido, sd))) return '고른 시도 밖';
    String stem(String x) => x.replaceAll(RegExp(r'(구|시|군)$'), '');
    if (s.excludeTowns.any((t) => v.sigungu.startsWith(stem(t)))) return '뺀 구';
    if (s.freeOnly && v.rentalFee != 0) return '무료 아님';
    if (s.maxFee != null && (v.rentalFee == null || v.rentalFee! > s.maxFee!)) return '대관료 상한 초과';
    if (s.date != null && kind == AnswerKind.venueDate && item.badge?.tone == Tone.no) {
      // 날짜 질문: 그날 안 되는 곳은 후보로 보여 주지 않는다
      return '그날 안 됨';
    }
    return null;
  }

  /// K5: 형식 규칙
  static List<CheckIssue> format(List<AnswerBlock> blocks, AnswerFacts f) {
    final out = <CheckIssue>[];
    if (blocks.isEmpty) return const [CheckIssue('K5', '블록 없음')];
    final firstType = blocks.first.type;
    if (firstType != BlockType.headline && firstType != BlockType.ask) {
      out.add(const CheckIssue('K5', '첫 블록은 headline 또는 ask (F1)'));
    }
    final head = blocks.firstOf(BlockType.headline) ?? blocks.firstOf(BlockType.ask);
    final title = head?.title ?? '';
    if (title.trim().isEmpty) out.add(const CheckIssue('K5', '제목 없음'));
    final tMax = head?.type == BlockType.ask ? askMax : titleMax;
    if (title.length > tMax) out.add(CheckIssue('K5', '제목 ${title.length}자 > $tMax자 (F1)'));
    if ((head?.badges.length ?? 0) > 2) out.add(const CheckIssue('K5', '배지 3개 이상'));
    var sentenceCount = 0;
    for (final b in blocks.where((b) => b.type == BlockType.text)) {
      final t = b.text ?? '';
      sentenceCount += sentences(t);
      if (t.length > textMax) out.add(CheckIssue('K5', '설명 ${t.length}자 > $textMax자 (F3)'));
      if (RegExp(r'(하고|이며|이고),').hasMatch(t)) out.add(const CheckIssue('K5', '설명을 "~하고,"로 이음 (F3)'));
    }
    if (sentenceCount > 1) out.add(CheckIssue('K5', '설명 $sentenceCount문장 > 1문장 (F2)'));
    final cards = blocks.allCards;
    final maxCards = f.cardLimit ?? 3;
    if (cards.length > maxCards) out.add(CheckIssue('K5', '카드 ${cards.length}개 > $maxCards개 (F5)'));
    for (final (i, c) in cards.indexed) {
      if (c.reason == null) continue;
      if (i > 0) out.add(const CheckIssue('K5', '이유는 첫 카드에만'));
      if (c.reason!.length > reasonMax) out.add(CheckIssue('K5', '카드 이유 ${c.reason!.length}자 > $reasonMax자'));
    }
    final next = blocks.firstOf(BlockType.next);
    if (next != null) {
      if (next.items.length > chipCount) out.add(CheckIssue('K5', '칩 ${next.items.length}개 > $chipCount개 (F7)'));
      for (final c in next.items) {
        if (c.length > chipMax) out.add(CheckIssue('K5', '칩 "$c" ${c.length}자 > $chipMax자 (F7)'));
      }
      // 카드에 이미 나온 이름을 칩으로 반복하지 않기 (F7)
      for (final c in next.items) {
        if (cards.any((k) => k.title == c)) out.add(CheckIssue('K5', '칩 "$c"가 카드와 같음 (F7)'));
      }
    }
    for (final s in blocks.where((b) => b.type == BlockType.steps).expand((b) => b.items)) {
      if (s.length > stepMax) out.add(CheckIssue('K5', '단계 "$s" ${s.length}자 > $stepMax자'));
    }
    // F14: 제목의 숫자를 설명·카드 이유에서 다시 쓰지 않기
    final headNums = numbers(title).where((n) => n.length >= 1 && n != '0').toSet();
    if (headNums.isNotEmpty) {
      final body = [
        for (final b in blocks.where((b) => b.type == BlockType.text)) b.text ?? '',
        for (final c in cards) c.reason ?? '',
      ].join(' ');
      final rep = numbers(body).intersection(headNums);
      // '120명'처럼 조건 숫자는 반복될 수 있어 제목의 '건수'만 본다: 제목 숫자 뒤가 곳·건·개일 때
      final counts = RegExp(r'(\d+)\s*(곳|건|개)(?!월)').allMatches(title).map((m) => m[1]!).toSet();
      final bad = rep.intersection(counts);
      if (bad.isNotEmpty) out.add(CheckIssue('K5', '제목 건수 ${bad.join(', ')}를 설명에서 반복 (F14)'));
    }
    // 허용 블록만 (BlockType으로 이미 제한). 같은 종류 반복은 headline·fold만 금지
    for (final t in [BlockType.headline, BlockType.fold, BlockType.next, BlockType.filters]) {
      if (blocks.where((b) => b.type == t).length > 1) out.add(CheckIssue('K5', '${t.name} 블록이 두 번'));
    }
    if (blocks.firstOf(BlockType.ask) != null && blocks.firstOf(BlockType.headline) != null) {
      out.add(const CheckIssue('K5', 'ask와 headline을 함께 씀'));
    }
    return out;
  }
}

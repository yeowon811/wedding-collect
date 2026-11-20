import '../agent/date_check.dart';
import 'answer_blocks.dart';
import 'answer_facts.dart';

/// 기본 틀 (R14): Gemini가 없거나 실패·검사 탈락이면 앱이 같은 블록을 정해진 문형으로 채운다.
/// headline → (text) → filters → cards/표/단계 → next → fold
class AnswerTemplate {
  static const maxCards = 3;
  static const maxChips = 4;

  /// 종류별 기본 제목 배지 우선순위
  static const badgeOrder = {
    AnswerKind.venueList: ['all_free', 'free_count', 'fit_count', 'no_info_count'],
    AnswerKind.venueDate: ['all_free', 'fit_count'], // 빈 곳 수는 제목이 말함
    AnswerKind.venueDetail: <String>[],
    AnswerKind.venueCompare: ['all_free'],
    AnswerKind.policyList: ['likely_count', 'check_count'],
    AnswerKind.vendorList: ['in_budget_count', 'demo'],
  };

  /// 앱이 정한 제목 (범위·건수는 항상 앱 값). 답 함수 힌트가 있으면 그것, 없으면 기본 문형
  static String appHeadline(AnswerFacts f) => f.hint?.headline ?? defaultHeadline(f);

  /// 제목을 앱만 쓰는 답 (건수·금액·날짜가 답인 것). 나머지(비교·상세·일반 안내)는 Gemini가 숫자 없는 제목을 쓸 수 있다
  static bool appOwnsTitle(AnswerFacts f) =>
      const {
        AnswerKind.venueList,
        AnswerKind.venueDate,
        AnswerKind.policyList,
        AnswerKind.vendorList,
        AnswerKind.calc,
        AnswerKind.cost,
        AnswerKind.budget,
        AnswerKind.schedule,
        AnswerKind.ask,
      }.contains(f.kind) ||
      f.templateOnly != null;

  static List<AnswerBlock> build(AnswerFacts f) {
    final h = f.hint;
    final title = appHeadline(f);
    final badges = h != null && h.headBadges.isNotEmpty
        ? h.headBadges.take(2).toList()
        : [for (final k in badgeOrder[f.kind] ?? const <String>[]) if (f.headBadges[k] case final b?) b].take(2).toList();
    final sentence = h?.sentence ?? (h?.headline == null && f.kind != AnswerKind.ask ? _secondSentence(f) : null);
    final list = _showsCards(f) ? cardItems(f).take(f.cardLimit ?? maxCards).toList() : const <FactItem>[];
    return [
      if (f.kind == AnswerKind.ask)
        AnswerBlock(BlockType.ask, title: title, items: [for (final o in f.options.take(maxChips)) o.label])
      else
        AnswerBlock(BlockType.headline, title: title, badges: badges),
      if (sentence != null && sentence.isNotEmpty) AnswerBlock(BlockType.text, text: sentence),
      if (filtersOf(f) case final fl when fl.isNotEmpty) AnswerBlock(BlockType.filters, filters: fl),
      if (list.isNotEmpty) AnswerBlock(BlockType.cards, cards: [for (final i in list) i.toCard()]),
      if (h != null && h.rows.isNotEmpty) AnswerBlock(BlockType.table, columns: h.columns, rows: h.rows.take(6).toList()),
      if (h != null && h.ranking.isNotEmpty) AnswerBlock(BlockType.ranking, items: h.ranking.take(3).toList()),
      if (h != null && h.steps.isNotEmpty) AnswerBlock(BlockType.steps, items: h.steps.take(4).toList()),
      if (h != null && h.budgetRows.isNotEmpty) AnswerBlock(BlockType.budget, rows: h.budgetRows, title: h.budgetTotal),
      if (h != null && h.web.isNotEmpty) AnswerBlock(BlockType.web, web: h.web, searchQueries: h.searchQueries),
      if (f.kind != AnswerKind.ask && f.options.isNotEmpty)
        AnswerBlock(BlockType.next, items: [for (final o in pickOptions(f.options)) o.label]),
      foldOf(f),
    ];
  }

  static bool _showsCards(AnswerFacts f) => f.items.isNotEmpty && f.kind != AnswerKind.venueCompare;

  /// 앱이 카드와 순서를 정하는 답 (목록·날짜·기간·정책·업체). 비교·상세는 Gemini가 고른다 (7차)
  static bool appPicksCards(AnswerFacts f) => const {
        AnswerKind.venueList,
        AnswerKind.venueDate,
        AnswerKind.policyList,
        AnswerKind.vendorList,
      }.contains(f.kind);

  /// 카드로 보여 줄 결과: 질문 목적과 같은 종류만 (K7). 전체 추천·두 목적 질문만 섞을 수 있다
  static List<FactItem> cardItems(AnswerFacts f) {
    final pins = [for (final r in f.pinned) if (f.byId(r) case final it?) it];
    final ordered = [...pins, ...f.items.where((i) => !pins.contains(i))];
    if (f.allowMixed || ordered.isEmpty) return ordered;
    final want = f.expectedCardKind ?? AnswerFacts.cardKindOf(ordered.first.ref);
    return [for (final i in ordered) if (AnswerFacts.cardKindOf(i.ref) == want) i];
  }

  /// 꼭 넣는 칩 (앱이 항상 붙임): 넓히기 최대 2개 + 더 보기
  static List<NextOption> mandatoryOptions(List<NextOption> all) => [
        ...all.where((o) => o.kind == 'widen').take(2),
        ...all.where((o) => o.kind == 'more').take(1),
      ];

  /// 다음 칩 고르기: 꼭 넣는 칩 먼저 → 좁히기 → 나머지 (최대 4)
  static List<NextOption> pickOptions(List<NextOption> all) {
    const order = ['narrow', 'next', 'action', 'widen', 'more'];
    final rest = [...all]..sort((a, b) => order.indexOf(a.kind).compareTo(order.indexOf(b.kind)));
    final seen = <String>{};
    return [for (final o in [...mandatoryOptions(all), ...rest]) if (seen.add(o.label)) o].take(maxChips).toList();
  }

  /// 칩 이름 합치기: 꼭 넣는 칩 먼저, 그다음 Gemini가 고른 칩 (최대 4, 겹치면 한 번)
  static List<String> mergeChips(AnswerFacts f, List<String> chosen) {
    final seen = <String>{};
    return [
      for (final l in [for (final o in mandatoryOptions(f.options)) o.label, ...chosen])
        if (seen.add(l)) l,
    ].take(maxChips).toList();
  }

  static AnswerBlock foldOf(AnswerFacts f, {List<String> extraLog = const []}) => AnswerBlock(
        BlockType.fold,
        sources: f.sources,
        log: [...f.log, ...extraLog],
        detail: f.detail.trim().isEmpty ? null : f.detail.trim(),
      );

  /// 적용된 조건 칩 (✕ = 그 조건 빼고 다시 찾기)
  static List<FilterChipData> filtersOf(AnswerFacts f) {
    final s = f.scope;
    if (s == null || !f.kind.isVenue || f.kind == AnswerKind.venueDetail || f.kind == AnswerKind.venueCompare) return const [];
    return [
      if (s.towns.isEmpty)
        for (final sd in s.sidos) FilterChipData(sd),
      for (final t in s.towns)
        s.towns.length > 1
            ? FilterChipData(t, set: {'sigungu': [for (final o in s.towns) if (o != t) o]})
            : FilterChipData(t, remove: 'sigungu'),
      for (final t in s.excludeTowns) FilterChipData('$t 제외', remove: 'exclude_sigungu'),
      if (s.freeOnly) const FilterChipData('무료만', remove: 'free_only'),
      if (s.maxFee != null) FilterChipData('${_manwon(s.maxFee!)} 이하', remove: 'max_fee_won'),
      if (s.guests != null) FilterChipData('하객 ${s.guests}명', remove: 'guests'),
      if (s.date != null) FilterChipData(md(s.date!), remove: 'date'),
      if (s.date == null && s.periodLabel != null) FilterChipData(s.periodLabel!, remove: 'date'),
      for (final n in s.needs) FilterChipData(const {'parking': '주차', 'reception': '피로연', 'outdoor': '야외'}[n] ?? n, remove: 'needs'),
      if (s.sortLabel != null) FilterChipData(s.sortLabel!, remove: 'sort'),
    ];
  }

  static String _manwon(int won) => won % 10000 == 0 ? '${won ~/ 10000}만원' : '${(won / 10000).toStringAsFixed(1)}만원';

  /// 기본 제목 문형 (H5)
  static String defaultHeadline(AnswerFacts f) {
    final s = f.scope;
    final place = s?.placeLabel ?? '';
    final n = f.count;
    switch (f.kind) {
      case AnswerKind.venueList:
        if (n == 0) {
          final narrowed = s != null && (s.freeOnly || s.maxFee != null || s.needs.isNotEmpty || s.excludeTowns.isNotEmpty || s.guests != null);
          return narrowed || place.isEmpty ? '조건에 맞는 곳이 없어요' : '$place에는 공공예식장이 없어요';
        }
        return '${place.isEmpty ? '' : '$place '}${s?.freeOnly == true ? '무료 ' : ''}공공예식장 $n곳';
      case AnswerKind.venueDate:
        final d = s?.date;
        final open = f.items.where((i) => i.badge?.tone == Tone.good).length;
        final at = place.isEmpty ? '' : '$place ';
        if (d == null) return '$at예약 현황';
        return open == 0 ? '$at${dateLabel(d)} 빈 곳이 없어요' : '$at${dateLabel(d)} 빈 곳 $open곳';
      case AnswerKind.venueDetail:
        return shortName(f.items.firstOrNull?.name ?? '예식장 정보');
      case AnswerKind.venueCompare:
        return '예식장 ${f.items.length}곳 비교';
      case AnswerKind.policyList:
        return n == 0 ? '찾은 정책이 없어요' : '받을 수 있는 정책 $n건';
      case AnswerKind.policyDetail:
        return shortName(f.items.firstOrNull?.name ?? '정책 정보');
      case AnswerKind.vendorList:
        return n == 0 ? '찾은 업체가 없어요' : '업체 $n곳';
      default:
        final first = _firstSentence(f.detail);
        if (first != null && first.length <= 28) return first;
        return switch (f.kind) {
          AnswerKind.calc => '계산 결과',
          AnswerKind.cost => '비용 참고',
          AnswerKind.schedule => '준비 순서',
          AnswerKind.budget => '내 예산 현황',
          AnswerKind.general => '일반 안내',
          _ => '답변',
        };
    }
  }

  /// 제목용 이름: 괄호 설명을 떼고 24자 안으로
  static String shortName(String name) {
    final n = name.length <= 24 ? name : name.split('(').first.trim();
    return n.length <= 24 ? n : '${n.substring(0, 23)}…';
  }

  static String? _firstSentence(String text) {
    final line = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty && !l.startsWith('•'), orElse: () => '');
    if (line.isEmpty) return null;
    final m = RegExp(r'^.+?(요|다|니다)[.!?]').firstMatch(line);
    return (m?.group(0) ?? line).trim();
  }

  /// 제목만으로 부족할 때 붙이는 한 문장: 예전 글의 두 번째 문장 또는 첫 줄(제목이 기본 문형일 때)
  static String? _secondSentence(AnswerFacts f) {
    if (f.kind.isVenue || f.kind == AnswerKind.policyList || f.kind == AnswerKind.vendorList) return null;
    final first = _firstSentence(f.detail);
    if (first == null) return null;
    final title = defaultHeadline(f);
    if (title == first) {
      // 다음 줄(글머리 포함) 하나
      final lines = f.detail.split('\n').map((l) => l.trim().replaceFirst(RegExp(r'^•\s*'), '')).where((l) => l.isNotEmpty).toList();
      final i = lines.indexWhere((l) => l.startsWith(first));
      final next = i >= 0 && i + 1 < lines.length ? lines[i + 1] : null;
      return next == null ? null : _cut(_firstSentence(next) ?? next, 60);
    }
    return _cut(first, 60);
  }

  static String _cut(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';
}

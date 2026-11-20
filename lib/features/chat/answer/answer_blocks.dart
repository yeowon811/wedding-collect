/// AI 상담 답변 블록 (docs/ai-design/answer_design_blaze.md 2장, 형식 규칙 F1~F14).
///
/// 답은 글 대신 정해 둔 블록의 목록이다. Gemini는 이 목록에서만 골라 배치하고(F11),
/// 카드 값·배지 숫자·조건 칩·출처는 앱이 데이터로 채운다. 저장(계정)과 다시 열기를 위해 JSON으로 바꿀 수 있다.
library;

/// 블록 종류 (허용 목록)
enum BlockType {
  headline, // 굵은 답 한 줄 + 배지 0~2개
  text, // 설명 한 문장
  filters, // 적용된 조건 칩 (✕로 빼기, + 조건)
  cards, // 카드 최대 3개 (이름 + 맞는지 배지 / 핵심 값 3개)
  table, // 비교표 (행 최대 5)
  ranking, // 순위 3개
  steps, // 단계 최대 4개
  budget, // 금액 표·합계
  ask, // 되묻기 한 문장 + 선택 칩
  web, // 웹에서 찾은 값 + 출처 링크
  next, // 다음 행동 칩 최대 4개
  fold, // 접힌 한 줄: 출처 보기 · 어떻게 찾았나요
  notice; // 앱 전용 알림 줄 ("내 정보에 반영: …"). Gemini는 고르지 않는다

  static BlockType? byName(Object? n) => BlockType.values.where((t) => t.name == n).firstOrNull;

  /// Gemini가 고를 수 있는 블록 (F11)
  static const aiAllowed = [headline, text, cards, table, ranking, steps, budget, ask, web, next];
}

/// 배지 색: 초록 맞음 · 주황 확인 필요 · 회색 맞지 않음 · 파랑 일반 강조
enum Tone {
  good,
  check,
  no,
  info;

  static Tone byName(Object? n) => Tone.values.where((t) => t.name == n).firstOrNull ?? Tone.info;
}

class BlockBadge {
  const BlockBadge(this.text, [this.tone = Tone.info]);

  final String text;
  final Tone tone;

  Map<String, Object?> toJson() => {'t': text, 'c': tone.name};
  static BlockBadge fromJson(Map m) => BlockBadge(m['t'] as String? ?? '', Tone.byName(m['c']));

  @override
  bool operator ==(Object other) => other is BlockBadge && other.text == text && other.tone == tone;
  @override
  int get hashCode => Object.hash(text, tone);
}

/// 카드 한 장: 1줄 이름 + 배지 / 2줄 핵심 값(순서 고정) / 첫 카드만 짧은 이유 / 빈 값이면 문의처
class BlockCard {
  const BlockCard({
    required this.ref,
    required this.title,
    this.badge,
    this.values = const [],
    this.reason,
    this.contact,
  });

  final String ref; // 'venue:H078' 등 (누르면 상세)
  final String title;
  final BlockBadge? badge;
  final List<String> values;
  final String? reason; // 15자 안팎 (첫 카드만)
  final String? contact; // 빈 값 안내용 문의처 (☎ …)

  BlockCard copyWith({String? reason, bool clearReason = false}) => BlockCard(
        ref: ref,
        title: title,
        badge: badge,
        values: values,
        reason: clearReason ? null : (reason ?? this.reason),
        contact: contact,
      );

  Map<String, Object?> toJson() => {
        'ref': ref,
        'title': title,
        if (badge != null) 'badge': badge!.toJson(),
        if (values.isNotEmpty) 'values': values,
        if (reason != null) 'reason': reason,
        if (contact != null) 'contact': contact,
      };

  static BlockCard fromJson(Map m) => BlockCard(
        ref: m['ref'] as String? ?? '',
        title: m['title'] as String? ?? '',
        badge: m['badge'] is Map ? BlockBadge.fromJson(m['badge'] as Map) : null,
        values: ((m['values'] as List?) ?? const []).cast<String>(),
        reason: m['reason'] as String?,
        contact: m['contact'] as String?,
      );
}

/// 조건 칩 하나 (✕를 누르면 그 조건을 빼고 다시 찾는다)
class FilterChipData {
  const FilterChipData(this.label, {this.remove, this.set});

  final String label;
  final String? remove; // 뺄 도구 조건 이름 (sigungu, free_only …)
  final Map<String, Object?>? set; // 빼는 대신 바꿀 값 (구 여러 개 중 하나만 뺄 때)

  Map<String, Object?> toJson() => {'l': label, if (remove != null) 'r': remove, if (set != null) 's': set};
  static FilterChipData fromJson(Map m) =>
      FilterChipData(m['l'] as String? ?? '', remove: m['r'] as String?, set: (m['s'] as Map?)?.cast<String, Object?>());
}

/// 웹에서 찾은 값 한 줄 + 출처
class WebItem {
  const WebItem({required this.text, this.url, this.source});

  final String text;
  final String? url;
  final String? source; // 사이트 이름·도메인

  Map<String, Object?> toJson() => {'t': text, if (url != null) 'u': url, if (source != null) 's': source};
  static WebItem fromJson(Map m) => WebItem(text: m['t'] as String? ?? '', url: m['u'] as String?, source: m['s'] as String?);
}

/// 블록 하나. 종류마다 쓰는 칸만 채운다.
class AnswerBlock {
  const AnswerBlock(
    this.type, {
    this.title,
    this.text,
    this.badges = const [],
    this.cards = const [],
    this.filters = const [],
    this.columns = const [],
    this.rows = const [],
    this.items = const [],
    this.web = const [],
    this.searchQueries = const [],
    this.sources = const [],
    this.log = const [],
    this.detail,
  });

  final BlockType type;
  final String? title; // headline 제목 · ask 질문 · budget 합계 줄
  final String? text; // text 한 문장
  final List<BlockBadge> badges; // headline 배지
  final List<BlockCard> cards; // cards
  final List<FilterChipData> filters; // filters
  final List<String> columns; // table 머리 (첫 칸은 항목 이름)
  final List<List<String>> rows; // table·budget 행 (첫 칸은 항목 이름)
  final List<String> items; // ranking·steps 줄, next·ask 칩 이름
  final List<WebItem> web; // web
  final List<String> searchQueries; // web: Google 검색 제안 (이용 조건상 화면에 표시)
  final List<String> sources; // fold: 출처
  final List<String> log; // fold: 어떻게 찾았나요 (검사 기록 포함)
  final String? detail; // fold: 자세한 설명 (예전 긴 글, 접어서 보관)

  Map<String, Object?> toJson() => {
        'type': type.name,
        if (title != null) 'title': title,
        if (text != null) 'text': text,
        if (badges.isNotEmpty) 'badges': [for (final b in badges) b.toJson()],
        if (cards.isNotEmpty) 'cards': [for (final c in cards) c.toJson()],
        if (filters.isNotEmpty) 'filters': [for (final f in filters) f.toJson()],
        if (columns.isNotEmpty) 'columns': columns,
        if (rows.isNotEmpty) 'rows': rows,
        if (items.isNotEmpty) 'items': items,
        if (web.isNotEmpty) 'web': [for (final w in web) w.toJson()],
        if (searchQueries.isNotEmpty) 'search': searchQueries,
        if (sources.isNotEmpty) 'sources': sources,
        if (log.isNotEmpty) 'log': log,
        if (detail != null) 'detail': detail,
      };

  static AnswerBlock? fromJson(Map m) {
    final type = BlockType.byName(m['type']);
    if (type == null) return null;
    List<T> list<T>(String k, T Function(Map) f) => [for (final x in ((m[k] as List?) ?? const []).whereType<Map>()) f(x)];
    List<String> strs(String k) => [for (final x in ((m[k] as List?) ?? const [])) if (x is String) x];
    return AnswerBlock(
      type,
      title: m['title'] as String?,
      text: m['text'] as String?,
      badges: list('badges', BlockBadge.fromJson),
      cards: list('cards', BlockCard.fromJson),
      filters: list('filters', FilterChipData.fromJson),
      columns: strs('columns'),
      rows: [for (final r in ((m['rows'] as List?) ?? const []).whereType<List>()) [for (final x in r) '$x']],
      items: strs('items'),
      web: list('web', WebItem.fromJson),
      searchQueries: strs('search'),
      sources: strs('sources'),
      log: strs('log'),
      detail: m['detail'] as String?,
    );
  }

  AnswerBlock copyWith({
    String? title,
    String? text,
    List<BlockBadge>? badges,
    List<BlockCard>? cards,
    List<String>? items,
    List<String>? log,
    List<String>? sources,
  }) =>
      AnswerBlock(
        type,
        title: title ?? this.title,
        text: text ?? this.text,
        badges: badges ?? this.badges,
        cards: cards ?? this.cards,
        filters: filters,
        columns: columns,
        rows: rows,
        items: items ?? this.items,
        web: web,
        searchQueries: searchQueries,
        sources: sources ?? this.sources,
        log: log ?? this.log,
        detail: detail,
      );
}

/// 블록 목록 도우미
extension AnswerBlocksX on List<AnswerBlock> {
  AnswerBlock? firstOf(BlockType t) => where((b) => b.type == t).firstOrNull;

  List<BlockCard> get allCards => [for (final b in this) ...b.cards];

  String? get headline => firstOf(BlockType.headline)?.title ?? firstOf(BlockType.ask)?.title;

  /// 복사용 글 (답 복사 버튼, 2026-11-20): 제목(배지) → 설명 → 카드 "이름 — 값 · 값 (배지) · 이유" → 표 → 단계 → 예산 → 웹 → 출처.
  /// 칩·버튼·조건 칩·접힌 기록은 넣지 않는다
  String get copyText {
    final out = <String>[];
    var sources = <String>[];
    for (final b in this) {
      switch (b.type) {
        case BlockType.headline:
        case BlockType.ask:
          final badges = b.badges.map((x) => x.text).join(' · ');
          out.add('${b.title ?? ''}${badges.isEmpty ? '' : ' ($badges)'}');
        case BlockType.text:
        case BlockType.notice:
          if ((b.text ?? '').trim().isNotEmpty) out.add(b.text!.trim());
        case BlockType.cards:
          for (final c in b.cards) {
            out.add([
              c.values.isEmpty ? c.title : '${c.title} — ${c.values.join(' · ')}',
              if (c.badge != null) '(${c.badge!.text})',
              if (c.reason != null) '· ${c.reason}',
              if (c.contact != null) '· 문의 ${c.contact}',
            ].join(' '));
          }
        case BlockType.table:
          if (b.columns.isNotEmpty) out.add(b.columns.where((x) => x.isNotEmpty).join(' | '));
          for (final r in b.rows) {
            out.add(r.length > 1 ? '${r.first}: ${r.skip(1).join(' | ')}' : r.join(''));
          }
        case BlockType.ranking:
        case BlockType.steps:
          for (final (i, x) in b.items.indexed) {
            out.add('${i + 1}. $x');
          }
        case BlockType.budget:
          for (final r in b.rows) {
            out.add(r.join(' '));
          }
          if (b.title != null) out.add(b.title!);
        case BlockType.web:
          for (final w in b.web) {
            out.add('${w.text}${w.url == null ? '' : ' (${w.source ?? w.url})'}');
          }
        case BlockType.fold:
          sources = b.sources;
        case BlockType.filters:
        case BlockType.next:
          break;
      }
    }
    if (sources.isNotEmpty) out.add('출처: ${sources.join(' · ')}');
    return out.where((l) => l.trim().isNotEmpty).join('\n');
  }

  /// 사람이 읽는 글로 (대화 기억·평가·검토용). 접힌 칸(fold)과 칩은 넣지 않는다
  String get plainText {
    final out = <String>[];
    for (final b in this) {
      switch (b.type) {
        case BlockType.headline:
          out.add([b.title ?? '', if (b.badges.isNotEmpty) '(${b.badges.map((x) => x.text).join(' · ')})'].join(' '));
        case BlockType.ask:
          out.add(b.title ?? '');
        case BlockType.text:
          out.add(b.text ?? '');
        case BlockType.filters:
          if (b.filters.isNotEmpty) out.add('조건: ${b.filters.map((f) => f.label).join(' · ')}');
        case BlockType.cards:
          for (final c in b.cards) {
            out.add('• ${c.title}${c.badge == null ? '' : ' [${c.badge!.text}]'}'
                '${c.values.isEmpty ? '' : ' — ${c.values.join(' · ')}'}'
                '${c.reason == null ? '' : ' (${c.reason})'}'
                '${c.contact == null ? '' : ' ${c.contact}'}');
          }
        case BlockType.table:
          out.add(b.columns.join(' | '));
          for (final r in b.rows) {
            out.add(r.join(' | '));
          }
        case BlockType.ranking:
          for (final (i, x) in b.items.indexed) {
            out.add('${i + 1}. $x');
          }
        case BlockType.steps:
          out.add(b.items.join(' → '));
        case BlockType.budget:
          for (final r in b.rows) {
            out.add(r.join(' '));
          }
          if (b.title != null) out.add(b.title!);
        case BlockType.web:
          for (final w in b.web) {
            out.add('${w.text}${w.source == null ? '' : ' (출처 ${w.source})'}');
          }
        case BlockType.notice:
          out.add(b.text ?? '');
        case BlockType.next:
        case BlockType.fold:
          break;
      }
    }
    return out.where((l) => l.trim().isNotEmpty).join('\n');
  }
}

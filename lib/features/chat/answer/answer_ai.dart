import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../../../core/utils/korean.dart';
import '../chat_agent.dart';
import 'answer_blocks.dart';
import 'answer_facts.dart';
import 'answer_template.dart';

/// Gemini 답 작성(④)과 검토(⑤ 나)의 지시문·형식, 그리고 Gemini JSON → 블록 변환.
/// Gemini는 블록 종류·순서·제목·한 문장·카드 이유·칩만 정하고, 값은 앱이 [AnswerFacts]에서 채운다.
class AnswerAi {
  // ───────────────────────── ④ 답 작성 ─────────────────────────

  /// 설명 글 제한을 풀지 (2026-11-20 동료 요청: "제한 없이 풀어서 결과를 보자"). false면 7차까지의 짧은 형식(F2·F3·F14)
  /// 바꾸면 Gemini 작성 모델을 다시 만들어야 하므로 앱 시작 전에 정한다
  static bool freeText = true;

  static String get writerPrompt => freeText ? freePrompt : limitedPrompt;

  /// 설명 글 제한 없음: 매 답에 자연스러운 설명(이유·주의·다음 할 일), 카드마다 이유 키
  static const freePrompt = '''
너는 결혼 준비 앱 AI 상담의 "답 쓰기" 단계다. 앱이 데이터에서 찾은 결과(facts)를 보고,
정해 둔 블록으로 화면을 JSON으로 만들고, 사용자에게 자연스러운 설명을 쓴다.

블록:
- headline: title_kind로 고른다.
  - "app": 앱이 범위·건수를 넣은 제목(facts.app_headline)을 그대로 쓴다. 목록·날짜·정책·업체·계산·비용·일정 답은 항상 app.
  - "custom": 비교·상세·일반 안내에서만 title을 직접 쓴다 (숫자 없이).
  badges는 badge_keys의 키만(0~2개).
- text: **항상 쓴다.** 상담사가 말하듯 사용자에게 하는 자연스러운 설명(해요체). 길이 제한 없음, 여러 문장·문단 가능.
  담을 것: 왜 이 결과인지(어떤 조건·범위·순서로 골랐는지), 주의할 점(정보 없음·확인 필요·예약 현황은 바뀔 수 있음 등),
  다음에 하면 좋은 일. 숫자·이름은 facts(items·notes·app_text·app_sentence)에 있는 것만 쓰고 지어내지 않는다.
- cards: 목록 답(facts.app_cards=true)은 앱이 카드와 순서를 정한다 (facts.items 앞에서부터). ids는 비운다.
  그 밖(비교·상세 등)은 ids에 facts.items의 id를 최대 3개.
  reason_keys: 카드마다(카드 순서대로) 그 item의 reasons에 있는 키 하나씩 (없으면 ""). 문장은 앱이 데이터로 쓴다.
  키 뜻: biggest 정원 가장 큼 · cheapest 대관료 가장 낮음 · free 무료 · fits 하객 수용 · parking 주차 · reception 피로연 ·
  outdoor 야외 · open_on_date 그날 빔 · likely 조건 잘 맞음 · max_amount 지원 금액 · in_budget 예산 안 · top_rating 평점 최고 · official 공식 업체
- table: 비교할 때. ids(2~5개) + fields(facts.items[].fields의 이름, 최대 5개).
- ranking: 순서가 답일 때(거리 등). ids 최대 3개.
- steps: 순서·절차. items 최대 4개.
- budget·web: facts.app_blocks에 있을 때만 (내용은 앱이 채움).
- ask: 답에 꼭 필요한 정보가 없을 때 되묻기. title + items 선택지 2~4개.
- next: options의 label 그대로 고르거나(넓히기·더 보기는 앱이 먼저 붙임), 12자 이내의 짧은 질문 칩을 1개까지 새로 만든다.

규칙:
- 첫 블록은 headline 또는 ask. 순서: headline → text → cards/table/ranking/steps/budget/web → next.
- 숫자·이름은 facts에 있는 것만. 제목의 건수·범위는 앱이 채운다.
- cards는 facts.items에 있는 종류만.
- 결과가 0건이면 그렇게 말하고 넓혀 볼 곳을 설명한다. 지어내지 않는다.
- facts.ai_general이 true면 앱 데이터가 아닌 일반 안내다: 일반적인 내용을 설명하고, 구체적인 금액·기관명은 만들지 않는다.
- 질문이 앞 답의 후속인데 결과가 같으면 설명에서 먼저 그렇게 말한다.
- fix가 주어지면 그 점을 고쳐 다시 만든다.

예시 (예식장 목록)
{"blocks":[{"type":"headline","title_kind":"app","badges":["all_free","fit_count"]},
{"type":"text","text":"사시는 강남구부터 찾았어요. 하객 수가 들어가는 곳을 먼저, 그다음 무료·정원 큰 순으로 놓았어요. 마루공원은 정원 정보가 없어 문의가 필요해요. 더 넓게 보려면 서초·송파까지 넓혀 보세요."},
{"type":"cards","reason_keys":["biggest","fits","free"]},
{"type":"next","items":["이 지역 지원 정책"]}]}
''';

  /// 짧은 형식 (7차까지): 설명은 꼭 필요할 때 한 문장
  static const limitedPrompt = '''
너는 결혼 준비 앱 AI 상담의 "답 화면 배치" 단계다. 앱이 데이터에서 찾은 결과(facts)를 보고,
정해 둔 블록 목록에서 골라 3초 안에 답이 보이는 화면을 JSON으로 만든다. 글은 최소로.

블록 (이것만 쓴다):
- headline: 질문에 대한 답 한 줄. title_kind로 고른다.
  - "app": 앱이 범위·건수를 넣은 제목(facts.app_headline)을 그대로 쓴다. 목록·날짜·정책·업체·계산·비용·일정 답은 항상 app.
  - "custom": 비교·상세·일반 안내에서만 title을 직접 쓴다 (20자 안팎, 숫자 없이, 해요체 또는 명사형).
  badges는 badge_keys의 키만(0~2개).
- text: 꼭 필요할 때만 설명 한 문장(40자 안팎). "~하고,"로 잇지 않는다.
- cards: 목록 답(facts.app_cards=true)은 앱이 카드와 순서를 정한다 (facts.items 앞에서부터). ids는 비우고 reason_key만:
  첫 번째 item의 reasons에 있는 키 하나 (문장은 앱이 데이터로 씀, 없으면 생략).
  그 밖(비교·상세 등)은 ids에 facts.items의 id를 최대 3개(관련도 순), reason_key는 첫 카드의 reasons 중 하나.
  키 뜻: biggest 정원 가장 큼 · cheapest 대관료 가장 낮음 · free 무료 · fits 하객 수용 · parking 주차 · reception 피로연 ·
  outdoor 야외 · open_on_date 그날 빔 · likely 조건 잘 맞음 · max_amount 지원 금액 · in_budget 예산 안 · top_rating 평점 최고 · official 공식 업체
- table: 비교할 때. ids(2~5개) + fields(facts.items[].fields의 이름, 최대 5개).
- ranking: 순서가 답일 때(거리·빈 날 많은 순). ids 최대 3개.
- steps: 순서·절차. items 최대 4개, 각 15자 안팎.
- budget: 금액 표가 facts에 있을 때만 (내용은 앱이 채움).
- ask: 답에 꼭 필요한 정보가 없을 때 되묻기. title 30자 이내, items 선택지 2~4개.
- web: facts에 web이 있을 때만 (내용은 앱이 채움).
- next: 고를 수 있는 칩은 options의 label 그대로 (넓히기·더 보기는 앱이 항상 먼저 붙이므로 고르지 않아도 된다).
  필요하면 12자 이내의 짧은 질문 칩을 1개까지 새로 만든다. 카드에 나온 이름을 칩으로 반복하지 않는다.
- table·steps·budget·web의 내용은 앱이 채운다 (facts.app_blocks에 있는 것만 고른다).

규칙:
- 첫 블록은 headline 또는 ask. 순서 예: headline → text(선택) → cards/table/ranking/steps/budget/web → next.
- 숫자·이름은 facts에 있는 것만. 제목의 건수·범위는 앱이 채우므로 text·reason에 건수를 다시 쓰지 않는다.
- cards는 facts.items에 있는 종류만 (예식장 질문엔 예식장, 정책 질문엔 정책).
- 무료·정원·대상 여부 같은 값은 배지·카드가 보여 주므로 문장으로 반복하지 않는다.
- 결과가 0건이면 그렇게 말하고 넓히기 칩을 고른다. 지어내지 않는다.
- facts.ai_general이 true면 앱 데이터가 아닌 일반 안내다: headline 한 줄 + steps(핵심 2~4개). 숫자·이름을 만들지 않는다.
- 질문이 앞 답의 후속인데 결과가 같으면 headline에서 "조건을 바꿔도 같아요"처럼 먼저 말한다.
- fix가 주어지면 그 점을 고쳐 다시 만든다.

예시 1 (예식장 목록) badge_keys=[all_free, fit_count]
{"blocks":[{"type":"headline","title_kind":"app","badges":["all_free","fit_count"]},
{"type":"cards","reason_key":"biggest"},
{"type":"next","items":["이 지역 지원 정책"]}]}
예시 2 (비교)
{"blocks":[{"type":"headline","title_kind":"custom","title":"인원은 A홀, 주차는 B홀"},{"type":"table","ids":["H078","H080"],"fields":["정원","대관료","주차"]},{"type":"next","items":["체크리스트에 담기"]}]}
예시 3 (0건)
{"blocks":[{"type":"headline","title_kind":"app"},{"type":"text","text":"가까운 지역을 볼 수 있어요."}]}
예시 4 (일반 안내)
{"blocks":[{"type":"headline","title_kind":"custom","title":"식사나 답례품으로 해요"},{"type":"steps","items":["피로연 식사 대접","답례품 준비","감사 문자"]},{"type":"next","items":["피로연 되는 곳"]}]}
예시 5 (되묻기)
{"blocks":[{"type":"ask","title":"어느 역 기준으로 찾을까요?","items":["삼성역","강남역","직접 입력"]}]}
''';

  static final writerSchema = Schema.object(properties: {
    'blocks': Schema.array(
      items: Schema.object(
        properties: {
          'type': Schema.enumString(enumValues: [for (final t in BlockType.aiAllowed) t.name]),
          'title_kind': Schema.enumString(enumValues: ['app', 'custom']),
          'title': Schema.string(),
          'text': Schema.string(),
          'badges': Schema.array(items: Schema.string()),
          'ids': Schema.array(items: Schema.string()),
          'reason_key': Schema.string(),
          'reason_keys': Schema.array(items: Schema.string()),
          'fields': Schema.array(items: Schema.string()),
          'items': Schema.array(items: Schema.string()),
        },
        optionalProperties: const ['title_kind', 'title', 'text', 'badges', 'ids', 'reason_key', 'reason_keys', 'fields', 'items'],
      ),
    ),
  });

  /// Gemini에 보내는 사실 묶음 — 짧게 (7): ID·핵심 값·건수·범위만. 긴 글·표 내용은 보내지 않는다 (앱이 채움).
  /// 개인정보 없음 (조건·결과 ID·이름·값만)
  static String factsJson(AnswerFacts f, {int maxItems = 6}) {
    final h = f.hint;
    final needFields = f.kind == AnswerKind.venueCompare || f.kind == AnswerKind.venueDetail || f.kind == AnswerKind.policyDetail;
    final cards = AnswerTemplate.cardItems(f);
    final s = f.scope;
    return jsonEncode({
      'kind': f.kind.name,
      // 예식장·정책이 섞인 답은 합계 대신 종류별 건수 (합계를 '5곳'처럼 말하지 않게)
      if (!f.mixed) 'count': f.count else 'count_by_kind': f.countByKind,
      'app_headline': AnswerTemplate.appHeadline(f),
      if (s != null && (s.towns.isNotEmpty || s.sidos.isNotEmpty)) 'place': s.placeLabel,
      'items': [
        for (final i in cards.take(maxItems))
          {
            'id': i.id,
            'name': i.name.length > 24 ? '${i.name.substring(0, 23)}…' : i.name,
            'values': i.values.take(3).toList(),
            if (i.badge != null) 'badge': '${i.badge!.text}/${i.badge!.tone.name}',
            if (needFields && i.fields.isNotEmpty) 'fields': i.fields.keys.toList(),
            if (i.rankValue != null) 'rank': i.rankValue,
            if (i.reasons.isNotEmpty) 'reasons': i.reasons.keys.toList(),
          },
      ],
      if (f.cardLimit != null) 'card_limit': f.cardLimit,
      if (AnswerTemplate.appPicksCards(f)) 'app_cards': true,
      if (cards.length > maxItems) 'more_items': cards.length - maxItems,
      'badge_keys': {for (final e in f.headBadges.entries) e.key: e.value.text},
      'options': [for (final o in f.options.where((o) => o.kind != 'widen' && o.kind != 'more').take(6)) o.label],
      if (h?.sentence != null) 'app_sentence': h!.sentence,
      'app_blocks': [
        if (h != null && h.rows.isNotEmpty) 'table',
        if (h != null && h.steps.isNotEmpty) 'steps',
        if (h != null && h.ranking.isNotEmpty) 'ranking',
        if (h != null && h.budgetRows.isNotEmpty) 'budget',
        if (h != null && h.web.isNotEmpty) 'web',
      ],
      if (freeText && f.notes.isNotEmpty) 'notes': f.notes.take(5).toList(),
      if (freeText && f.detail.isNotEmpty)
        'app_text': _cut(f.detail, 600)
      else if (f.aiGeneral && (h == null || h.steps.isEmpty) && f.detail.isNotEmpty)
        'app_text': _cut(f.detail, 300),
      if (f.aiGeneral) 'ai_general': true,
      if (f.followUp && f.previous != null) 'previous_headline': f.previous!.headline,
    });
  }

  static String writerInput(AnswerFacts f, {String? fix, String? draft}) => [
        '질문: ${f.question}',
        'facts: ${factsJson(f)}',
        if (fix != null) '고칠 점(fix): $fix',
        if (draft != null) '앞서 만든 답: $draft',
      ].join('\n');

  static String _cut(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';

  /// Gemini JSON → 블록 (값은 모두 앱이 채움). 모르는 id·키는 버린다
  static List<AnswerBlock> resolve(Map<String, Object?> json, AnswerFacts f) {
    final raw = (json['blocks'] as List?)?.whereType<Map>() ?? const <Map>[];
    final out = <AnswerBlock>[];
    var cardsUsed = 0;
    List<String> strs(Object? v) => [for (final x in (v as List?) ?? const []) if (x is String && x.trim().isNotEmpty) x.trim()];
    final names = [for (final i in f.items) i.name];
    String tidy(String s) => fixJosaAfter(fixJosa(s.replaceAll('**', '').trim()), names);
    for (final b in raw) {
      final type = BlockType.byName(b['type']);
      if (type == null || !BlockType.aiAllowed.contains(type)) continue;
      switch (type) {
        case BlockType.headline:
          // 제목의 범위·건수는 앱이 채운다 (2): Gemini가 쓴 숫자는 제목에 들어가지 않는다
          final mine = tidy(b['title'] as String? ?? '');
          final custom = b['title_kind'] == 'custom' &&
              !AnswerTemplate.appOwnsTitle(f) &&
              mine.isNotEmpty &&
              !RegExp(r'\d').hasMatch(mine);
          final appBadges = !custom && f.hint != null && f.hint!.headBadges.isNotEmpty;
          out.add(AnswerBlock(type,
              title: custom ? mine : AnswerTemplate.appHeadline(f),
              badges: appBadges
                  ? f.hint!.headBadges.take(2).toList()
                  : [for (final k in strs(b['badges'])) if (f.headBadges[k] case final x?) x].take(2).toList()));
        case BlockType.text:
          final t = tidy(b['text'] as String? ?? '');
          if (t.isNotEmpty) out.add(AnswerBlock(type, text: t));
        case BlockType.cards:
          final allowed = AnswerTemplate.cardItems(f).map((i) => i.ref).toSet(); // 질문 목적과 같은 종류만 (3)
          // 목록 답(예식장·날짜·기간·정책·업체 목록)은 앱이 카드와 순서를 정한다 (7차: 실행마다 같은 카드). Gemini는 이유 키만
          final items = AnswerTemplate.appPicksCards(f)
              ? AnswerTemplate.cardItems(f)
              : [for (final id in strs(b['ids'])) if (f.byId(id) case final it? when allowed.contains(it.ref)) it];
          final max = f.cardLimit ?? 3;
          final pins = cardsUsed > 0 ? const <FactItem>[] : [for (final r in f.pinned) if (f.byId(r) case final it?) it];
          var take = [...pins, ...items.where((i) => !pins.contains(i))]
              .where((i) => !out.allCards.any((c) => c.ref == i.ref))
              .take(max - cardsUsed)
              .toList();
          // "3개만"처럼 수를 정했으면 모자란 만큼 앱 순서대로 채운다 (4)
          if (f.cardLimit != null && take.length < max - cardsUsed) {
            take = [
              ...take,
              ...AnswerTemplate.cardItems(f)
                  .where((i) => !take.contains(i) && !out.allCards.any((c) => c.ref == i.ref))
                  .take(max - cardsUsed - take.length),
            ];
          }
          if (take.isEmpty) continue;
          // 이유는 앱이 데이터로 확인한 문장만 (Gemini는 키만 고름, 1). 모르는 키면 이유 없음.
          // 제한 없을 때(freeText)는 카드마다 reason_keys, 아니면 첫 카드에만 reason_key
          final key = (b['reason_key'] as String?)?.trim();
          final keys = strs(b['reason_keys']);
          String? reasonFor(int k, FactItem it) {
            if (freeText && k < keys.length) return it.reasons[keys[k]];
            if (freeText && keys.isEmpty && k == 0 && key != null) return it.reasons[key];
            return !freeText && k == 0 && cardsUsed == 0 && key != null ? it.reasons[key] : null;
          }

          out.add(AnswerBlock(type, cards: [
            for (final (k, it) in take.indexed) it.toCard(reason: reasonFor(cardsUsed + k, it)),
          ]));
          cardsUsed += take.length;
        case BlockType.table:
          final items = [for (final id in strs(b['ids'])) if (f.byId(id) case final it?) it];
          final use = items.isEmpty ? f.items.take(3).toList() : items.take(5).toList();
          final fields = strs(b['fields']).where((x) => use.any((i) => i.fields.containsKey(x))).take(5).toList();
          if (use.isNotEmpty && fields.isNotEmpty) {
            out.add(AnswerBlock(type,
                columns: ['', for (final i in use) _short(i.name)],
                rows: [for (final x in fields) [x, for (final i in use) i.fields[x] ?? '정보 없음']]));
          } else if (f.hint != null && f.hint!.rows.isNotEmpty) {
            out.add(AnswerBlock(type, columns: f.hint!.columns, rows: f.hint!.rows));
          }
        case BlockType.ranking:
          // 목록 답은 카드가 이미 앱 순서라 Gemini 순위는 카드를 되풀이할 뿐 → 앱 순위(역 거리 등)가 있을 때만 (7차)
          if (AnswerTemplate.appPicksCards(f) && (f.hint == null || f.hint!.ranking.isEmpty)) continue;
          final items = [for (final id in strs(b['ids'])) if (f.byId(id) case final it?) it];
          final lines = items.isNotEmpty
              ? [for (final i in items.take(3)) '${i.name}${i.rankValue == null ? '' : ' · ${i.rankValue}'}']
              : (f.hint?.ranking ?? const <String>[]).take(3).toList();
          if (lines.isNotEmpty) out.add(AnswerBlock(type, items: lines));
        case BlockType.steps:
          final items = strs(b['items']).map(tidy).take(4).toList();
          final use = items.isNotEmpty ? items : (f.hint?.steps ?? const <String>[]).take(4).toList();
          if (use.isNotEmpty) out.add(AnswerBlock(type, items: use));
        case BlockType.budget:
          if (f.hint != null && f.hint!.budgetRows.isNotEmpty) {
            out.add(AnswerBlock(type, rows: f.hint!.budgetRows, title: f.hint!.budgetTotal));
          }
        case BlockType.ask:
          out.add(AnswerBlock(type, title: tidy(b['title'] as String? ?? ''), items: strs(b['items']).take(4).toList()));
        case BlockType.web:
          if (f.hint != null && f.hint!.web.isNotEmpty) {
            out.add(AnswerBlock(type, web: f.hint!.web, searchQueries: f.hint!.searchQueries));
          }
        case BlockType.next:
          final labels = <String>[];
          var invented = 0;
          for (final x in strs(b['items'])) {
            if (labels.length >= 4) break;
            if (f.options.any((o) => o.label == x)) {
              labels.add(x);
            } else if (invented == 0 && x.length <= 12) {
              labels.add(x);
              invented++;
            }
          }
          final merged = AnswerTemplate.mergeChips(f, labels); // 넓히기·더 보기는 앱이 먼저 (5)
          if (merged.isNotEmpty) out.add(AnswerBlock(type, items: merged));
        default:
          break;
      }
    }
    // 목록 답인데 Gemini가 카드를 빼먹었으면 앱 순서대로 붙인다
    if (AnswerTemplate.appPicksCards(f) && out.firstOf(BlockType.cards) == null && AnswerTemplate.cardItems(f).isNotEmpty) {
      final at = out.indexWhere((b) => b.type == BlockType.next);
      out.insert(at < 0 ? out.length : at,
          AnswerBlock(BlockType.cards, cards: [for (final i in AnswerTemplate.cardItems(f).take(f.cardLimit ?? 3)) i.toCard()]));
    }
    // 제목이 없거나 첫 블록이 아니면 앱 제목을 맨 앞에 (F1)
    if (out.isNotEmpty && out.first.type != BlockType.headline && out.first.type != BlockType.ask) {
      final i = out.indexWhere((x) => x.type == BlockType.headline);
      final head = i >= 0 ? out.removeAt(i) : AnswerBlock(BlockType.headline, title: AnswerTemplate.appHeadline(f));
      out.insert(0, head);
    }
    // Gemini가 next를 빼먹어도 꼭 넣는 칩은 붙인다
    if (out.firstOf(BlockType.next) == null && out.firstOf(BlockType.ask) == null) {
      final merged = AnswerTemplate.mergeChips(f, const []);
      if (merged.isNotEmpty) out.add(AnswerBlock(BlockType.next, items: merged));
    }
    // 앱이 붙이는 블록: 조건 칩(제목 바로 뒤), 웹 결과가 있는데 Gemini가 빼먹었으면 붙임, 접힌 줄
    final filters = AnswerTemplate.filtersOf(f);
    if (filters.isNotEmpty && out.isNotEmpty) {
      final at = out.indexWhere((b) => b.type != BlockType.headline && b.type != BlockType.text);
      out.insert(at < 0 ? out.length : at, AnswerBlock(BlockType.filters, filters: filters));
    }
    if (f.hint != null && f.hint!.web.isNotEmpty && out.firstOf(BlockType.web) == null) {
      final at = out.indexWhere((b) => b.type == BlockType.next);
      out.insert(at < 0 ? out.length : at, AnswerBlock(BlockType.web, web: f.hint!.web, searchQueries: f.hint!.searchQueries));
    }
    return out;
  }

  static String _short(String name) {
    final n = name.split('(').first.trim();
    return n.length > 12 ? '${n.substring(0, 11)}…' : n;
  }

  /// next·ask 칩 이름 → 실제 버튼 (앱이 만든 선택지면 그 동작, 새로 만든 칩이면 질문으로 보냄)
  static List<QuickReply> repliesFor(List<AnswerBlock> blocks, AnswerFacts f) {
    final labels = [
      ...?blocks.firstOf(BlockType.next)?.items,
      ...?blocks.firstOf(BlockType.ask)?.items,
    ];
    return [
      for (final l in labels)
        f.options.where((o) => o.label == l).firstOrNull?.reply ?? QuickReply(l, text: l),
    ];
  }

  // ───────────────────────── ⑤ 검토 ─────────────────────────

  static const reviewerPrompt = '''
너는 결혼 준비 앱 AI 상담의 "답 검토" 단계다. 답을 쓰지 않고 판정만 JSON으로 한다.
받는 것: 질문, 직전 대화, 앱 기준(답 종류·찾은 범위·건수), 조회 결과 요약, 화면에 나갈 답(글로 옮긴 것).
앱 기준은 앱이 데이터로 정한 정답이다. 답의 범위·건수·카드 종류가 앱 기준과 다르면 scope_ok=false.
- answers_question: 질문에 직접 답했나 ('몇 곳'을 물었으면 개수가 있나, 되물어야 할 때 되물었나)
- scope_ok: 질문이 말한 범위(지역·구·날짜·조건)를 그대로 썼나. 질문에 없는 범위로 넓히거나 좁히지 않았나.
  단, 질문에 장소가 없으면 사용자의 시·군·구부터 보여 주고 넓히기를 제안하는 것은 맞는 동작이다.
- context_ok: 후속 질문("그중에", "말고", "그럼 ~는?")이면 앞 조건을 이어받았나 / 새 질문이면 앞 조건을 버렸나
- repeats_previous: 앞 답과 내용이 사실상 같나 (질문이 같으면 false)
- unsupported_claim: 조회 결과에 없는 주장 (숫자·이름·자격·가격). 없으면 빈 배열
- missing: 질문이 요구했는데 빠진 것. 없으면 빈 배열
- fix: 고칠 점 한 줄 (문제가 없으면 빈 문자열)
배지·카드 값은 앱이 데이터로 채운 것이므로 믿는다. 형식(글자 수 등)은 앱이 따로 검사하므로 보지 않는다.
''';

  static final reviewSchema = Schema.object(properties: {
    'answers_question': Schema.boolean(),
    'scope_ok': Schema.boolean(),
    'context_ok': Schema.boolean(),
    'repeats_previous': Schema.boolean(),
    'unsupported_claim': Schema.array(items: Schema.string()),
    'missing': Schema.array(items: Schema.string()),
    'fix': Schema.string(),
  });

  static String reviewInput(AnswerFacts f, List<AnswerBlock> blocks) => [
        '질문: ${f.question}',
        if (f.context.isNotEmpty) '직전 대화:\n${f.context}',
        '앱 기준: 답 종류 ${f.kind.name} · 카드 종류 ${f.allowMixed ? '섞어도 됨' : (f.expectedCardKind ?? '한 종류')}'
            ' · 범위 ${f.scope?.placeLabel.isNotEmpty == true ? f.scope!.placeLabel : '없음'}'
            ' · 건수 ${f.mixed ? jsonEncode(f.countByKind) : f.count}${f.followUp ? ' · 앞 답을 고치는 후속 질문' : ''}',
        if (f.scope != null) '적용한 조건: ${jsonEncode(f.scope!.toJson())}',
        '조회 결과: ${f.count}건 · ${[for (final i in f.items.take(6)) '${i.name}(${[...i.values, if (i.badge != null) i.badge!.text].join('/')})'].join(', ')}',
        if (f.notes.isNotEmpty) '조건 메모: ${f.notes.take(4).join(' / ')}',
        if (f.aiGeneral) '(일반 안내 질문: 앱 데이터가 아닌 일반 지식으로 답함)',
        '답:\n${blocks.plainText}',
        if (blocks.firstOf(BlockType.next) case final n?) '다음 칩: ${n.items.join(', ')}',
      ].join('\n');
}

/// 검토 결과
class ReviewVerdict {
  const ReviewVerdict({
    this.answers = true,
    this.scopeOk = true,
    this.contextOk = true,
    this.repeats = false,
    this.unsupported = const [],
    this.missing = const [],
    this.fix = '',
  });

  final bool answers;
  final bool scopeOk;
  final bool contextOk;
  final bool repeats;
  final List<String> unsupported;
  final List<String> missing;
  final String fix;

  bool get ok => answers && scopeOk && contextOk && !repeats && unsupported.isEmpty && missing.isEmpty;

  static ReviewVerdict fromJson(Map<String, Object?> j) {
    List<String> strs(Object? v) => [for (final x in (v as List?) ?? const []) if (x is String && x.trim().isNotEmpty) x.trim()];
    return ReviewVerdict(
      answers: j['answers_question'] != false,
      scopeOk: j['scope_ok'] != false,
      contextOk: j['context_ok'] != false,
      repeats: j['repeats_previous'] == true,
      unsupported: strs(j['unsupported_claim']),
      missing: strs(j['missing']),
      fix: (j['fix'] as String?)?.trim() ?? '',
    );
  }

  String get summary => ok
      ? '통과'
      : [
          if (!answers) '질문에 직접 답하지 않음',
          if (!scopeOk) '범위가 질문과 다름',
          if (!contextOk) '앞 조건 처리 틀림',
          if (repeats) '앞 답과 같음',
          if (unsupported.isNotEmpty) '근거 없는 주장: ${unsupported.join(', ')}',
          if (missing.isNotEmpty) '빠진 것: ${missing.join(', ')}',
          if (fix.isNotEmpty) '고칠 점: $fix',
        ].join(' · ');
}

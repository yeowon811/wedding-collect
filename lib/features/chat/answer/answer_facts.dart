import '../../../data/models/booking_status.dart';
import '../../../data/models/policy.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/venue.dart';
import '../../policy/policy_matcher.dart';
import '../agent/date_check.dart';
import '../agent/policy_text.dart';
import '../agent/venue_features.dart';
import '../chat_agent.dart';
import 'answer_blocks.dart';

/// 답의 종류 (기본 틀 템플릿과 Gemini 작성 지시가 달라진다)
enum AnswerKind {
  venueList,
  venueDate,
  venueDetail,
  venueCompare,
  policyList,
  policyDetail,
  vendorList,
  cost,
  calc,
  schedule,
  budget,
  general,
  ask,
  other;

  bool get isVenue => this == venueList || this == venueDate || this == venueDetail || this == venueCompare;
}

/// 이번 검색에 실제로 적용된 조건 (앱이 [ConsultAgent._venuePool]에서 기록). 조건 칩·K1 검사의 기준
class QueryScope {
  const QueryScope({
    this.sidos = const [],
    this.towns = const [],
    this.excludeTowns = const [],
    this.freeOnly = false,
    this.maxFee,
    this.guests,
    this.date,
    this.periodLabel,
    this.needs = const [],
    this.sortLabel,
    this.autoTown = false,
    this.args = const {},
  });

  final List<String> sidos;
  final List<String> towns;
  final List<String> excludeTowns;
  final bool freeOnly;
  final int? maxFee; // 원
  final int? guests;
  final DateTime? date;
  final String? periodLabel;
  final List<String> needs;
  final String? sortLabel;
  final bool autoTown; // 질문에 구가 없어 내 시군구부터 보여 준 경우 (R9)
  final Map<String, Object?> args; // search_venues 형식의 조건 (칩 ✕·넓히기에서 고쳐 다시 찾음)

  String get placeLabel => towns.isNotEmpty
      ? towns.map((t) => t).join('·')
      : sidos.isNotEmpty
          ? sidos.join('·')
          : '';

  Map<String, Object?> toJson() => {
        if (sidos.isNotEmpty) 'sido': sidos,
        if (towns.isNotEmpty) 'sigungu': towns,
        if (excludeTowns.isNotEmpty) 'exclude': excludeTowns,
        if (freeOnly) 'free_only': true,
        if (maxFee != null) 'max_fee_won': maxFee,
        if (guests != null) 'guests': guests,
        if (date != null) 'date': BookingStatus.key(date!),
        if (periodLabel != null) 'period': periodLabel,
        if (needs.isNotEmpty) 'needs': needs,
        if (sortLabel != null) 'sort': sortLabel,
      };
}

/// 답에 쓸 결과 하나 (앱 데이터에서 찾은 값). 카드·표·순위는 이 값만 쓴다
class FactItem {
  FactItem({
    required this.ref,
    required this.name,
    this.values = const [],
    this.badge,
    this.contact,
    this.empty = const [],
    this.venue,
    this.policy,
    this.level,
    this.fields = const {},
    this.rankValue,
    this.tags = const [],
  });

  final String ref;
  final String name;
  final List<String> values; // 카드 2줄 값 (순서 고정, F6)
  final BlockBadge? badge; // 맞는지 배지 (앱 판정)
  final String? contact; // 빈 값이 있을 때 문의처 (R2)
  final List<String> empty; // 비어 있는 값 이름 (정원·대관료 …)
  final Venue? venue;
  final Policy? policy;
  final MatchLevel? level;
  final Map<String, String> fields; // 표 칸 값 (정원·대관료·주차 …)
  final String? rankValue; // 순위 블록 값 (빈 날 5일 · 3.2km)
  final List<String> tags; // 카드 위 속성 배지 (Red Team P1-4)
  String? note; // 카드 값 아래 한 줄 (앱이 센 값, 예: 가능한 날 3월 7, 14일)

  /// 카드 이유 후보: 키 → 앱이 데이터로 확인한 짧은 문장 (Gemini는 키만 고름, 6차). [fillReasons]가 채운다
  final Map<String, String> reasons = {};

  String get id => ref.split(':').last;

  BlockCard toCard({String? reason}) =>
      BlockCard(ref: ref, title: name, badge: badge, values: values, reason: reason, contact: contact, tags: tags, note: note);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'values': values,
        if (badge != null) 'badge': badge!.text,
        if (badge != null) 'fit': badge!.tone.name,
        if (empty.isNotEmpty) 'empty': empty,
        if (fields.isNotEmpty) 'fields': fields,
        if (rankValue != null) 'rank': rankValue,
      };
}

/// 다음 행동 칩 후보 (앱이 만든 것). Gemini는 이 중에서 고르거나 짧은 질문 칩을 하나 더한다
class NextOption {
  const NextOption(this.reply, {this.kind = 'next'});

  final QuickReply reply;
  final String kind; // narrow·widen·more·next·action

  String get label => reply.label;
}

/// 직전 답 요약 (K3 반복 검사용)
class PrevAnswer {
  const PrevAnswer({required this.question, required this.headline, required this.ids, this.text = ''});

  final String question;
  final String headline;
  final List<String> ids;
  final String text;
}

/// 앱이 답을 만들 때 넘겨주는 힌트 (기본 틀 제목·표·단계 등). 답 함수가 채운다
class AnswerHint {
  const AnswerHint({
    required this.kind,
    this.headline,
    this.sentence,
    this.headBadges = const [],
    this.columns = const [],
    this.rows = const [],
    this.steps = const [],
    this.budgetRows = const [],
    this.budgetTotal,
    this.ranking = const [],
    this.web = const [],
    this.searchQueries = const [],
  });

  final AnswerKind kind;
  final String? headline;
  final String? sentence;
  final List<BlockBadge> headBadges;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String> steps;
  final List<List<String>> budgetRows;
  final String? budgetTotal;
  final List<String> ranking;
  final List<WebItem> web;
  final List<String> searchQueries;
}

/// 한 번의 답에 필요한 모든 사실 (Gemini 작성·검사·템플릿이 모두 이것만 본다)
class AnswerFacts {
  AnswerFacts({
    required this.question,
    required this.kind,
    this.scope,
    this.items = const [],
    this.total,
    this.headBadges = const {},
    this.options = const [],
    this.notes = const [],
    this.sources = const [],
    this.log = const [],
    this.detail = '',
    this.hint,
    this.previous,
    this.context = '',
    this.aiGeneral = false,
    this.followUp = false,
    this.templateOnly,
    this.allowMixed = false,
    this.cardLimit,
    this.pinned = const [],
    this.steps = const [],
    this.pending = const [],
    this.profile,
  });

  final String question;
  final AnswerKind kind;
  final QueryScope? scope;
  final List<FactItem> items; // 전체 결과 (보여 줄 순서)
  final int? total; // 전체 건수 (items보다 클 수 있음)
  final Map<String, BlockBadge> headBadges; // 제목 배지 후보 (키 → 앱이 센 값)
  final List<NextOption> options;
  final List<String> notes; // 앱이 남긴 조건 설명 (몇 곳 → 몇 곳)
  final List<String> sources;
  final List<String> log; // 어떻게 찾았나요
  final String detail; // 예전 긴 글 (접어서 보관)
  final AnswerHint? hint;
  final PrevAnswer? previous;
  final String context; // 직전 2턴 (검토용)
  final bool aiGeneral; // Gemini 일반 지식 (앱 데이터 아님)
  final bool followUp; // 앞 답을 고치는 후속 질문·조건 칩 (검토 대상)
  final String? templateOnly; // 이유가 있으면 Gemini 없이 기본 틀로 (예: 더 보기)
  final bool allowMixed; // 예식장·정책 카드를 섞어도 되는 답 (전체 추천·두 목적 질문)
  final int? cardLimit; // "3개만"처럼 사용자가 정한 카드 수 (1~5). 있으면 그 수만큼, 더 보기 없음
  final List<String> pinned; // 꼭 맨 앞에 보여 줄 카드 (답의 주인공, 예: "그 대출은 대상이 아니에요"의 그 대출)
  // '어떻게 찾았나요' 사용자 말 요약 (Red Team P1-3): 앱이 센 걸러진 과정 · 앱 데이터로 못 보는 조건 · 이번 답에 쓴 내 정보
  final List<String> steps;
  final List<String> pending;
  final UserProfile? profile;

  int get count => total ?? items.length;

  /// 이 답에 나와야 할 카드 종류 (K7). null이면 한 종류이기만 하면 된다
  String? get expectedCardKind => switch (kind) {
        AnswerKind.venueList || AnswerKind.venueDate || AnswerKind.venueDetail || AnswerKind.venueCompare => 'venue',
        AnswerKind.policyList || AnswerKind.policyDetail => 'policy',
        AnswerKind.vendorList => 'vendor',
        _ => null,
      };

  /// 카드 종류 (시연 업체·실제 업체는 같은 '업체')
  static String cardKindOf(String ref) => switch (ref.split(':').first) { 'real' => 'vendor', final k => k };

  /// 앱이 센 건수들 (K6: 제목의 'N곳·N건' 숫자는 이 안에 있어야 한다)
  Set<int> get appCounts => {
        count,
        ...countByKind.values,
        items.length,
        items.where((i) => i.badge?.tone == Tone.good).length,
      };

  /// 결과 종류별 건수 (예식장·정책이 섞인 답에서 합계를 '곳'으로 말하지 않게)
  Map<String, int> get countByKind {
    final out = <String, int>{};
    for (final i in items) {
      final k = cardKindOf(i.ref);
      out[k] = (out[k] ?? 0) + 1;
    }
    return out;
  }

  bool get mixed => countByKind.length > 1;

  FactItem? byId(String id) => items.where((i) => i.id == id || i.ref == id).firstOrNull;

  /// 숫자 근거 검사(K2)에 쓰는 글: 결과 값·배지·조건·메모·질문·예전 글 전부
  late final String groundText = [
    question,
    detail,
    ...notes,
    for (final i in items) ...[i.name, ...i.values, i.badge?.text ?? '', ...i.fields.values, i.rankValue ?? '', i.contact ?? '', ...i.reasons.values],
    for (final b in headBadges.values) b.text,
    if (scope != null) ...scope!.toJson().values.map((v) => '$v'),
    if (hint != null) ...[
      hint!.headline ?? '',
      hint!.sentence ?? '',
      ...hint!.steps,
      ...hint!.ranking,
      for (final r in hint!.rows) ...r,
      for (final r in hint!.budgetRows) ...r,
      hint!.budgetTotal ?? '',
      for (final w in hint!.web) w.text,
    ],
    if (!mixed) '$count' else ...countByKind.values.map((n) => '$n'),
  ].join('\n');
}

// ───────────────────────── 값 만들기 (앱 판정) ─────────────────────────

String feeShort(Venue v) {
  if (v.rentalFee == null) return '요금 문의 필요';
  if (v.rentalFee == 0) return '무료';
  final w = v.rentalFee!;
  if (w >= 10000 && w % 10000 == 0) return '${w ~/ 10000}만원';
  if (w >= 10000) return '${(w / 10000).toStringAsFixed(1)}만원';
  return '${_comma(w)}원';
}

String capShort(Venue v) {
  if (v.capacity == null) return '정원 문의 필요';
  if (v.capacityMin != null) return '${v.capacityMin}~${v.capacity}명';
  return '최대 ${v.capacity}명';
}

String _comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String md(DateTime d) => '${d.month}/${d.day}';

/// 예식장 결과 하나: 값 순서 = 구 · 정원 · 대관료 (· 주차/날짜). 배지 = 날짜 > 하객 > 요금 순으로 판정
FactItem venueFact(Venue v, {QueryScope? scope, BookingStatus? booking, bool multiSido = false, BlockBadge? override}) {
  final guests = scope?.guests;
  final date = scope?.date;
  final empty = <String>[
    if (v.capacity == null) '정원',
    if (v.rentalFee == null) '대관료',
  ];
  BlockBadge? badge;
  String? dateValue;
  if (date != null) {
    final j = bookingJudge(booking, date) ?? ruleJudgeDate(v, date);
    final slots = booking?.slotsOn(date) ?? const [];
    switch (j.fit) {
      case DateFit.possible:
        final via = bookingJudge(booking, date) != null;
        badge = BlockBadge('${md(date)} ${slots.isEmpty ? (via ? '빔' : '가능일') : '${slots.join('·')} 빔'}', Tone.good);
        dateValue = via ? '${md(date)} 비어 있음' : '${md(date)} 예식 가능일';
      case DateFit.impossible:
        badge = BlockBadge('${md(date)} 안 됨', Tone.no);
        dateValue = '${md(date)} 안 됨';
      case DateFit.unknown:
        badge = const BlockBadge('날짜 정보 없음', Tone.check);
        if (!empty.contains('예약 현황')) empty.add('예약 현황');
    }
  } else if (guests != null) {
    badge = switch (v.fits(guests)) {
      true => BlockBadge('$guests명 OK', Tone.good),
      false => BlockBadge('${v.capacity}명까지', Tone.no),
      null => const BlockBadge('정원 문의 필요', Tone.check),
    };
  } else {
    badge = switch (v.rentalFee) {
      null => const BlockBadge('요금 문의 필요', Tone.check),
      0 => const BlockBadge('무료', Tone.good),
      _ => BlockBadge(feeShort(v), Tone.info),
    };
  }
  final parking = VenueFeatures.parking(v);
  final reception = VenueFeatures.reception(v);
  final needs = scope?.needs ?? const [];
  final place = multiSido || v.sigungu.isEmpty ? v.region : v.sigungu;
  final values = <String>[
    place,
    if (v.capacity != null) capShort(v),
    // 대관료 무료만 따로 보이지 않게 (Red Team P1-2): 식대·꽃장식은 따로 든다
    if (v.rentalFee != null) v.rentalFee == 0 ? '무료 · 식대 별도' : feeShort(v),
    if (needs.contains('parking')) parking.label,
    if (needs.contains('reception')) reception.label,
    if (dateValue != null && badge.tone != Tone.good) dateValue,
  ];
  return FactItem(
    ref: 'venue:${v.id}',
    name: v.name,
    values: values,
    badge: override ?? badge,
    contact: empty.isEmpty ? null : (v.phone != null ? '☎ ${v.bookingContact}' : '예약 페이지에서 문의'),
    empty: empty,
    venue: v,
    rankValue: override?.text,
    tags: VenueFeatures.traits(v, fee: false),
    fields: {
      '지역': v.region,
      '정원': capShort(v),
      '대관료': v.rentalFee == 0 ? '무료 (식대 별도)' : feeShort(v),
      '예약': v.bookingType.label,
      '주차': parking.label,
      '피로연': reception.label,
      if (date != null) md(date): badge.text,
    },
  );
}

/// 정책 결과 하나: 값 = 기관 · 분야 · 금액(원문에 있을 때). 배지 = 앱 판정(대상/조건 확인/대상 아님)
FactItem policyFact(Policy p, {MatchLevel? level, bool miss = false, String? missReason}) {
  final amt = maxAmount(p.eligibility);
  final cap = incomeCap(p.eligibility);
  final badge = miss
      ? BlockBadge(missReason == null || missReason.length > 8 ? '대상 아님' : missReason, Tone.no)
      : switch (level) {
          MatchLevel.likely => const BlockBadge('대상', Tone.good),
          MatchLevel.check => const BlockBadge('조건 확인', Tone.check),
          null => const BlockBadge('조건 확인', Tone.check),
        };
  return FactItem(
    ref: 'policy:${p.id}',
    name: p.name,
    values: [
      p.agency.isEmpty ? p.regionLabel : p.agency,
      p.category.label,
      if (amt != null) '최대 ${manwonLabel(amt)}',
    ],
    badge: badge,
    policy: p,
    level: level,
    fields: {
      '지역': p.regionLabel,
      '분야': p.category.label,
      if (amt != null) '금액': '최대 ${manwonLabel(amt)}',
      if (cap != null) '소득 상한': '연 ${manwonLabel(cap)}',
    },
  );
}

/// 시연 업체 결과: 값 = 항목 · 가격 · 평점. 배지 = 내 예산 안/초과
FactItem demoVendorFact(DemoVendor v, {int? budget, required int guests}) {
  final est = v.estimate(guests: guests);
  return FactItem(
    ref: 'vendor:${v.id}',
    name: v.name,
    values: [v.category.label, v.priceText, '★${v.rating}'],
    badge: budget == null ? const BlockBadge('시연용 가격', Tone.info) : (est <= budget ? const BlockBadge('예산 안', Tone.good) : const BlockBadge('예산 초과', Tone.no)),
    fields: {'항목': v.category.label, '가격': v.priceText, '평점': '★${v.rating}', '예상': '$est만원'},
  );
}

/// 실제 연계 업체: 가격은 없다 (문의)
FactItem realVendorFact(RealVendor v) => FactItem(
      ref: 'real:${v.id}',
      name: v.name,
      values: [v.categoryText, v.sigungu.isEmpty ? v.sido : v.sigungu, '가격 문의'],
      badge: BlockBadge(v.isOfficial ? '공식' : '실제 업체', v.isOfficial ? Tone.good : Tone.info),
      contact: v.phone.isEmpty ? null : '☎ ${v.phone}',
      empty: const ['가격'],
      fields: {'항목': v.categoryText, '지역': v.sido, '가격': '문의'},
    );

/// 예전 카드(데이터를 찾지 못한 것)를 그대로 사실로
FactItem cardFact(ChatCard c) {
  final b = c.badge;
  final tone = b == null
      ? Tone.info
      : RegExp(r'해당 가능성 높음|하객 수용|예산 안|비어 있음|가능일|최저가').hasMatch(b)
          ? Tone.good
          : RegExp(r'확인|정보 없음|모름').hasMatch(b)
              ? Tone.check
              : RegExp(r'초과|부족|불가|아님').hasMatch(b)
                  ? Tone.no
                  : Tone.info;
  return FactItem(
    ref: c.ref ?? 'card:${c.title}',
    name: c.title,
    values: c.subtitle.split(' · ').where((s) => s.trim().isNotEmpty).take(3).toList(),
    badge: b == null ? null : BlockBadge(b.length > 10 ? b.substring(0, 10) : b, tone),
  );
}

/// 카드 이유 후보를 채운다 (6차): 데이터로 참인 것만, 문장은 앱이 정한다 (18자 이내).
/// '가장 큼·가장 낮음'은 이번 결과 안에서 비교한 값
void fillReasons(List<FactItem> items, {int? guests, DateTime? date}) {
  final vs = [for (final i in items) if (i.venue != null) i];
  final caps = [for (final i in vs) if (i.venue!.capacity != null) i.venue!.capacity!];
  final fees = [for (final i in vs) if (i.venue!.rentalFee != null) i.venue!.rentalFee!];
  final maxCap = caps.length >= 2 ? caps.reduce((a, b) => a > b ? a : b) : null;
  final minFee = fees.length >= 2 && fees.toSet().length > 1 ? fees.reduce((a, b) => a < b ? a : b) : null;
  for (final i in vs) {
    final v = i.venue!;
    final r = i.reasons;
    if (maxCap != null && v.capacity == maxCap) r['biggest'] = '정원이 가장 큼 ($maxCap명)';
    if (minFee != null && v.rentalFee == minFee) r['cheapest'] = '대관료가 가장 낮음';
    if (v.rentalFee == 0) r['free'] = '대관료 무료 · 식대 별도';
    if (guests != null && v.fits(guests) == true) r['fits'] = '하객 $guests명 수용';
    final p = VenueFeatures.parking(v);
    if (p.ok == Avail.yes) r['parking'] = p.spaces != null ? '주차 ${p.spaces}대' : '주차 가능';
    if (VenueFeatures.reception(v).ok == Avail.yes) r['reception'] = '피로연 가능';
    final o = VenueFeatures.outdoor(v);
    if (o.ok == Avail.yes && !o.guessed) r['outdoor'] = '야외 예식';
    if (date != null && i.badge?.tone == Tone.good) r['open_on_date'] = '${md(date)} 비어 있음';
  }
  final ratings = <double>[];
  final demo = <FactItem>[];
  for (final i in items.where((i) => i.policy != null)) {
    if (i.level == MatchLevel.likely) i.reasons['likely'] = '조건이 잘 맞음';
    final amt = maxAmount(i.policy!.eligibility);
    if (amt != null) i.reasons['max_amount'] = '최대 ${manwonLabel(amt)} 지원';
  }
  for (final i in items.where((i) => i.ref.startsWith('vendor:'))) {
    demo.add(i);
    final rating = double.tryParse(i.fields['평점']?.replaceAll('★', '') ?? '');
    if (rating != null) ratings.add(rating);
    if (i.badge?.text == '예산 안') i.reasons['in_budget'] = '내 예산 안';
  }
  if (ratings.length >= 2) {
    final best = ratings.reduce((a, b) => a > b ? a : b);
    for (final i in demo) {
      if (i.fields['평점'] == '★$best') i.reasons['top_rating'] = '평점이 가장 높음 (★$best)';
    }
  }
  for (final i in items.where((i) => i.ref.startsWith('real:') && i.badge?.text == '공식')) {
    i.reasons['official'] = '공식 전담 업체';
  }
}

/// 제목 배지 후보 (앱이 센 숫자). Gemini는 키만 고른다
Map<String, BlockBadge> headBadgesFor(AnswerKind kind, List<FactItem> items, QueryScope? scope) {
  final out = <String, BlockBadge>{};
  if (kind.isVenue) {
    final vs = [for (final i in items) if (i.venue != null) i.venue!];
    if (vs.isEmpty) return out;
    final free = vs.where((v) => v.isFree).length;
    if (free == vs.length) {
      out['all_free'] = const BlockBadge('모두 무료', Tone.good);
    } else if (free > 0) {
      out['free_count'] = BlockBadge('무료 $free곳', Tone.good);
    }
    final g = scope?.guests;
    if (g != null) {
      final fit = vs.where((v) => v.fits(g) == true).length;
      out['fit_count'] = BlockBadge('$g명 가능 $fit곳', fit > 0 ? Tone.good : Tone.no);
    }
    if (scope?.date != null) {
      final open = items.where((i) => i.badge?.tone == Tone.good).length;
      out['open_count'] = BlockBadge('${md(scope!.date!)} 빈 곳 $open곳', open > 0 ? Tone.good : Tone.no);
    }
    final noInfo = vs.where((v) => v.capacity == null || v.rentalFee == null).length;
    if (noInfo > 0) out['no_info_count'] = BlockBadge('정보 없음 $noInfo곳', Tone.check);
  }
  if (kind == AnswerKind.policyList) {
    final likely = items.where((i) => i.level == MatchLevel.likely).length;
    final check = items.where((i) => i.level == MatchLevel.check).length;
    if (likely > 0) out['likely_count'] = BlockBadge('대상 $likely건', Tone.good);
    if (check > 0) out['check_count'] = BlockBadge('조건 확인 $check건', Tone.check);
  }
  if (kind == AnswerKind.vendorList) {
    final inB = items.where((i) => i.badge?.text == '예산 안').length;
    final over = items.where((i) => i.badge?.text == '예산 초과').length;
    if (inB + over > 0) out['in_budget_count'] = BlockBadge('예산 안 $inB곳', inB > 0 ? Tone.good : Tone.no);
    if (items.any((i) => i.ref.startsWith('vendor:'))) out['demo'] = const BlockBadge('시연용 가격', Tone.info);
  }
  return out;
}

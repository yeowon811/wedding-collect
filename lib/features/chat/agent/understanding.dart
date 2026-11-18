import '../../../core/utils/region.dart';
import 'calc.dart';
import '../../../data/models/policy.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/vendor.dart';

/// 질문의 목적
enum ConsultIntent {
  recommend, // 내 상황에 맞게 전체 추천
  policy, // 지원 정책
  venue, // 공공예식장
  vendor, // 업체(드레스·스냅 등)
  budget, // 내 예산 현황 (준비 항목에 정한 금액)
  schedule, // 준비 순서·일정
  help, // 무엇을 물어볼지 모름
}

/// 답변에 필요한 정보 항목
enum Slot { sido, sigungu, age, stage, marriedYears, guests, budget, item, homeless, weddingDate }

/// 질문 종류: 무엇을 해 달라는 질문인가 (목적과 별개)
enum AskKind {
  list, // 찾아 줘·추천 (기본)
  detail, // 특정 예식장·정책·업체 하나에 대해
  compare, // 둘 이상 비교
  cost, // 비용 수준·추가금·예산이 충분한지 (업체_요소 단가표)
  calc, // 질문에 준 숫자로 계산
  general, // 앱 데이터가 아닌 일반 지식·방법·제도 설명
}

/// 예식장 조건 중 원문으로 거르는 것
const kVenueNeeds = ['parking', 'reception', 'outdoor'];

/// 질문 하나를 이해한 결과 (= 답을 만들 계획: 어떤 도구를 어떤 조건으로 쓸지)
class Understanding {
  const Understanding({
    required this.intent,
    this.facts = const UserProfile(),
    this.topic,
    this.item,
    this.refIndex,
    this.filter,
    this.date,
    this.unsupported = const [],
    this.kind = AskKind.list,
    this.names = const [],
    this.exclude = const [],
    this.needs = const [],
    this.items = const [],
    this.itemBudget,
    this.calc,
    this.monthsLeft,
    this.also,
  });

  final AskKind kind;
  final List<String> names; // 질문에 나온 예식장·정책·업체 이름
  final List<String> exclude; // 빼 달라는 시군구
  final List<String> needs; // 예식장 원문 조건 ([kVenueNeeds])
  final List<VendorCategory> items; // 업체 항목 여러 개 (스드메 = 촬영·드레스·메이크업)
  final int? itemBudget; // 그 항목(들)에 쓸 금액 상한 (만원)
  final String? calc; // 계산식 (원 단위, 예: 65000*150)
  final int? monthsLeft; // 예식까지 남은 개월
  final ConsultIntent? also; // 함께 물은 두 번째 목적

  final ConsultIntent intent;
  final DateTime? date; // 질문 속 예식·예약 날짜 (예: "12/20")
  final List<String> unsupported; // 질문 속 조건 중 앱 데이터로 확인할 수 없는 것 (Gemini 판단)
  final UserProfile facts; // 질문에서 새로 알게 된 정보 (예: "20대" → 만 20~29세)
  final PolicyCategory? topic; // 정책 분야 (예: "신혼생활" → 주거)
  final VendorCategory? item; // 업체 항목 (예: "드레스")
  final int? refIndex; // 이전 답변 목록의 몇 번째 항목을 가리키는지 (1부터, "두 번째 거" → 2)
  final String? filter; // 이전 결과를 거르는 조건 ([kResultFilters] 중 하나)

  Understanding withItem(VendorCategory item) => copyWith(item: item);

  Understanding copyWith({
    ConsultIntent? intent,
    UserProfile? facts,
    PolicyCategory? topic,
    VendorCategory? item,
    int? refIndex,
    String? filter,
    AskKind? kind,
  }) =>
      Understanding(
        intent: intent ?? this.intent,
        facts: facts ?? this.facts,
        topic: topic ?? this.topic,
        item: item ?? this.item,
        refIndex: refIndex ?? this.refIndex,
        filter: filter ?? this.filter,
        date: date,
        unsupported: unsupported,
        kind: kind ?? this.kind,
        names: names,
        exclude: exclude,
        needs: needs,
        items: items,
        itemBudget: itemBudget,
        calc: calc,
        monthsLeft: monthsLeft,
        also: also,
      );

  /// 규칙 결과(plan 필드)를 Gemini 결과에 보탠다: Gemini가 비운 것만 채움
  Understanding withPlanFrom(Understanding r) => Understanding(
        intent: intent,
        facts: facts,
        topic: topic,
        item: item,
        refIndex: refIndex,
        filter: filter,
        date: date ?? r.date,
        unsupported: unsupported,
        kind: kind != AskKind.list ? kind : r.kind,
        names: names.isNotEmpty ? names : r.names,
        exclude: exclude.isNotEmpty ? exclude : r.exclude,
        needs: {...needs, ...r.needs}.toList(),
        items: items.isNotEmpty ? items : r.items,
        itemBudget: itemBudget ?? r.itemBudget,
        calc: calc ?? r.calc,
        monthsLeft: monthsLeft ?? r.monthsLeft,
        also: also ?? (r.also == null ? null : (r.also == intent ? (r.intent == intent ? null : r.intent) : r.also)),
      );
}

/// 이전 결과를 거르는 조건: 무료 / 하객 수용 / 더 싼 곳 / 사진 있음
const kResultFilters = ['free', 'fits_guests', 'cheaper', 'has_photo'];

/// 질문 이해 단계. 지금은 규칙(키워드·정규식), 나중에는 LLM이 같은 결과를 만들면 된다.
abstract class Understander {
  /// [expecting]: 방금 되물은 항목. 짧은 답("서울", "27")을 그 항목의 값으로 읽는다.
  Understanding parse(String text, {Slot? expecting});
}

class RuleUnderstander implements Understander {
  static const _itemWords = <VendorCategory, List<String>>{
    VendorCategory.parentMakeup: ['혼주 메이크업', '혼주메이크업', '혼주'],
    VendorCategory.dress: ['드레스'],
    VendorCategory.meal: ['식대', '식사', '뷔페', '케이터링', '피로연'],
    VendorCategory.studio: ['웨딩촬영', '스튜디오', '촬영'],
    VendorCategory.snap: ['스냅'],
    VendorCategory.invitation: ['청첩장'],
    VendorCategory.props: ['부케', '케이크', '꽃'],
    VendorCategory.video: ['영상'],
    VendorCategory.suit: ['정장', '턱시도', '수트'],
    VendorCategory.hanbok: ['한복'],
    VendorCategory.makeup: ['메이크업', '화장'],
  };

  /// 묶음 이름 → 항목 여러 개
  static const _bundles = <String, List<VendorCategory>>{
    '스드메': [VendorCategory.studio, VendorCategory.dress, VendorCategory.makeup],
  };

  static const _topicWords = <PolicyCategory, List<String>>{
    PolicyCategory.housing: ['신혼집', '신혼생활', '주거', '전세', '월세', '집', '대출', '임대', '이자'],
    PolicyCategory.cash: ['장려금', '축하금', '지원금', '현금', '목돈'],
    PolicyCategory.wedding: ['예식 지원', '결혼식 지원', '대관료'],
    PolicyCategory.health: ['검진', '건강', '임신', '가임'],
  };

  static const _sidoAliases = <String, List<String>>{
    '서울': ['서울'], '부산': ['부산'], '대구': ['대구'], '인천': ['인천'], '광주': ['광주'],
    '대전': ['대전'], '울산': ['울산'], '세종': ['세종'], '경기': ['경기'], '강원': ['강원'],
    '충북': ['충북', '충청북'], '충남': ['충남', '충청남'], '전북': ['전북', '전라북'],
    '전남': ['전남', '전라남'], '경북': ['경북', '경상북'], '경남': ['경남', '경상남'], '제주': ['제주'],
  };

  bool _has(String t, List<String> words) => words.any(t.contains);

  @override
  Understanding parse(String text, {Slot? expecting}) {
    final t = text.replaceAll(' ', '');
    final raw = text;

    // ── 정보 추출 ──
    String? sido;
    for (final e in _sidoAliases.entries) {
      if (_has(t, e.value)) {
        sido = e.key;
        break;
      }
    }
    assert(sido == null || kSidoList.contains(sido));

    int? age, ageMax;
    final exact = RegExp(r'(?:만\s*)?(\d{2})\s*(?:세|살)').firstMatch(raw);
    final decade = RegExp(r'(\d)0\s*대\s*(초반|중반|후반)?').firstMatch(raw);
    if (exact != null) {
      age = int.parse(exact.group(1)!);
    } else if (decade != null) {
      final base = int.parse(decade.group(1)!) * 10;
      (age, ageMax) = switch (decade.group(2)) {
        '초반' => (base, base + 3),
        '중반' => (base + 3, base + 6),
        '후반' => (base + 6, base + 9),
        _ => (base, base + 9),
      };
    } else if (expecting == Slot.age) {
      final n = RegExp(r'\d{2}').firstMatch(raw);
      if (n != null) age = int.parse(n.group(0)!);
    }

    MarriageStage? stage;
    if (_has(t, ['예비부부', '예비신혼', '결혼예정', '결혼할', '결혼준비', '아직결혼', '혼인신고전', '혼인신고안', '신고안했'])) {
      stage = MarriageStage.engaged;
    } else if (_has(t, ['혼인신고했', '결혼했', '신혼부부', '혼인신고후', '년차'])) {
      stage = MarriageStage.married;
    }

    int? years;
    final y = RegExp(r'(?:결혼|혼인)?\s*(\d{1,2})\s*년\s*(?:차|째|됐|되었|이내)').firstMatch(raw);
    if (y != null) {
      years = int.parse(y.group(1)!);
      stage ??= MarriageStage.married;
    }

    int? guests;
    final g = RegExp(r'(?:하객\s*)?(\d{2,3})\s*명').firstMatch(raw);
    if (g != null && (raw.contains('하객') || expecting == Slot.guests)) guests = int.parse(g.group(1)!);

    int? budget; // 만원
    final b = RegExp(r'(\d+(?:\.\d+)?)\s*(억|천만|천|만)\s*원?').firstMatch(raw);
    if (b != null && (raw.contains('예산') || expecting == Slot.budget)) {
      final n = double.parse(b.group(1)!);
      budget = switch (b.group(2)) {
        '억' => (n * 10000).round(),
        '천만' || '천' => (n * 1000).round(),
        _ => n.round(),
      };
    }

    bool? homeless;
    if (_has(t, ['무주택', '집이없', '집없'])) homeless = true;
    if (_has(t, ['집이있', '집있', '유주택', '주택보유'])) homeless = false;

    final items = [for (final e in _bundles.entries) if (t.contains(e.key)) ...e.value];
    VendorCategory? item = items.isEmpty ? null : items.first;
    for (final e in _itemWords.entries) {
      if (item != null) break;
      if (_has(t, e.value.map((w) => w.replaceAll(' ', '')).toList())) {
        item = e.key;
        break;
      }
    }

    PolicyCategory? topic;
    for (final e in _topicWords.entries) {
      if (_has(t, e.value.map((w) => w.replaceAll(' ', '')).toList())) {
        topic = e.key;
        break;
      }
    }

    // ── 목적 판단 ──
    final ConsultIntent intent;
    if (_has(t, ['정책', '지원', '혜택', '받을수있', '장려금', '축하금', '대출', '이자']) || (topic != null && item == null)) {
      intent = ConsultIntent.policy;
    } else if (item != null && !_has(t, ['예식장', '식장', '공공예식'])) {
      intent = ConsultIntent.vendor;
    } else if (_has(t, ['예식장', '식장', '공공예식', '장소', '대관', '할곳', '할데', '작은결혼식', '스몰웨딩'])) {
      intent = ConsultIntent.venue;
    } else if (_has(t, ['예산', '얼마', '비용', '돈'])) {
      intent = ConsultIntent.budget;
    } else if (_has(t, ['뭐부터', '순서', '할일', '일정', '언제', '준비'])) {
      intent = ConsultIntent.schedule;
    } else if (_has(t, ['추천', '맞춤', '전체', '한번에'])) {
      intent = ConsultIntent.recommend;
    } else {
      intent = ConsultIntent.help;
    }

    // ── 계획(질문 종류·조건) ──
    final askVenue = _has(t, ['예식장', '식장', '공공예식']);
    final askPolicy = _has(t, ['정책', '지원', '혜택', '장려금']);
    final both = askVenue && askPolicy && _has(t, ['이랑', '하고', '같이', '랑', '와', '과', '도']);
    final calc = ruleCalc(raw);
    final dupApply = _has(t, ['동시에', '중복', '두군데', '두곳', '여러곳', '여러군데']) && _has(t, ['신청', '예약', '계약']);
    final kind = calc != null
        ? AskKind.calc
        : dupApply
            ? AskKind.general
        : _has(t, ['비교', '어디가나', '어느곳이', '뭐가나', '중에어디', '중어디'])
            ? AskKind.compare
            : _has(t, ['추가금', '총얼마', '총비용', '얼마들', '비용은', '보통얼마', '얼마정도', '얼마잡', '더싸', '진짜싸'])
                ? AskKind.cost
                : AskKind.list;
    final months = RegExp(r'(\d{1,2})\s*개월\s*(?:남|뒤|후)').firstMatch(raw);
    final yearLeft = RegExp(r'(\d)\s*년\s*(?:남|뒤|후)').firstMatch(raw);
    final needs = [
      if (t.contains('주차')) 'parking',
      if (_has(t, ['피로연', '출장뷔페', '케이터링', '도시락'])) 'reception',
      if (_has(t, ['야외', '잔디', '가든'])) 'outdoor',
    ];
    final ex = RegExp(r'([가-힣]{1,5}(?:구|시|군))\s*(?:은|는)?\s*(?:말고|빼고|제외)').firstMatch(raw);
    final budgetCap = RegExp(r'(\d+)\s*만\s*원?\s*(?:안|이하|이내|까지|내로|아래)').firstMatch(raw);

    return Understanding(
      intent: intent,
      kind: kind,
      calc: calc,
      also: both ? (intent == ConsultIntent.policy ? ConsultIntent.venue : ConsultIntent.policy) : null,
      items: items,
      needs: needs,
      exclude: ex == null ? const [] : [ex[1]!],
      itemBudget: budgetCap == null ? null : int.parse(budgetCap[1]!),
      monthsLeft: months != null ? int.parse(months[1]!) : (yearLeft != null ? int.parse(yearLeft[1]!) * 12 : null),
      facts: UserProfile(
        sido: sido,
        age: age,
        ageMax: ageMax,
        stage: stage,
        marriedYears: years,
        guests: guests,
        budget: budget,
        homeless: homeless,
      ),
      topic: topic,
      item: item,
    );
  }
}

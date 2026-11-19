/// 결혼 단계 (직접 고르지 않고 예식일로 정한다: 예식 전 = 예비부부, 예식 후 = 신혼부부)
enum MarriageStage {
  engaged('예비부부'),
  married('신혼부부');

  const MarriageStage(this.label);
  final String label;
}

/// 초혼 여부 (결혼 장려금 일부는 '초혼 부부'·'부부 중 1명 이상 초혼'만 대상)
enum FirstMarriage {
  both('둘 다 초혼'),
  one('한 명만 초혼'),
  none('둘 다 재혼');

  const FirstMarriage(this.label);
  final String label;
}

/// 상담 전에 입력하는 "내 정보". 비어 있는 값은 상담 중에 다시 묻는다.
/// 기기 안에서만 쓰고, 외부 AI로 보낼 때도 이름·연락처 없이 조건만 보낸다.
class UserProfile {
  const UserProfile({
    this.sido,
    this.sigungu,
    this.age,
    this.ageMax,
    MarriageStage? stage,
    int? marriedYears,
    this.weddingDate,
    this.weddingUndecided = false,
    this.guests,
    this.budget,
    this.homeless,
    this.firstMarriage,
    this.income,
  })  : stageInput = stage,
        marriedYearsInput = marriedYears;

  final String? sido; // 거주 지역 (시도)
  final String? sigungu; // 거주 시·군·구 (선택, 시군구 단위 정책 판정에 씀)

  /// "서울 강남구" 또는 "서울"
  String? get regionLabel => sido == null ? null : (sigungu == null ? sido : '$sido $sigungu');
  final int? age; // 만 나이. 범위로만 알면 최소값 (예: 20대 → 20)
  final int? ageMax; // 범위로만 알 때 최대값 (예: 20대 → 29). 정확한 나이면 null

  /// 대화에서 직접 말한 결혼 단계 ("혼인신고 했어요"). 화면에서는 고르지 않는다
  final MarriageStage? stageInput;

  /// 대화에서 직접 말한 혼인 N년차
  final int? marriedYearsInput;
  final DateTime? weddingDate;
  final bool weddingUndecided; // 예식일 미정
  final int? guests; // 예상 하객 수
  final int? budget; // 총예산 (만원)
  final bool? homeless; // 무주택 여부 (null = 모름)
  final FirstMarriage? firstMarriage; // 초혼 여부 (null = 모름)
  final int? income; // 부부 합산 연소득 (만원, null = 모름)

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// 예식일이 지났는지 (오늘 예식이면 아직 예비부부로 본다)
  bool get weddingPassed => weddingDate != null && weddingDate!.isBefore(_today);

  /// 결혼 단계: "혼인신고 했어요"라고 말했으면 신혼부부(예식 전 혼인신고도 흔함),
  /// 아니면 예식일로 정한다 (예식 전 예비부부 · 예식 후 신혼부부)
  MarriageStage? get stage {
    if (stageInput == MarriageStage.married) return MarriageStage.married;
    if (weddingDate != null) return weddingPassed ? MarriageStage.married : MarriageStage.engaged;
    return stageInput;
  }

  /// 혼인 N년차: 대화에서 말한 값, 없으면 예식일부터 센다 (1년 안이면 1년차)
  int? get marriedYears {
    if (marriedYearsInput != null) return marriedYearsInput;
    if (!weddingPassed) return null;
    return _today.difference(weddingDate!).inDays ~/ 365 + 1;
  }

  /// 예식 후 지난 개월 수 (예식 전이면 null)
  int? get monthsSinceWedding {
    if (!weddingPassed) return null;
    final t = _today, w = weddingDate!;
    return (t.year - w.year) * 12 + t.month - w.month - (t.day < w.day ? 1 : 0);
  }

  bool get hasAge => age != null;
  bool get isAgeRange => ageMax != null && ageMax != age;

  String get ageLabel {
    if (age == null) return '나이 미입력';
    return isAgeRange ? '만 $age~$ageMax세' : '만 $age세';
  }

  String get stageLabel {
    final s = stage;
    if (s == null) return '결혼 단계 미입력';
    final y = marriedYears;
    if (s == MarriageStage.married && y != null) {
      return y >= 8 ? '신혼부부(혼인 7년 넘음)' : '신혼부부(혼인 $y년 이내)';
    }
    return s.label;
  }

  /// "서울 · 만 29세 · 예비부부" 같은 요약 (값이 있는 것만)
  String get summary => [
    if (sido != null) regionLabel!,
    if (age != null) ageLabel,
    if (stage != null) stageLabel,
    if (guests != null) '하객 $guests명',
    if (budget != null) '예산 $budget만원',
  ].join(' · ');

  /// 대화에서 새로 알게 된 값으로 덮어쓴다 (null인 값은 그대로 둠)
  UserProfile merge(UserProfile o) => UserProfile(
    sido: o.sido ?? sido,
    // 시도가 바뀌면 예전 시군구는 버린다
    sigungu: o.sigungu ?? (o.sido != null && o.sido != sido ? null : sigungu),
    age: o.age ?? age,
    ageMax: o.age != null ? o.ageMax : ageMax,
    stage: o.stageInput ?? stageInput,
    marriedYears: o.marriedYearsInput ?? marriedYearsInput,
    weddingDate: o.weddingDate ?? weddingDate,
    weddingUndecided: o.weddingDate != null
        ? false
        : (o.weddingUndecided || weddingUndecided),
    guests: o.guests ?? guests,
    budget: o.budget ?? budget,
    homeless: o.homeless ?? homeless,
    firstMarriage: o.firstMarriage ?? firstMarriage,
    income: o.income ?? income,
  );

  UserProfile copyWith({
    String? sido,
    String? sigungu,
    bool clearSigungu = false,
    int? age,
    int? ageMax,
    bool clearAgeMax = false,
    MarriageStage? stage,
    int? marriedYears,
    DateTime? weddingDate,
    bool clearWeddingDate = false,
    bool? weddingUndecided,
    int? guests,
    int? budget,
    bool? homeless,
    bool clearHomeless = false,
    FirstMarriage? firstMarriage,
    bool clearFirstMarriage = false,
    int? income,
    bool clearIncome = false,
  }) => UserProfile(
    sido: sido ?? this.sido,
    sigungu: clearSigungu || (sido != null && sido != this.sido && sigungu == null) ? null : (sigungu ?? this.sigungu),
    age: age ?? this.age,
    ageMax: clearAgeMax ? null : (ageMax ?? this.ageMax),
    stage: stage ?? stageInput,
    marriedYears: marriedYears ?? marriedYearsInput,
    weddingDate: clearWeddingDate ? null : (weddingDate ?? this.weddingDate),
    weddingUndecided: weddingUndecided ?? this.weddingUndecided,
    guests: guests ?? this.guests,
    budget: budget ?? this.budget,
    homeless: clearHomeless ? null : (homeless ?? this.homeless),
    firstMarriage: clearFirstMarriage ? null : (firstMarriage ?? this.firstMarriage),
    income: clearIncome ? null : (income ?? this.income),
  );
}

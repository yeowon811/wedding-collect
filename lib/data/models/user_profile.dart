/// 결혼 단계
enum MarriageStage {
  engaged('예비부부'),
  married('신혼부부');

  const MarriageStage(this.label);
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
    this.stage,
    this.marriedYears,
    this.weddingDate,
    this.weddingUndecided = false,
    this.guests,
    this.budget,
    this.homeless,
  });

  final String? sido; // 거주 지역 (시도)
  final String? sigungu; // 거주 시·군·구 (선택, 시군구 단위 정책 판정에 씀)

  /// "서울 강남구" 또는 "서울"
  String? get regionLabel => sido == null ? null : (sigungu == null ? sido : '$sido $sigungu');
  final int? age; // 만 나이. 범위로만 알면 최소값 (예: 20대 → 20)
  final int? ageMax; // 범위로만 알 때 최대값 (예: 20대 → 29). 정확한 나이면 null
  final MarriageStage? stage;
  final int? marriedYears; // 신혼부부일 때 혼인 N년차
  final DateTime? weddingDate;
  final bool weddingUndecided; // 예식일 미정
  final int? guests; // 예상 하객 수
  final int? budget; // 총예산 (만원)
  final bool? homeless; // 무주택 여부 (null = 모름)

  bool get hasAge => age != null;
  bool get isAgeRange => ageMax != null && ageMax != age;

  String get ageLabel {
    if (age == null) return '나이 미입력';
    return isAgeRange ? '만 $age~$ageMax세' : '만 $age세';
  }

  String get stageLabel {
    if (stage == null) return '결혼 단계 미입력';
    if (stage == MarriageStage.married && marriedYears != null) {
      return marriedYears! >= 8
          ? '신혼부부(혼인 7년 넘음)'
          : '신혼부부(혼인 $marriedYears년 이내)';
    }
    return stage!.label;
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
    stage: o.stage ?? stage,
    marriedYears: o.marriedYears ?? marriedYears,
    weddingDate: o.weddingDate ?? weddingDate,
    weddingUndecided: o.weddingDate != null
        ? false
        : (o.weddingUndecided || weddingUndecided),
    guests: o.guests ?? guests,
    budget: o.budget ?? budget,
    homeless: o.homeless ?? homeless,
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
    bool? weddingUndecided,
    int? guests,
    int? budget,
    bool? homeless,
    bool clearHomeless = false,
  }) => UserProfile(
    sido: sido ?? this.sido,
    sigungu: clearSigungu || (sido != null && sido != this.sido && sigungu == null) ? null : (sigungu ?? this.sigungu),
    age: age ?? this.age,
    ageMax: clearAgeMax ? null : (ageMax ?? this.ageMax),
    stage: stage ?? this.stage,
    marriedYears: marriedYears ?? this.marriedYears,
    weddingDate: weddingDate ?? this.weddingDate,
    weddingUndecided: weddingUndecided ?? this.weddingUndecided,
    guests: guests ?? this.guests,
    budget: budget ?? this.budget,
    homeless: clearHomeless ? null : (homeless ?? this.homeless),
  );
}

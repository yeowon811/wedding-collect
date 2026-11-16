/// 정책 분류
enum PolicyCategory {
  wedding('예식 지원'),
  cash('결혼 장려금'),
  housing('주거·대출'),
  health('건강검진'),
  education('교육·상담'),
  etc('기타');

  const PolicyCategory(this.label);
  final String label;

  static PolicyCategory fromCode(String code) => switch (code) {
    'WEDDING' => wedding,
    'CASH' => cash,
    'HOUSING' => housing,
    'HEALTH' => health,
    'EDUCATION' => education,
    _ => etc,
  };
}

/// 청년 결혼 지원 정책 1건.
/// 조건 항목(나이·혼인 등)은 원문에서 자동 추출한 값이며 [reviewed]가 false면 검수 전이다.
class Policy {
  const Policy({
    required this.id,
    required this.name,
    required this.agency,
    required this.sido,
    required this.sigungu,
    required this.eligibility,
    required this.url,
    required this.category,
    required this.allowsEngaged,
    required this.hasIncomeLimit,
    required this.requiresHomeless,
    required this.reviewed,
    this.ageMin,
    this.ageMax,
    this.marriedWithinYears,
  });

  final String id;
  final String name;
  final String agency;
  final String sido; // '전국' 또는 시도 짧은 이름
  final String sigungu; // 시군구 정책이면 이름, 시도·전국 정책이면 ''
  final String eligibility; // 지원 자격 원문
  final String url;
  final PolicyCategory category;
  final int? ageMin;
  final int? ageMax;
  final bool allowsEngaged; // 원문에 예비부부·결혼예정 언급
  final int? marriedWithinYears; // 혼인 N년 이내
  final bool hasIncomeLimit;
  final bool requiresHomeless;
  final bool reviewed;

  bool get isNational => sido == '전국';

  String get regionLabel =>
      isNational ? '전국' : (sigungu.isEmpty ? sido : '$sido $sigungu');

  factory Policy.fromJson(Map<String, dynamic> j) => Policy(
    id: j['id'] as String,
    name: j['name'] as String,
    agency: j['agency'] as String,
    sido: j['sido'] as String,
    sigungu: j['sigungu'] as String,
    eligibility: j['eligibility'] as String,
    url: j['url'] as String,
    category: PolicyCategory.fromCode(j['category'] as String),
    ageMin: (j['ageMin'] as num?)?.toInt(),
    ageMax: (j['ageMax'] as num?)?.toInt(),
    allowsEngaged: j['allowsEngaged'] as bool,
    marriedWithinYears: (j['marriedWithinYears'] as num?)?.toInt(),
    hasIncomeLimit: j['hasIncomeLimit'] as bool,
    requiresHomeless: j['requiresHomeless'] as bool,
    reviewed: j['reviewed'] as bool,
  );
}

import '../../data/models/policy.dart';
import '../../data/models/user_profile.dart';

export '../../data/models/user_profile.dart' show MarriageStage;

/// 정책 판정용 조건 (기기 안에서만 쓰고 외부로 보내지 않는다)
class PolicyProfile {
  const PolicyProfile({
    this.sido,
    this.age = 31,
    this.ageMax,
    this.stage = MarriageStage.engaged,
    this.marriedYears = 1,
    this.homeless,
  });

  /// 내 정보(또는 대화에서 알게 된 정보)로 만든다. 모르는 값은 기본값을 쓴다.
  factory PolicyProfile.fromUser(UserProfile u) => PolicyProfile(
        sido: u.sido,
        age: u.age ?? 31,
        ageMax: u.ageMax,
        stage: u.stage ?? MarriageStage.engaged,
        marriedYears: u.marriedYears ?? 1,
        homeless: u.homeless,
      );

  final String? sido; // null = 지역 미선택 (전국 정책만)
  final int age; // 정확한 나이 또는 범위의 최소
  final int? ageMax; // 범위로만 알 때 최대 (예: 20대 → 29)
  final MarriageStage stage;
  final int marriedYears; // 신혼부부일 때 혼인 N년차
  final bool? homeless; // 무주택 여부 (null = 모름)

  bool get isAgeRange => ageMax != null && ageMax != age;
  int get ageHigh => ageMax ?? age;

  PolicyProfile copyWith({
    String? sido,
    bool clearSido = false,
    int? age,
    MarriageStage? stage,
    int? marriedYears,
  }) =>
      PolicyProfile(
        sido: clearSido ? null : (sido ?? this.sido),
        age: age ?? this.age,
        ageMax: age != null ? null : ageMax, // 나이를 직접 고르면 정확한 나이로 본다
        stage: stage ?? this.stage,
        marriedYears: marriedYears ?? this.marriedYears,
        homeless: homeless,
      );
}

/// 판정 결과
enum MatchLevel { likely, check }

class PolicyMatch {
  const PolicyMatch(this.policy, this.level, this.reasons, this.checks);

  final Policy policy;
  final MatchLevel level;
  final List<String> reasons; // 해당되는 이유
  final List<String> checks; // 직접 확인해야 할 조건
}

/// 대상 여부는 AI가 아니라 이 규칙으로 판정한다.
/// 확실히 안 되는 정책만 빼고, 애매한 조건은 "확인 필요"로 남긴다.
class PolicyMatcher {
  static List<PolicyMatch> match(List<Policy> all, PolicyProfile p) {
    final result = <PolicyMatch>[];
    for (final policy in all) {
      final reasons = <String>[];
      final checks = <String>[];

      // 지역
      if (policy.isNational) {
        reasons.add('전국 대상');
      } else if (p.sido != null && policy.sido == p.sido) {
        reasons.add(policy.sigungu.isEmpty
            ? '${policy.sido} 거주'
            : '${policy.sido} ${policy.sigungu} 거주 시');
        if (policy.sigungu.isNotEmpty) checks.add('${policy.sigungu} 주민등록 필요');
      } else {
        continue;
      }

      // 나이: 내 나이(범위)와 정책 나이 조건이 전혀 안 겹칠 때만 제외
      if (policy.ageMax != null && p.age > policy.ageMax!) continue;
      if (policy.ageMin != null && p.ageHigh < policy.ageMin!) continue;
      if (policy.ageMax != null || policy.ageMin != null) {
        final range = '만 ${policy.ageMin ?? ''}~${policy.ageMax ?? ''}세';
        final fully = (policy.ageMin == null || p.age >= policy.ageMin!) &&
            (policy.ageMax == null || p.ageHigh <= policy.ageMax!);
        if (fully) {
          reasons.add('$range 조건 충족');
        } else {
          checks.add('$range 조건 (정확한 나이 확인)');
        }
      }

      // 혼인 상태
      if (p.stage == MarriageStage.married) {
        final within = policy.marriedWithinYears;
        if (within != null && p.marriedYears > within) continue;
        if (within != null) reasons.add('혼인 $within년 이내');
      } else {
        if (policy.allowsEngaged) {
          reasons.add('예비부부 신청 가능');
        } else if (policy.marriedWithinYears != null) {
          checks.add('혼인신고 후 신청');
        }
      }

      // 무주택
      if (policy.requiresHomeless) {
        if (p.homeless == false) continue;
        if (p.homeless == true) {
          reasons.add('무주택 조건 충족');
        } else {
          checks.add('무주택 여부');
        }
      }
      if (policy.hasIncomeLimit) checks.add('소득 기준');

      result.add(PolicyMatch(
        policy,
        checks.isEmpty ? MatchLevel.likely : MatchLevel.check,
        reasons,
        checks,
      ));
    }

    // 지역 정책 → 전국 정책, 그 안에서 확인할 조건이 적은 순
    result.sort((a, b) {
      final ra = a.policy.isNational ? 1 : 0;
      final rb = b.policy.isNational ? 1 : 0;
      if (ra != rb) return ra - rb;
      return a.checks.length - b.checks.length;
    });
    return result;
  }
}

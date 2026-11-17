import '../../../core/utils/region.dart';
import '../../../data/app_state.dart';
import '../../../data/models/policy.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/venue.dart';
import '../../../data/models/wedding_plan.dart';
import '../../../data/repositories/repositories.dart';
import '../../policy/policy_matcher.dart';

/// 데이터 조회 도구. 에이전트(규칙 또는 LLM)는 이 함수들의 결과로만 답한다.
/// 가격·자격·정원 같은 숫자는 전부 여기서 나온다 (AI가 만들어내지 않음).
class ConsultTools {
  ConsultTools._();

  /// 공공예식장: 하객 수 수용 → 무료 → 예약 가능 순. 정원을 모르는 곳은 뒤로, 확실히 작은 곳은 맨 뒤.
  static Future<List<Venue>> searchVenues({required String sido, int? guests}) async {
    final all = await Repos.venue.loadAll();
    int score(Venue v) =>
        (guests == null ? 0 : (v.fits(guests) == true ? 0 : (v.fits(guests) == null ? 4 : 8))) +
        (v.isFree ? 0 : 2) +
        (v.isLimited ? 1 : 0);
    return all.where((v) => sidoMatches(v.sido, sido)).toList()
      ..sort((a, b) => score(a).compareTo(score(b)));
  }

  /// 지원 정책: 규칙으로 대상 판정 + 분야로 거르기
  static Future<List<PolicyMatch>> matchPolicies(UserProfile who, {PolicyCategory? topic}) async {
    final all = await Repos.policy.loadAll();
    final matches = PolicyMatcher.match(all, PolicyProfile.fromUser(who));
    return topic == null ? matches : matches.where((m) => m.policy.category == topic).toList();
  }

  /// 시연용 업체: 항목 추천 예산 안 → 평점순
  static Future<(List<DemoVendor> picks, int inBudget, int total, int budget)> searchVendors({
    required VendorCategory item,
    required String sido,
    required int totalBudget,
    required int guests,
    bool cheapest = false, // true면 예상 비용이 낮은 순 ("더 싼 데")
  }) async {
    final budget = totalBudget * item.budgetShare ~/ 100;
    final all = (await Repos.vendor.demoVendors())
        .where((v) => v.sido == sido && v.category == item)
        .toList()
      ..sort((a, b) => cheapest
          ? a.estimate(guests: guests).compareTo(b.estimate(guests: guests))
          : b.rating.compareTo(a.rating));
    final fit = all.where((v) => v.estimate(guests: guests) <= budget).toList();
    return ((fit.isNotEmpty ? fit : all).take(3).toList(), fit.length, all.length, budget);
  }

  /// 예산 배분 (만원)
  static List<(VendorCategory, int)> budgetPlan(int totalBudget) {
    final items = VendorCategory.planItems.toList()..sort((a, b) => b.budgetShare.compareTo(a.budgetShare));
    return [for (final c in items) (c, totalBudget * c.budgetShare ~/ 100)];
  }

  /// 아직 안 한 할 일 (예식일 기준 순서)
  static List<ChecklistTask> nextTasks({int count = 4}) {
    final s = AppState.instance;
    return s.tasks.where((t) => !s.isTaskDone(t)).take(count).toList();
  }
}

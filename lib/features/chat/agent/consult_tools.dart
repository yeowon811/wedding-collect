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
  static Future<List<Venue>> searchVenues({required String sido, int? guests, String? sigungu}) async {
    final all = await Repos.venue.loadAll();
    // 내 시군구 예식장을 먼저 (그다음 하객 수용 · 무료 · 예약 가능 순)
    int score(Venue v) =>
        (sigungu == null || v.sigungu == sigungu ? 0 : 16) +
        (guests == null ? 0 : (v.fits(guests) == true ? 0 : (v.fits(guests) == null ? 4 : 8))) +
        (v.isFree ? 0 : 2) +
        (v.isLimited ? 1 : 0);
    // 같은 점수면 정원 큰 곳 → ID 순 (2026-11-20 7차: 실행마다 같은 카드·같은 순서가 되도록 순서를 끝까지 정함)
    return all.where((v) => sidoMatches(v.sido, sido)).toList()
      ..sort((a, b) {
        final s = score(a).compareTo(score(b));
        if (s != 0) return s;
        final c = (b.capacity ?? -1).compareTo(a.capacity ?? -1);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
  }

  /// 지원 정책: 규칙으로 대상 판정 + 분야로 거르기
  static Future<List<PolicyMatch>> matchPolicies(UserProfile who, {PolicyCategory? topic}) async {
    final all = await Repos.policy.loadAll();
    final matches = PolicyMatcher.match(all, PolicyProfile.fromUser(who));
    return topic == null ? matches : matches.where((m) => m.policy.category == topic).toList();
  }

  /// 시연용 업체: 준비 항목에 정한 예산이 있으면 예산 안 업체 먼저 → 평점순 (예산이 없으면 평점순만)
  static Future<(List<DemoVendor> picks, int inBudget, int total)> searchVendors({
    required VendorCategory item,
    required String sido,
    required int? budget,
    required int guests,
    bool cheapest = false, // true면 비용이 낮은 순 ("더 싼 데")
  }) async {
    final all = (await Repos.vendor.demoVendors())
        .where((v) => v.sido == sido && v.category == item)
        .toList()
      ..sort((a, b) => cheapest
          ? a.estimate(guests: guests).compareTo(b.estimate(guests: guests))
          : b.rating.compareTo(a.rating));
    if (budget == null) return (all.take(3).toList(), 0, all.length);
    final fit = all.where((v) => v.estimate(guests: guests) <= budget).toList();
    return ((fit.isNotEmpty ? fit : all).take(3).toList(), fit.length, all.length);
  }

  /// 아직 안 한 할 일 (예식일 기준 순서)
  static List<ChecklistTask> nextTasks({int count = 4}) {
    final s = AppState.instance;
    // 내 할 일이 비어 있으면 추천 할 일 목록(템플릿) 기준으로 안내
    final source = s.tasks.isEmpty ? kChecklistTasks : s.tasks;
    return source.where((t) => !s.isTaskDone(t)).take(count).toList();
  }
}

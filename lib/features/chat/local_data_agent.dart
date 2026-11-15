import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../core/utils/region.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/models/venue.dart';
import '../../data/models/wedding_plan.dart';
import '../../data/repositories/repositories.dart';
import '../policy/policy_detail_screen.dart';
import '../policy/policy_matcher.dart';
import '../vendor/demo_vendor_detail_screen.dart';
import '../venue/venue_detail_screen.dart';
import 'chat_agent.dart';

/// 앱 안의 데이터와 규칙으로 답하는 상담 (생성형 AI 연결 전 단계).
/// 질문에서 의도(예식장·정책·업체·예산·일정)를 찾고, 그에 맞는 데이터를 조회해 정리한다.
class LocalDataAgent implements ChatAgent {
  @override
  String get name => '앱 데이터 상담 (규칙 기반)';

  static const _categoryWords = <VendorCategory, List<String>>{
    VendorCategory.dress: ['드레스'],
    VendorCategory.meal: ['식대', '식사', '뷔페', '케이터링'],
    VendorCategory.studio: ['촬영', '스튜디오'],
    VendorCategory.snap: ['스냅'],
    VendorCategory.invitation: ['청첩장'],
    VendorCategory.props: ['부케', '케이크', '꽃'],
    VendorCategory.video: ['영상'],
    VendorCategory.suit: ['정장', '턱시도', '수트'],
    VendorCategory.hanbok: ['한복'],
    VendorCategory.parentMakeup: ['혼주'],
    VendorCategory.makeup: ['메이크업', '화장'],
  };

  AppState get _state => AppState.instance;

  @override
  Future<ChatMessage> reply(String q) async {
    final sido = kSidoList.firstWhere((s) => q.contains(s), orElse: () => _state.plan.sido);

    VendorCategory? category;
    for (final e in _categoryWords.entries) {
      if (e.value.any(q.contains)) {
        // '혼주 메이크업'은 메이크업보다 먼저 맞춘다
        category = e.key;
        if (e.key == VendorCategory.parentMakeup) break;
      }
    }

    if (_has(q, ['뭐부터', '순서', '할 일', '할일', '일정', '언제'])) return _timeline();
    if (_has(q, ['정책', '지원', '장려금', '대출', '혜택', '축하금'])) return _policies(q, sido);
    if (category != null) return _vendors(category, sido);
    if (_has(q, ['예식장', '식장', '공공', '대관'])) return _venues(sido);
    if (_has(q, ['예산', '얼마', '비용', '돈'])) return _budget();
    return _help();
  }

  bool _has(String q, List<String> words) => words.any(q.contains);

  ChatMessage _help() => ChatMessage(
        fromUser: false,
        text: '이런 걸 물어보실 수 있어요.\n'
            '• "${_state.plan.sido} 공공예식장 알려줘"\n'
            '• "받을 수 있는 정책 있어?"\n'
            '• "예산 안에서 드레스 추천해줘"\n'
            '• "예산 어떻게 나누면 돼?"\n'
            '• "뭐부터 해야 해?"\n\n'
            '지역은 체크리스트 탭의 결혼 정보(현재 ${_state.plan.sido})를 기준으로 하고, 질문에 지역을 넣으면 그 지역으로 찾아요.',
      );

  Future<ChatMessage> _venues(String sido) async {
    final all = await Repos.venue.loadAll();
    final guests = _state.plan.guests;
    // 하객 수를 수용하는 곳 → 무료 → 예약 가능 순. 정원을 모르는 곳은 그 뒤, 확실히 작은 곳은 맨 뒤
    int score(Venue v) =>
        (v.fits(guests) == true ? 0 : (v.fits(guests) == null ? 4 : 8)) +
        (v.isFree ? 0 : 2) +
        (v.isLimited ? 1 : 0);
    final list = all.where((v) => sidoMatches(v.sido, sido)).toList()
      ..sort((a, b) => score(a).compareTo(score(b)));
    if (list.isEmpty) {
      return ChatMessage(
        fromUser: false,
        text: '$sido에는 등록된 공공예식장이 없어요. 가까운 지역을 함께 찾아볼까요? (예: "경기 공공예식장")',
        sources: const ['전국 공공예식장 현황 (공유누리 등)'],
      );
    }
    final types = <String, int>{};
    for (final v in list) {
      types[v.bookingType.label] = (types[v.bookingType.label] ?? 0) + 1;
    }
    return ChatMessage(
      fromUser: false,
      text: '$sido 공공예식장은 ${list.length}곳이에요.\n'
          '신청 방법: ${types.entries.map((e) => '${e.key} ${e.value}곳').join(', ')}\n'
          '하객 $guests명 수용 확인 ${list.where((v) => v.fits(guests) == true).length}곳 · '
          '무료 대관 ${list.where((v) => v.isFree).length}곳 · '
          '정원 미확인 ${list.where((v) => v.capacity == null).length}곳\n\n'
          '하객 수를 수용하고 대관료가 무료인 곳부터 보여드릴게요. 정원·요금을 모르는 곳은 기관에 확인이 필요해요.',
      cards: [
        for (final v in list.take(3))
          ChatCard(
            title: v.name,
            subtitle: '${v.region} · ${v.capacityLabel} · ${v.feeLabel}',
            icon: Icons.location_city,
            badge: v.isLimited ? '기간 제한' : '예약 가능',
            open: () => VenueDetailScreen(venue: v),
          ),
      ],
      sources: const ['전국 공공예식장 현황 · 정원·요금·사진: 공유누리(eshare.go.kr) 수집'],
    );
  }

  Future<ChatMessage> _policies(String q, String sido) async {
    final ageMatch = RegExp(r'(\d{2})\s*(세|살)').firstMatch(q);
    final profile = PolicyProfile(
      sido: sido,
      age: ageMatch != null ? int.parse(ageMatch.group(1)!) : 31,
      stage: q.contains('신혼') || q.contains('혼인신고') ? MarriageStage.married : MarriageStage.engaged,
    );
    final matches = PolicyMatcher.match(await Repos.policy.loadAll(), profile);
    final likely = matches.where((m) => m.level == MatchLevel.likely).length;
    return ChatMessage(
      fromUser: false,
      text: '$sido · 만 ${profile.age}세 · ${profile.stage.label} 기준으로 ${matches.length}건을 찾았어요.\n'
          '그중 $likely건은 조건이 잘 맞고, 나머지는 소득·무주택 같은 조건을 직접 확인해야 해요.\n'
          '${ageMatch == null ? '(나이를 알려주시면 더 정확해요. 예: "29세 정책")\n' : ''}'
          '대상 여부는 규칙으로 판정했고, 최종 확인은 담당 기관에서 해 주세요.',
      cards: [
        for (final m in matches.take(3))
          ChatCard(
            title: m.policy.name,
            subtitle: '${m.policy.regionLabel} · ${m.policy.category.label}',
            icon: Icons.volunteer_activism,
            badge: m.level == MatchLevel.likely ? '해당 가능성 높음' : '조건 확인 필요',
            open: () => PolicyDetailScreen(match: m),
          ),
      ],
      sources: const ['청년 결혼 지원 정책 177건 (복지로·온통청년·지자체 공고)'],
    );
  }

  Future<ChatMessage> _vendors(VendorCategory c, String sido) async {
    final plan = _state.plan;
    final budget = plan.budgetFor(c);
    final all = (await Repos.vendor.demoVendors())
        .where((v) => v.sido == sido && v.category == c)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final inBudget = all.where((v) => v.estimate(guests: plan.guests) <= budget).toList();
    final pick = (inBudget.isNotEmpty ? inBudget : all).take(3).toList();
    return ChatMessage(
      fromUser: false,
      text: '총예산 ${formatManwon(plan.budget)} 중 ${c.label} 추천 예산은 $budget만원(${c.budgetShare}%)이에요.\n'
          '$sido ${c.label} 업체 ${all.length}곳 중 예산 안은 ${inBudget.length}곳이에요.'
          '${inBudget.isEmpty ? ' 예산 안 업체가 없어 평점순으로 보여드릴게요.' : ' 평점순으로 3곳 골랐어요.'}\n'
          '(가격·평점은 시연용 가상 데이터예요)',
      cards: [
        for (final v in pick)
          ChatCard(
            title: v.name,
            subtitle: '${v.priceText} · 예상 ${v.estimate(guests: plan.guests)}만원 · ★${v.rating}',
            icon: c.icon,
            badge: v.estimate(guests: plan.guests) <= budget ? '예산 안' : '예산 초과',
            open: () => DemoVendorDetailScreen(vendor: v),
          ),
      ],
      sources: const ['시연용 가상 업체 데이터'],
    );
  }

  ChatMessage _budget() {
    final plan = _state.plan;
    final items = VendorCategory.planItems.toList()
      ..sort((a, b) => b.budgetShare.compareTo(a.budgetShare));
    return ChatMessage(
      fromUser: false,
      text: '총예산 ${formatManwon(plan.budget)} · 하객 ${plan.guests}명 기준 추천 배분이에요.\n'
          '${items.map((c) => '• ${c.label} ${plan.budgetFor(c)}만원 (${c.budgetShare}%)').join('\n')}\n'
          '• 대관·기타 ${plan.budget * 5 ~/ 100}만원 (5%)\n\n'
          '공공예식장은 대관료가 무료이거나 저렴한 곳이 많아, 아낀 비용을 다른 항목에 쓸 수 있어요. '
          '계약 현황은 체크리스트 탭에서 볼 수 있어요.',
      sources: const ['앱 기본 배분 비율 (조정 가능)'],
    );
  }

  ChatMessage _timeline() {
    final plan = _state.plan;
    bool done(ChecklistTask t) =>
        _state.doneTasks.contains(t.id) ||
        (t.category != null && _state.statusOf(t.category!) == ItemStatus.contracted);
    final todo = kChecklistTasks.where((t) => !done(t)).take(4).toList();
    return ChatMessage(
      fromUser: false,
      text: '예식일 ${formatDate(plan.weddingDate)}까지 ${plan.dDay}일 남았어요. 지금 먼저 할 일이에요.\n'
          '${todo.map((t) => '• D-${t.dMinus} ${t.title}').join('\n')}\n\n'
          '체크리스트 탭에서 전체 순서와 진행 상태를 볼 수 있어요.',
      sources: const ['예식일 기준 체크리스트 템플릿'],
    );
  }
}

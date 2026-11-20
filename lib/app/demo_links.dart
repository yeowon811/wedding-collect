import 'package:flutter/material.dart';

import '../core/utils/region.dart';
import '../data/app_state.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/repositories.dart';
import '../features/checklist/task_calendar_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/policy/policy_detail_screen.dart';
import '../features/policy/policy_matcher.dart';
import '../features/vendor/demo_vendor_detail_screen.dart';
import '../features/venue/venue_detail_screen.dart';

/// 웹 주소로 시연 화면을 바로 여는 링크 (화면 캡처·시연 영상용, 앱 동작에는 영향 없음)
/// - `?demo=1`        : 가상 내 정보(서울 · 만 29세 · 예비부부 …)로 시작
/// - `?venue=H078`    : 예식장 상세
/// - `?vendor=<ID>`   : 시연용 업체 상세
/// - `?policy=<번호>` : 맞춤 정책 목록의 N번째 정책 상세 (0부터)
/// - `?page=favorites` / `calendar` : 찜 목록 / 할 일 캘린더
/// - `?tab=4&sido=서울&sigungu=강남구&guests=150&budget=3000&date=2027-05-15` : 파트너가 공유한 조건으로 AI 상담 (Red Team P2-1).
///   내 정보가 비어 있으면 바로 채우고, 이미 값이 있으면 덮어쓰지 않고 '공유받은 조건으로 바꿀까요?'를 묻는다 ([pendingShare])
class DemoLinks {
  DemoLinks._();

  static Map<String, String> get _q => Uri.base.queryParameters;

  /// 공유받은 조건 중 아직 적용하지 않은 것 (AI 상담 위쪽 안내 띠: [바꾸기] [그대로])
  static final pendingShare = ValueNotifier<UserProfile?>(null);

  /// 공유 링크의 조건 (지역·하객·총예산·예식일만, 이름·연락처는 없음). 값마다 검사하고, 하나도 없으면 null
  static UserProfile? sharedFrom(Map<String, String> q) {
    final sido = kSidoList.contains(q['sido']) ? q['sido'] : null;
    final town = sido != null && (kSigunguBySido[sido] ?? const <String>[]).contains(q['sigungu']) ? q['sigungu'] : null;
    int? num(String k, int min, int max) {
      final n = int.tryParse(q[k] ?? '');
      return n != null && n >= min && n <= max ? n : null;
    }

    // 날짜는 YYYY-MM-DD 그대로 맞는 날만 ('2027-13-40'처럼 넘치는 값은 DateTime이 다음 달로 넘겨 버리므로 버린다)
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(q['date'] ?? '');
    var d = m == null ? null : DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (d != null && (d.month != int.parse(m![2]!) || d.day != int.parse(m[3]!))) d = null;
    final p = UserProfile(
      sido: sido,
      sigungu: town,
      guests: num('guests', 1, 3000),
      budget: num('budget', 10, 100000),
      weddingDate: d == null ? null : DateTime(d.year, d.month, d.day),
    );
    return p.sido == null && p.guests == null && p.budget == null && p.weddingDate == null ? null : p;
  }

  /// 공유받은 조건 적용: 지금 내 정보에 그 칸 값이 하나라도 있으면(로그인한 사람의 저장된 정보 등) 묻고, 없으면 바로 채운다
  static void applyShared([Map<String, String>? query]) {
    final shared = sharedFrom(query ?? _q);
    if (shared == null) return;
    final app = AppState.instance;
    final mine = app.profile;
    final hasMine = mine.sido != null || mine.guests != null || mine.budget != null || mine.weddingDate != null;
    if (hasMine) {
      pendingShare.value = shared;
      return;
    }
    app.saveProfile(mine.merge(shared));
  }

  /// [바꾸기]: 공유받은 조건으로 (공유에 없는 내 값은 그대로)
  static void acceptShared() {
    final s = pendingShare.value;
    if (s == null) return;
    final app = AppState.instance;
    app.saveProfile(app.profile.merge(s), done: true);
    pendingShare.value = null;
  }

  static void keepMine() => pendingShare.value = null;

  /// 시연·캡처용 주소로 열었는지 (로그인 화면 없이 둘러보기로 시작)
  static bool get isDemoLink => const ['demo', 'tab', 'venue', 'vendor', 'policy', 'page'].any(_q.containsKey);

  /// 앱 시작 전에 적용 (내 정보)
  static void applyProfile() {
    if (_q['demo'] != '1') return;
    AppState.instance.saveProfile(UserProfile(
      sido: '서울',
      age: 29,
      stage: MarriageStage.engaged,
      weddingDate: DateTime.now().add(const Duration(days: 200)),
      guests: 150,
      budget: 3000,
      homeless: true,
    ));
    AppState.instance.loadRecommendedTasks();
  }

  /// 첫 화면이 뜬 뒤 상세 화면 열기
  static Future<void> openDetail(NavigatorState nav) async {
    Widget? page;
    if (_q['venue'] case final id?) {
      final v = (await Repos.venue.loadAll()).where((v) => v.id == id).firstOrNull;
      if (v != null) page = VenueDetailScreen(venue: v);
    } else if (_q['vendor'] case final id?) {
      final v = (await Repos.vendor.demoVendors()).where((v) => v.id == id).firstOrNull;
      if (v != null) page = DemoVendorDetailScreen(vendor: v);
    } else if (_q['policy'] case final n?) {
      final all = await Repos.policy.loadAll();
      final matches = PolicyMatcher.match(all, PolicyProfile.fromUser(AppState.instance.profile));
      final i = int.tryParse(n) ?? 0;
      if (i < matches.length) page = PolicyDetailScreen(match: matches[i]);
    } else if (_q['page'] == 'favorites') {
      page = const FavoritesScreen();
    } else if (_q['page'] == 'calendar') {
      page = const TaskCalendarScreen();
    }
    if (page != null && nav.mounted) {
      final p = page;
      nav.push(MaterialPageRoute(builder: (_) => p));
    }
  }
}

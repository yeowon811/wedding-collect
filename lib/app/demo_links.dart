import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/repositories.dart';
import '../features/policy/policy_detail_screen.dart';
import '../features/policy/policy_matcher.dart';
import '../features/vendor/demo_vendor_detail_screen.dart';
import '../features/venue/venue_detail_screen.dart';

/// 웹 주소로 시연 화면을 바로 여는 링크 (화면 캡처·시연 영상용, 앱 동작에는 영향 없음)
/// - `?demo=1`        : 가상 내 정보(서울 · 만 29세 · 예비부부 …)로 시작
/// - `?venue=H078`    : 예식장 상세
/// - `?vendor=<ID>`   : 시연용 업체 상세
/// - `?policy=<번호>` : 맞춤 정책 목록의 N번째 정책 상세 (0부터)
class DemoLinks {
  DemoLinks._();

  static Map<String, String> get _q => Uri.base.queryParameters;

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
    }
    if (page != null && nav.mounted) {
      final p = page;
      nav.push(MaterialPageRoute(builder: (_) => p));
    }
  }
}

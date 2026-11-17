import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/core/utils/region.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/data/user_data_codec.dart';
import 'package:wedding_collect/features/policy/policy_matcher.dart';

/// 거주 지역 시·군·구: 정책 판정, 내 정보 변경, 저장
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('정책 데이터의 시군구 이름은 모두 시군구 목록에 있다', () async {
    for (final p in await Repos.policy.loadAll()) {
      if (p.sigungu.isEmpty) continue;
      expect(kSigunguBySido[p.sido], contains(p.sigungu), reason: '${p.sido} ${p.sigungu}');
    }
  });

  test('시군구를 고르면 그 시군구 정책은 확인 없이, 다른 시군구 정책은 빠진다', () async {
    final all = await Repos.policy.loadAll();
    final local = all.where((p) => p.sido == '경기' && p.sigungu.isNotEmpty).toList();
    final mine = local.first;
    final other = local.firstWhere((p) => p.sigungu != mine.sigungu);

    // 시군구를 모르면: 경기의 시군구 정책이 모두 나오고 '주민등록 필요' 확인이 붙는다
    final noTown = PolicyMatcher.match(all, PolicyProfile.fromUser(const UserProfile(sido: '경기', age: 30)));
    expect(noTown.map((m) => m.policy.id), containsAll([mine.id, other.id]));
    expect(noTown.firstWhere((m) => m.policy.id == mine.id).checks, contains('${mine.sigungu} 주민등록 필요'));

    // 시군구를 알면: 내 시군구 정책은 확인 없이, 다른 시군구 정책은 빠진다
    final withTown =
        PolicyMatcher.match(all, PolicyProfile.fromUser(UserProfile(sido: '경기', sigungu: mine.sigungu, age: 30)));
    final m = withTown.firstWhere((m) => m.policy.id == mine.id);
    expect(m.checks.where((c) => c.contains('주민등록')), isEmpty);
    expect(m.reasons, contains('경기 ${mine.sigungu} 거주'));
    expect(withTown.any((m) => m.policy.id == other.id), isFalse);
  });

  test('시도를 바꾸면 시군구는 비워지고, 계정 저장 후 그대로 돌아온다', () async {
    const p = UserProfile(sido: '서울', sigungu: '강남구');
    expect(p.regionLabel, '서울 강남구');
    expect(p.copyWith(sido: '부산').sigungu, isNull);
    expect(p.copyWith(age: 30).sigungu, '강남구');
    expect(p.merge(const UserProfile(sido: '부산')).sigungu, isNull);

    final s = AppState.instance..resetAll();
    s.updateProfileDraft(p);
    final saved = jsonDecode(jsonEncode(UserDataCodec.encode(s))) as Map<String, dynamic>;
    s.resetAll();
    UserDataCodec.apply(s, saved, await Repos.vendor.demoVendors());
    expect(s.profile.regionLabel, '서울 강남구');
    // 체크리스트에서 지역(시도)을 바꾸면 시군구는 비워진다
    s.updatePlan(s.plan.copyWith(sido: '경기'));
    expect(s.profile.sido, '경기');
    expect(s.profile.sigungu, isNull);
    s.resetAll();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/models/policy.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/policy/policy_matcher.dart';

/// 2026-11-19 피드백: 결혼 단계는 고르지 않고 예식일로, 초혼·소득·신청 기한도 판정에 쓴다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime.now();
  DateTime daysAgo(int d) => DateTime(today.year, today.month, today.day - d);

  group('결혼 단계 = 예식일', () {
    test('예식 전이면 예비부부, 지나면 신혼부부 N년차', () {
      expect(UserProfile(weddingDate: daysAgo(-30)).stage, MarriageStage.engaged);
      final after = UserProfile(weddingDate: daysAgo(100));
      expect(after.stage, MarriageStage.married);
      expect(after.marriedYears, 1);
      expect(UserProfile(weddingDate: daysAgo(400)).marriedYears, 2);
      expect(const UserProfile().stage, isNull);
    });

    test('"혼인신고 했어요"(대화)는 예식 전이어도 신혼부부', () {
      final p = UserProfile(weddingDate: daysAgo(-60), stage: MarriageStage.married);
      expect(p.stage, MarriageStage.married);
    });
  });

  group('정책 판정', () {
    late List<Policy> all;
    setUpAll(() async => all = await Repos.policy.loadAll());
    Policy byId(String id) => all.firstWhere((p) => p.id == id);

    test('함양 신혼부부 결혼자금은 결혼 장려금 분야', () {
      expect(byId('P167').category, PolicyCategory.cash);
      expect(byId('P167').firstMarriage, 'one');
    });

    test('초혼: 둘 다 재혼이면 초혼 조건 정책은 대상 아님 (이유 표시)', () {
      final p = PolicyProfile.fromUser(UserProfile(
          sido: '경남', sigungu: '함양군', age: 30, weddingDate: daysAgo(60), firstMarriage: FirstMarriage.none));
      final r = PolicyMatcher.judge([byId('P167')], p);
      expect(r.matches, isEmpty);
      expect(r.misses.single.reason, contains('초혼'));
      final ok = PolicyMatcher.judge(
          [byId('P167')], PolicyProfile.fromUser(UserProfile(sido: '경남', sigungu: '함양군', age: 30, weddingDate: daysAgo(60), firstMarriage: FirstMarriage.one)));
      expect(ok.matches.single.reasons.join(), contains('초혼 충족'));
    });

    test('신혼부부 연차가 정책의 혼인 N년 이내를 넘으면 대상 아님', () {
      final within1 = all.firstWhere((p) => p.marriedWithinYears == 1);
      final old = PolicyProfile.fromUser(UserProfile(sido: within1.isNational ? null : within1.sido,
          sigungu: within1.sigungu.isEmpty ? null : within1.sigungu, age: 30, weddingDate: daysAgo(500)));
      expect(PolicyMatcher.judge([within1], old).misses.single.reason, contains('혼인 1년 이내'));
    });

    test('예비부부: 혼인신고 후 N년 이내 신청 기한을 예식일 기준으로 안내', () {
      final p = all.firstWhere((x) => !x.allowsEngaged && x.marriedWithinYears != null && x.isNational);
      final w = DateTime(today.year + 1, 4, 10);
      final m = PolicyMatcher.judge([p], PolicyProfile.fromUser(UserProfile(age: 30, weddingDate: w))).matches.single;
      expect(m.checks.join(), contains('혼인신고 후 ${p.marriedWithinYears}년 이내 신청'));
      expect(m.checks.join(), contains('${w.year + p.marriedWithinYears!}.4까지'));
    });

    test('소득: 원문 상한보다 많으면 대상 아님, 모르면 확인 필요', () {
      final capped = all.firstWhere((p) => p.isNational && p.hasIncomeLimit && RegExp(r'\d').hasMatch(p.eligibility) &&
          PolicyMatcher.judge([p], const PolicyProfile(age: 30, income: 100000)).misses.isNotEmpty);
      expect(PolicyMatcher.judge([capped], const PolicyProfile(age: 30, income: 100000)).misses.single.reason, contains('이하 대상'));
      expect(PolicyMatcher.judge([capped], const PolicyProfile(age: 30)).matches.single.checks, contains('소득 기준'));
    });
  });
}

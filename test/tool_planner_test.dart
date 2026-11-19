import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/models/policy.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/features/chat/agent/tool_planner.dart';

/// 새 구조: Gemini가 고른 도구·조건을 앱이 검사한다 (잘못된 이름·날짜·숫자는 버림)
void main() {
  final next = DateTime.now().year + 1;

  test('예식장 검색: 구 여러 개·제외·정렬·기간을 검사해서 읽는다', () {
    final p = ToolPlanner.parse('search_venues', {
      'sido': ['서울', '없는시도'],
      'sigungu': ['강남구', '송파', '아무구'],
      'exclude_sigungu': ['마포구'],
      'free_only': true,
      'sort': 'capacity_high',
      'date_from': '$next-03-01',
      'date_to': '$next-03-31',
      'weekdays': ['sat'],
    })!;
    final q = p.venue!;
    expect(q.sidos, ['서울']);
    expect(q.towns, ['강남구', '송파구']);
    expect(q.excludeTowns, ['마포구']);
    expect(q.freeOnly, isTrue);
    expect(q.sort, 'capacity_high');
    expect(q.hasPeriod, isTrue);
    expect(q.weekdays, [DateTime.saturday]);
  });

  test('잘못된 값은 버린다: 지난 날짜, 거꾸로 된 기간, 범위 밖 숫자, 모르는 도구', () {
    final q = ToolPlanner.parse('search_venues', {
      'date': '2020-01-01',
      'date_from': '$next-05-01',
      'date_to': '$next-04-01',
      'guests': 99999,
      'sort': 'random',
    })!.venue!;
    expect(q.date, isNull);
    expect(q.hasPeriod, isFalse);
    expect(q.guests, isNull);
    expect(q.sort, 'default');
    expect(ToolPlanner.parse('delete_everything', {}), isNull);
  });

  test('자기 이야기(user_facts)와 찾는 조건을 나눈다', () {
    final p = ToolPlanner.parse('search_policies', {
      'topic': 'wedding',
      'target_sido': '서울',
      'user_facts': {'lives_sido': '경기', 'age': 34, 'first_marriage': 'one', 'registered_marriage': true},
    })!;
    expect(p.targetSido, '서울');
    expect(p.topic, PolicyCategory.wedding);
    expect(p.self.livesGiven, isTrue);
    expect(p.self.profile.sido, '경기');
    expect(p.self.profile.age, 34);
    expect(p.self.profile.firstMarriage, FirstMarriage.one);
    expect(p.self.profile.stageInput, MarriageStage.married);
    // 찾는 조건만 있으면 사는 곳으로 보지 않는다
    expect(ToolPlanner.parse('search_venues', {'sido': ['부산']})!.self.livesGiven, isFalse);
  });

  test('후속 질문: 앞 조건과 앱이 합친다 (새 조건 우선, remove는 뺌)', () {
    final prev = {'sido': ['서울'], 'sigungu': ['강남구', '송파구']};
    final free = ToolPlanner.refine(ToolPlanner.parse('search_venues', {'refine_previous': true, 'free_only': true})!, prev);
    expect(free.venue!.towns, ['강남구', '송파구']);
    expect(free.venue!.freeOnly, isTrue);
    final big = ToolPlanner.refine(ToolPlanner.parse('search_venues', {'refine_previous': true, 'sort': 'capacity_high'})!, free.args);
    expect(big.venue!.towns, ['강남구', '송파구']);
    expect(big.venue!.freeOnly, isTrue);
    expect(big.venue!.sort, 'capacity_high');
    final wide = ToolPlanner.refine(
        ToolPlanner.parse('search_venues', {'refine_previous': true, 'remove': ['sigungu']})!, big.args);
    expect(wide.venue!.towns, isEmpty);
    expect(wide.venue!.freeOnly, isTrue);
  });

  test('자기 이야기는 질문에 그 말이 있을 때만 남긴다', () {
    final p = ToolPlanner.parse('search_venues', {
      'user_facts': {'first_marriage': 'both', 'guests': 200, 'lives_sido': '경기'},
    })!;
    final g = ToolPlanner.grounded(p.self, '예식장 추천해줘');
    expect(g.profile.firstMarriage, isNull);
    expect(g.profile.guests, isNull);
    expect(g.livesGiven, isFalse);
    final g2 = ToolPlanner.grounded(p.self, '저 수원 살아요. 하객 200명이에요');
    expect(g2.profile.guests, 200);
    expect(g2.livesGiven, isTrue);
  });

  test('업체 항목·계산·일정', () {
    final v = ToolPlanner.parse('search_vendors', {'items': ['studio', 'dress', 'makeup', 'nope'], 'budget_manwon': 200})!;
    expect(v.items, [VendorCategory.studio, VendorCategory.dress, VendorCategory.makeup]);
    expect(v.itemBudget, 200);
    expect(ToolPlanner.parse('calculate', {'until_date': '$next-04-10'})!.untilDate, DateTime(next, 4, 10));
    expect(ToolPlanner.parse('wedding_schedule', {'months_left': 6})!.monthsLeft, 6);
  });
}

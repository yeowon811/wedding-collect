import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/features/chat/agent/tool_planner.dart';

/// 2026-11-21 전체 평가에서 틀린 것 고친 확인 (Gemini 없이)
void main() {
  group('후속 질문의 지역 조건 (B4)', () {
    final prev = <String, Object?>{
      'sido': ['서울'],
      'sigungu': ['송파구'],
      'exclude_sigungu': ['강남구'],
    };

    test('"그중에 주차 넓은 곳"에 Gemini가 구 조건을 지우라고 해도 송파구를 지킨다', () {
      final p = ToolPlanner.parse('search_venues', {
        'needs': ['parking'],
        'refine_previous': true,
        'remove': ['sigungu', 'exclude_sigungu'],
      })!;
      final r = ToolPlanner.refine(p, prev, question: '그중에 주차 넓은 곳');
      expect(r.venue!.towns, ['송파구']);
      expect(r.venue!.excludeTowns, ['강남구']);
      expect(r.venue!.needs, ['parking']);
    });

    test('질문이 넓혀 달라고 하면 구 조건을 지운다', () {
      final p = ToolPlanner.parse('search_venues', {
        'refine_previous': true,
        'remove': ['sigungu'],
      })!;
      final r = ToolPlanner.refine(p, prev, question: '서울 전체로 보여줘');
      expect(r.venue!.towns, isEmpty);
    });
  });

  test('장소·검색어 도구는 장소·검색어를 계획에 담는다 (X07·E4)', () {
    final near = ToolPlanner.parse('near_place', {'place': '삼성역'})!;
    expect(near.place, '삼성역');
    final web = ToolPlanner.parse('web_lookup', {'query': '더 아름다운 결혼식 신청 기간'})!;
    expect(web.query, '더 아름다운 결혼식 신청 기간');
  });
}

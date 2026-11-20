import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_checks.dart';

/// 기본 틀(Gemini 없음) 블록 답을 글로 찍어 본다: flutter test test/eval/blocks_dump.dart
/// 공통 가정: 서울 강남구 · 만 29세 · 예식일 2027-05-15 · 하객 120명 · 무주택 · 예산 3,000만원
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('dump', () async {
    await Repos.venue.loadAll();
    await Repos.booking.loadAll();
    AppState.instance.saveProfile(UserProfile(
        sido: '서울', sigungu: '강남구', age: 29, guests: 120, homeless: true, budget: 3000, weddingDate: DateTime(2027, 5, 15)));
    const scenarios = [
      ['공공예식장 추천해줘', '#송파·서초까지'],
      ['강남구, 송파구의 예식장만'],
      ['강남구 말고 송파구', '그중에 주차 넓은 곳'],
      ['부산 무료 예식장'],
      ['대전 공공예식장 알려줘'],
      ['마루공원 몇 명까지 돼?'],
      ['2027년 5월 15일에 강남구 예식장 예약 돼?'],
      ['내년 5월 토요일 비어 있는 날 많은 곳'],
      ['SETEC 컨벤션홀 알려줘'],
      ['SETEC이랑 서울주택도시개발공사 비교'],
      ['받을 수 있는 정책 알려줘'],
      ['부부 합쳐 연봉 8천인데 신혼부부 전세대출 돼?'],
      ['스드메 보통 얼마 들어?'],
      ['드레스 업체 추천해줘'],
      ['식대 1인 6만5천원, 150명이면?'],
      ['뭐부터 해야 해?'],
      ['오늘 날씨 어때?'],
      ['저 수원 살고 하객은 100명 정도예요'],
    ];
    for (final sc in scenarios) {
      final agent = ConsultAgent();
      var m = await agent.start();
      for (final q in sc) {
        if (q.startsWith('#')) {
          final r = m.quickReplies.where((r) => r.label == q.substring(1)).firstOrNull;
          if (r == null) {
            // ignore: avoid_print
            print('  (칩 없음: ${q.substring(1)} / 있는 칩: ${m.quickReplies.map((r) => r.label).join(', ')})');
            continue;
          }
          m = await agent.choose(r);
        } else {
          m = await agent.reply(q);
        }
        final issues = AnswerChecks.format(m.blocks, agent.lastFacts!);
        // ignore: avoid_print
        print('\n### $q  [${agent.lastComposed?.path}]${issues.isEmpty ? '' : '  K5: ${issues.join(' / ')}'}\n'
            '${m.blocks.plainText}\n'
            '칩: ${m.quickReplies.map((r) => r.label).join(' | ')}');
      }
    }
    AppState.instance.resetProfile();
  });
}

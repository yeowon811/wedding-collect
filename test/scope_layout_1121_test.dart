import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/repositories/consumer_prices.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/tool_planner.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_view.dart';
import 'package:wedding_collect/features/chat/mini_form_card.dart';

/// 2026-11-21 휴대폰 피드백: ① 앱 데이터 밖 질문("사설 예식장")에 공공예식장 목록으로 답함 ② 좁은 화면에서 버튼이 카드 밖으로
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('앱 데이터 밖 예식장 질문', () {
    test('사설·호텔·일반 웨딩홀을 찾는 질문을 알아본다', () {
      expect(ToolPlanner.outOfScopeVenue('서울시 내 사설 예식장 몇 개 좀 추려줘'), '사설');
      expect(ToolPlanner.outOfScopeVenue('강남 호텔 웨딩 추천해줘'), '호텔 웨딩');
      expect(ToolPlanner.outOfScopeVenue('부산 일반 웨딩홀 어디 있어?'), '일반 웨딩홀');
    });

    test('"검색해줘"·"정보"·외부 결혼식장 표현도 알아본다 (11-21 빈틈)', () {
      expect(ToolPlanner.outOfScopeVenue('외부 사설 결혼식장에 대해서 검색해줘'), '사설');
      expect(ToolPlanner.outOfScopeVenue('사설 결혼식장 정보 알려줘'), '사설');
      expect(ToolPlanner.outOfScopeVenue('호텔 웨딩 어때?'), '호텔 웨딩');
      expect(ToolPlanner.outOfScopeVenue('외부 예식장 찾아줘'), '외부 예식장');
    });

    test('공공예식장 질문·일반 웨딩홀과 비용 비교는 그대로 앱 데이터로', () {
      expect(ToolPlanner.outOfScopeVenue('서울 공공예식장 추천해줘'), isNull);
      expect(ToolPlanner.outOfScopeVenue('공공예식장이 일반 웨딩홀보다 얼마나 싸?'), isNull);
      expect(ToolPlanner.outOfScopeVenue('일반 웨딩홀 평균 식대 알려줘'), isNull);
      expect(ToolPlanner.outOfScopeVenue('SETEC 컨벤션홀 주차 돼?'), isNull);
    });

    group('Gemini 없이', () {
      setUp(() => AppState.instance.saveProfile(const UserProfile(sido: '서울', sigungu: '강남구', age: 29)));
      tearDown(() => AppState.instance.resetProfile());

      test('하객 수를 되묻거나 공공예식장 목록을 내놓지 않고, 앱 데이터 범위를 안내한다', () async {
        final m = await ConsultAgent().reply('서울시 내 사설 예식장 몇 개 좀 추려줘');
        expect(m.isQuestion, isFalse);
        expect(m.cards, isEmpty);
        expect(m.text, contains('공공예식장 240곳 데이터만'));
        final all = m.blocks.copyText;
        expect(all, isNot(contains('74곳')));
        expect(m.blocks.where((b) => b.type == BlockType.notice).map((b) => b.text).join(), contains('사설 예식장은 웹 검색'));
        expect(m.quickReplies.map((r) => r.label), contains('서울 공공예식장 보기'));
      });
    });
  });

  group('결혼 준비와 관계없는 질문 막기 (11-21)', () {
    test('주식·날씨·코딩·연예·정치는 막는다', () {
      for (final q in ['오늘 무슨 주식 사야 돼?', '내일 서울 날씨 어때?', '파이썬 코드 짜줘', '요즘 인기 아이돌 누구야?',
          '대통령 선거 언제야?', '비트코인 시세 검색해줘', '로또 번호 추천해줘']) {
        expect(ToolPlanner.offTopic(q), isTrue, reason: q);
      }
    });

    test('결혼 관련 말이 있으면 막지 않는다', () {
      for (final q in ['신혼여행지 날씨 어때?', '상견례 맛집 추천해줘', '결혼자금 주식으로 모아도 돼?', '예식일 미세먼지 걱정돼',
          '공공예식장 추천해줘', '받을 수 있는 정책 알려줘', '축의금 얼마가 적당해?']) {
        expect(ToolPlanner.offTopic(q), isFalse, reason: q);
      }
    });

    test('막힌 질문은 Gemini·검색 없이 범위 안내 + 결혼 준비 버튼', () async {
      final m = await ConsultAgent().reply('오늘 무슨 주식 사야 돼?');
      expect(m.text, contains('결혼 준비'));
      expect(m.text, contains('답하지 않아요'));
      expect(m.cards, isEmpty);
      expect(m.blocks.firstWhere((b) => b.type == BlockType.headline).title, '결혼 준비 질문만 도와드려요');
      expect(m.quickReplies.map((r) => r.label), contains('공공예식장 추천'));
    });

    test('Gemini 도구 고르기에 off_topic이 있다', () {
      expect(ToolPlanner.tools, contains('off_topic'));
      expect(ToolPlanner.parse('off_topic', {})!.tool, 'off_topic');
    });
  });

  group('공공 vs 일반 예식장 금액 비교 (한국소비자원 참가격)', () {
    test('비교 질문을 알아본다', () {
      expect(ToolPlanner.costCompare('혹시 그러면 서울 공공예식장과 금액적인 부분에서 비교가 가능한가?'), isTrue);
      expect(ToolPlanner.costCompare('한국 소비자원 데이터를 가져와서 비교해줄 수 있을까?'), isTrue);
      expect(ToolPlanner.costCompare('공공예식장이 일반 웨딩홀보다 얼마나 싸?'), isTrue);
      // 비교 말이 없는 비용 질문·목록 질문은 기존 도구로
      expect(ToolPlanner.costCompare('공공예식장 대관료 말고 실제로 총 얼마 들어?'), isFalse);
      expect(ToolPlanner.costCompare('서울 공공예식장 추천해줘'), isFalse);
    });

    group('Gemini 없이', () {
      setUp(() => AppState.instance.saveProfile(const UserProfile(sido: '서울', sigungu: '송파구', guests: 150)));
      tearDown(() => AppState.instance.resetProfile());

      test('서울: 공공 실제 대관료와 소비자원 서울(강남 외) 중간값을 표로', () async {
        final m = await ConsultAgent().reply('서울 공공예식장과 금액적인 부분에서 비교가 가능한가?');
        final table = m.blocks.firstWhere((b) => b.type == BlockType.table);
        expect(table.columns, ['항목', '서울 공공예식장', '서울(강남 외) 일반']);
        final rental = table.rows.firstWhere((r) => r[0] == '대관료');
        expect(rental[1], startsWith('무료 '));
        expect(rental[2], '중간 580만원'); // 참가격 2026년 9월 서울(강남외) 대관비용 중간값
        expect(table.rows.firstWhere((r) => r[0] == '1인당 식대')[2], '중간 7.6만원');
        expect(m.sources.first, contains('2026년 9월'));
        expect(m.text, isNot(contains('일반 안내')));
      });

      test('소비자원 데이터 질문은 앞 답을 다시 쓰지 않고 같은 표로 답한다', () async {
        final agent = ConsultAgent();
        await agent.reply('서울 공공예식장과 금액적인 부분에서 비교가 가능한가?');
        final m = await agent.reply('한국 소비자원 데이터를 가져와서 비교해줄 수 있을까?');
        expect(m.blocks.any((b) => b.type == BlockType.table), isTrue);
        expect(m.sources.first, contains('한국소비자원'));
      });
    });

    test('강남구는 서울(강남), 경남은 경상도 조사값', () {
      expect(ConsumerPrices.regionKey('서울', sigungu: '강남구'), '서울(강남)');
      expect(ConsumerPrices.regionKey('서울', sigungu: '마포구'), '서울(강남외)');
      expect(ConsumerPrices.regionKey('경남'), '경상도');
      expect(ConsumerPrices.regionKey('광주·전남'), '전남광주');
      expect(ConsumerPrices.regionKey(null), '전국');
    });
  });

  group('좁은 휴대폰 화면 (카드 폭 290)', () {
    Future<void> pumpNarrow(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: Center(child: SizedBox(width: 290, child: child))),
        ),
      ));
      await tester.pump();
    }

    testWidgets('미니 폼 버튼이 카드 밖으로 넘치지 않는다', (tester) async {
      await pumpNarrow(
        tester,
        MiniFormCard(slots: const ['age', 'stage', 'homeless'], initial: const UserProfile(), onSubmit: (_) {}),
      );
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(MiniFormCard));
      final button = tester.getRect(find.widgetWithText(FilledButton, '조건 적용하고 결과 보기'));
      expect(button.right, lessThanOrEqualTo(card.right));
      expect(find.text('잘 모르겠어요'), findsOneWidget);
    });

    testWidgets('접힌 줄 + 공유·복사 버튼이 한 줄에 들어간다', (tester) async {
      await pumpNarrow(
        tester,
        AnswerView(
          blocks: [
            AnswerBlock(BlockType.headline, title: '서울 공공예식장 3곳'),
            AnswerBlock(BlockType.fold, sources: ['전국 공공예식장 현황']),
          ],
          footer: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton.icon(onPressed: () {}, icon: const Icon(Icons.ios_share_rounded, size: 16), label: const Text('공유')),
            const CopyAnswerButton(text: 'x'),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      final copy = tester.getRect(find.byType(CopyAnswerButton));
      expect(copy.right, lessThanOrEqualTo(tester.getRect(find.byType(AnswerView)).right));
    });
  });
}

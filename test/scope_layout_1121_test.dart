import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_view.dart';

/// 2026-11-20 답 복사: 복사용 글 만들기 + 복사 버튼 (클립보드 · "답변을 복사했어요")
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const blocks = [
    AnswerBlock(BlockType.headline, title: '강남구 공공예식장 4곳', badges: [BlockBadge('모두 무료', Tone.good), BlockBadge('120명 가능 2곳', Tone.good)]),
    AnswerBlock(BlockType.text, text: '사시는 강남구부터 찾았어요.'),
    AnswerBlock(BlockType.filters, filters: [FilterChipData('강남구', remove: 'sigungu')]),
    AnswerBlock(BlockType.cards, cards: [
      BlockCard(
          ref: 'venue:H080',
          title: '서울주택도시개발공사(대강당홀)',
          badge: BlockBadge('120명 OK', Tone.good),
          values: ['강남구', '100~400명', '무료'],
          reason: '정원이 가장 큼 (400명)'),
      BlockCard(
          ref: 'venue:H079',
          title: '마루공원',
          badge: BlockBadge('정원 문의 필요', Tone.check),
          values: ['강남구', '무료'],
          contact: '☎ 02-2133-6546'),
    ]),
    AnswerBlock(BlockType.table, columns: ['', 'A', 'B'], rows: [
      ['정원', '100~400명', '100~200명'],
    ]),
    AnswerBlock(BlockType.steps, items: ['예식장 신청', '스드메 상담']),
    AnswerBlock(BlockType.next, items: ['서울 전체', '1곳 더 보기']),
    AnswerBlock(BlockType.fold, sources: ['전국 공공예식장 현황', '예약 달력 11/19'], log: ['앱 검사 통과'], detail: '긴 예전 글'),
  ];

  const expected = '강남구 공공예식장 4곳 (모두 무료 · 120명 가능 2곳)\n'
      '사시는 강남구부터 찾았어요.\n'
      '서울주택도시개발공사(대강당홀) — 강남구 · 100~400명 · 무료 (120명 OK) · 정원이 가장 큼 (400명)\n'
      '마루공원 — 강남구 · 무료 (정원 문의 필요) · 문의 ☎ 02-2133-6546\n'
      'A | B\n'
      '정원: 100~400명 | 100~200명\n'
      '1. 예식장 신청\n'
      '2. 스드메 상담\n'
      '출처: 전국 공공예식장 현황 · 예약 달력 11/19';

  test('복사용 글: 제목(배지)·설명·카드·표·단계·출처, 칩·조건 칩·접힌 기록은 뺌', () {
    expect(blocks.copyText, expected);
    expect(blocks.copyText, isNot(contains('서울 전체')));
    expect(blocks.copyText, isNot(contains('앱 검사')));
    expect(blocks.copyText, isNot(contains('긴 예전 글')));
  });

  testWidgets('복사 버튼: 클립보드에 넣고 "답변을 복사했어요"', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SelectionArea(child: AnswerView(blocks: blocks, footer: CopyAnswerButton(text: blocks.copyText))),
        ),
      ),
    ));
    await tester.tap(find.byTooltip('답변 복사'));
    await tester.pump();
    expect(copied, expected);
    expect(find.text('답변을 복사했어요'), findsOneWidget);
    // 브라우저가 클립보드를 막으면 직접 고르는 방법을 알려 준다
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') throw PlatformException(code: 'copy_fail');
      return null;
    });
    await tester.tap(find.byTooltip('답변 복사'));
    await tester.pump();
    expect(find.textContaining('복사 버튼이 막혀 있어요'), findsOneWidget);
    // 접힌 줄은 그대로 열린다 (선택 영역 안에서도 버튼 동작). 내부 기록(log)은 화면에 보이지 않는다 (Red Team P1-3)
    await tester.tap(find.text('출처 보기 · 어떻게 찾았나요'));
    await tester.pump();
    expect(find.text('출처'), findsOneWidget);
    expect(find.text('자세한 설명'), findsOneWidget);
    expect(find.textContaining('앱 검사'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/app/demo_links.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_view.dart';
import 'package:wedding_collect/features/chat/chat_agent.dart';
import 'package:wedding_collect/features/chat/chat_screen.dart';
import 'package:wedding_collect/features/chat/mini_form_card.dart';
import 'package:wedding_collect/features/chat/share_summary.dart';

/// Red Team Phase 3 (P2, 2026-11-20): 파트너에게 공유 · 채팅 안 미니 폼 · 카드에서 바로 담기
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final app = AppState.instance;

  setUpAll(() async {
    await Repos.venue.loadAll();
    await Repos.policy.loadAll();
    await Repos.booking.loadAll();
  });
  tearDown(() {
    app.resetProfile();
    DemoLinks.pendingShare.value = null;
  });

  group('P2-1 파트너에게 공유', () {
    final me = UserProfile(sido: '서울', sigungu: '강남구', age: 29, guests: 150, budget: 3000, weddingDate: DateTime(2027, 5, 15));

    test('링크: 지역·하객·총예산·예식일만 담고, 열면 같은 조건이 된다', () {
      final link = ShareSummary.link(me, origin: 'https://wedding-collect.web.app');
      final q = Uri.parse(link).queryParameters;
      expect(q, {'tab': '4', 'sido': '서울', 'sigungu': '강남구', 'guests': '150', 'budget': '3000', 'date': '2027-05-15'});
      expect(q.containsKey('age'), isFalse); // 공유 조건에 나이는 없음
      final back = DemoLinks.sharedFrom(q)!;
      expect([back.sido, back.sigungu, back.guests, back.budget, back.weddingDate], ['서울', '강남구', 150, 3000, DateTime(2027, 5, 15)]);
    });

    test('잘못된 값은 버린다', () {
      final p = DemoLinks.sharedFrom({'sido': '서울시', 'sigungu': '강남구', 'guests': '99999', 'budget': 'abc', 'date': '2027-13-40'});
      expect(p, isNull);
      expect(DemoLinks.sharedFrom({'sido': '부산', 'sigungu': '강남구'})!.sigungu, isNull); // 부산에 강남구는 없음
    });

    test('내 정보가 비어 있으면 바로 채우고, 있으면 덮어쓰지 않고 묻는다', () {
      app.resetProfile();
      DemoLinks.applyShared({'tab': '4', 'sido': '부산', 'guests': '80'});
      expect(app.profile.sido, '부산');
      expect(app.profile.guests, 80);
      expect(app.profileDone, isTrue);
      expect(DemoLinks.pendingShare.value, isNull);

      app.saveProfile(const UserProfile(sido: '서울', guests: 150, age: 30));
      DemoLinks.applyShared({'tab': '4', 'sido': '부산', 'budget': '2000'});
      expect(app.profile.sido, '서울'); // 그대로
      expect(DemoLinks.pendingShare.value!.sido, '부산');
      DemoLinks.keepMine();
      expect(DemoLinks.pendingShare.value, isNull);
      expect(app.profile.sido, '서울');

      DemoLinks.applyShared({'tab': '4', 'sido': '부산', 'budget': '2000'});
      DemoLinks.acceptShared();
      expect(app.profile.sido, '부산');
      expect(app.profile.budget, 2000);
      expect(app.profile.guests, 150); // 공유에 없는 내 값은 그대로
      expect(app.profile.age, 30);
    });

    test('요약 글: 내 조건 + 추천 TOP 3 + 예상 비용 줄 + 링크 (개인정보 없음)', () async {
      app.saveProfile(me);
      final m = await ConsultAgent().reply('공공예식장 추천해줘');
      final text = ShareSummary.build(me, [const ChatMessage(fromUser: true, text: '공공예식장 추천해줘'), m],
          origin: 'https://wedding-collect.web.app');
      expect(text, startsWith('[We Connect 결혼 준비 상담 요약]'));
      expect(text, contains('내 조건: 서울 강남구 · 하객 150명 · 총예산 3,000만원 · 예식일 2027.5.15'));
      expect(text, contains('추천 TOP'));
      expect(text, contains('1. ${m.blocks.allCards.first.title}'));
      expect(text, contains('참고 단가표 추정'));
      expect(text, contains('https://wedding-collect.web.app/?tab=4'));
      expect(text, isNot(contains('만 29세'))); // 나이·연락처는 넣지 않음
    });

    testWidgets('헤더 [공유] → 클립보드 + "카카오톡 공유용 상담 요약이 복사되었어요"', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      app.saveProfile(me);
      await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.tap(find.byTooltip('파트너에게 공유'));
      await tester.pump();
      expect(copied, contains('내 조건: 서울 강남구'));
      expect(find.text('카카오톡 공유용 상담 요약이 복사되었어요'), findsOneWidget);
      app.clearChat();
    });
  });

  group('P2-2 채팅 안 미니 폼', () {
    test('정책 질문에 조건이 여러 개 비면 폼 한 장 → 제출하면 내 정보에 저장하고 바로 답', () async {
      app.saveProfile(const UserProfile());
      final agent = ConsultAgent();
      final ask = await agent.reply('받을 수 있는 정책 알려줘');
      expect(ask.isQuestion, isTrue);
      expect(ask.form, containsAll(['region', 'age', 'stage', 'homeless']));
      expect(ask.blocks.headline, '조건을 한 번에 골라 주세요');

      final done = await agent.choose(const QuickReply('서울 · 만 29세 · 예비부부 · 무주택', action: 'form', value: {
        'sido': '서울',
        'age': 29,
        'stage': 'engaged',
        'homeless': true,
        'slots': ['region', 'age', 'stage', 'homeless'],
      }));
      expect(done.isQuestion, isFalse);
      expect(done.form, isEmpty);
      expect(done.blocks.allCards.first.ref, startsWith('policy:'));
      // 같은 자기 정보 경로: 위쪽 조건 칩(내 정보)에 바로 보인다
      expect(app.profile.sido, '서울');
      expect(app.profile.age, 29);
      expect(app.profile.homeless, isTrue);
      expect(done.blocks.any((b) => b.type == BlockType.notice && (b.text ?? '').contains('내 정보에 반영')), isTrue);
    });

    test('[잘 모르겠어요]는 비운 칸을 건너뛰고 다시 묻지 않는다', () async {
      app.saveProfile(const UserProfile());
      final agent = ConsultAgent();
      await agent.reply('받을 수 있는 정책 알려줘');
      final m = await agent.choose(const QuickReply('잘 모르겠어요', action: 'form', value: {
        'slots': ['region', 'age', 'stage', 'homeless'],
      }));
      expect(m.isQuestion, isFalse);
      expect(m.form, isEmpty);
    });

    test('빠진 조건이 하나면 예전처럼 하나씩 묻는다', () async {
      app.saveProfile(UserProfile(sido: '서울', age: 29, weddingDate: DateTime(2027, 5, 15)));
      final m = await ConsultAgent().reply('신혼집 주거 지원 정책 알려줘');
      expect(m.isQuestion, isTrue);
      expect(m.form, isEmpty);
      expect(m.quickReplies.map((r) => r.label), contains('무주택이에요'));
    });

    testWidgets('폼 카드: 고른 값을 한 번에 넘긴다', (tester) async {
      QuickReply? sent;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MiniFormCard(
              slots: const ['age', 'stage', 'homeless'],
              initial: const UserProfile(),
              onSubmit: (r) => sent = r,
            ),
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.add)); // 나이 + (시작 29 → 30)
      await tester.tap(find.text('예비부부'));
      await tester.tap(find.text('무주택'));
      await tester.pump();
      await tester.tap(find.text('조건 적용하고 결과 보기'));
      final v = sent!.value as Map;
      expect(sent!.action, 'form');
      expect(v['age'], isA<int>());
      expect(v['stage'], 'engaged');
      expect(v['homeless'], true);
      expect(sent!.label, contains('예비부부'));
    });
  });

  group('P2-3 카드에서 바로 담기', () {
    testWidgets('[+ 담기] → 체크리스트에 담고 채팅에 머묾, 다시 누르면 뺌', (tester) async {
      var opened = false;
      AddToChecklistButton.openChecklist = () => opened = true;
      const blocks = [
        AnswerBlock(BlockType.cards, cards: [
          BlockCard(ref: 'venue:H080', title: '서울주택도시개발공사(대강당홀)', values: ['강남구', '100~400명']),
          BlockCard(ref: 'policy:P001', title: '어떤 정책', values: ['서울']),
        ]),
      ];
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AnswerView(blocks: blocks)))));
      expect(find.text('담기'), findsOneWidget); // 정책 카드에는 없음
      await tester.tap(find.text('담기'));
      await tester.pump();
      expect(app.inChecklist('venue:H080'), isTrue);
      expect(find.text('체크리스트에 추가했어요'), findsOneWidget);
      expect(find.text('담김'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 750)); // 안내가 다 올라온 뒤
      await tester.tap(find.text('보러가기'));
      await tester.pump();
      expect(opened, isTrue);

      await tester.tap(find.text('담김'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(app.inChecklist('venue:H080'), isFalse);
      expect(find.text('체크리스트에서 뺐어요'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/tool_planner.dart';
import 'package:wedding_collect/features/chat/agent/venue_features.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_facts.dart';
import 'package:wedding_collect/features/chat/answer/answer_fold.dart';
import 'package:wedding_collect/features/chat/answer/answer_view.dart';
import 'package:wedding_collect/features/chat/answer/venue_cost.dart';
import 'package:wedding_collect/features/venue/widgets/venue_image.dart';

/// Red Team Phase 2 (P1, 2026-11-20): 총예산 ≠ 대관료 · 예상 총 예식비 · '어떻게 찾았나요' 사용자 말 · 속성 배지
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1-1 총예산과 대관료 분리', () {
    test('"예산 3000만원으로 …"을 대관료 상한으로 쓰지 않고 총예산으로', () {
      final p = ToolPlanner.parse('search_venues', {'sido': ['서울'], 'max_fee_won': 30000000})!;
      final g = ToolPlanner.feeGuard(p, '예산 3000만원으로 서울 웨딩홀 추천해줘');
      expect(g.plan.venue!.maxFee, isNull);
      expect(g.plan.args.containsKey('max_fee_won'), isFalse);
      expect(g.plan.venue!.sidos, ['서울']);
      expect(g.plan.self.profile.budget, 3000);
      expect(g.note, contains('총예산'));
      // Gemini가 만원 단위로 넣어도 같다
      final m = ToolPlanner.feeGuard(ToolPlanner.parse('search_venues', {'max_fee_won': 3000})!, '총예산 3천만원인데 예식장');
      expect(m.plan.venue!.maxFee, isNull);
      expect(m.plan.self.profile.budget, 3000);
    });

    test('대관료를 직접 말하면 그대로 상한', () {
      final p = ToolPlanner.parse('search_venues', {'sido': ['서울'], 'max_fee_won': 500000})!;
      final g = ToolPlanner.feeGuard(p, '대관료 50만원 이하 서울 예식장');
      expect(g.plan.venue!.maxFee, 500000);
      expect(g.note, isNull);
      // '예산'과 '대관비'가 함께 있으면 대관료로 본다
      final both = ToolPlanner.feeGuard(p, '예산 빠듯해서 대관비 50만원 이하로');
      expect(both.plan.venue!.maxFee, 500000);
    });

    test('도구 선언·지시문이 총예산과 대관료를 구분하라고 한다', () {
      expect(ToolPlanner.prompt, contains('총예산과 대관료는 다르다'));
      final sv = ToolPlanner.declarations.firstWhere((d) => d.name == 'search_venues');
      expect(sv.toJson().toString(), contains('budget_manwon'));
    });
  });

  group('P1-2 예상 총 예식비 (참고 단가표 추정)', () {
    test('하객 150명: 식대·꽃장식·음향·디렉팅 = 1,030~1,750만원, 계산식과 총예산 비교', () async {
      final opts = await Repos.vendor.options();
      final e = VenueCostEstimate.of(opts, guests: 150, budget: 3000, allFree: true, anyFree: true)!;
      expect(e.low, 630 + 150 + 150 + 100);
      expect(e.high, 1200 + 300 + 150 + 100);
      expect(e.line, '대관료 무료여도 식대·꽃장식은 따로예요 · 하객 150명 기준 예상 약 1,030~1,750만원 (참고 단가표 추정)');
      expect(e.budgetBadge, const BlockBadge('총예산 3,000만원 안 · 추정', Tone.good));
      expect(e.formula.first, '식대 1인 약 4.2~8만원 × 150명 = 630~1,200만원');
      expect(e.formula.join('\n'), contains('34~58%'));
      expect(VenueCostEstimate.of(opts, guests: 150, budget: 1000)!.budgetBadge!.tone, Tone.no);
      expect(VenueCostEstimate.of(opts, guests: 150, budget: 1500)!.budgetBadge!.tone, Tone.check);
    });

    test('하객 수를 모르면 150명 기본값이라고 밝히고, 유료가 섞이면 "대관료 외"', () async {
      final e = VenueCostEstimate.of(await Repos.vendor.options(), anyFree: true)!;
      expect(e.guests, 150);
      expect(e.line, contains('하객 150명(미입력, 기본값) 기준 대관료 외 예상'));
      expect(e.budgetBadge, isNull);
      expect(e.formula.join(), contains('150명으로 계산'));
    });

    test('단가표에 항목이 없으면 숫자를 만들지 않는다', () {
      expect(VenueCostEstimate.of(const []), isNull);
    });

    test('카드의 무료는 "식대 별도"와 함께', () async {
      final free = (await Repos.venue.loadAll()).firstWhere((v) => v.rentalFee == 0);
      final f = venueFact(free);
      expect(f.values, contains('무료 · 식대 별도'));
      expect(f.fields['대관료'], '무료 (식대 별도)');
      fillReasons([f]);
      expect(f.reasons['free'], '대관료 무료 · 식대 별도');
    });
  });

  group('P1-3 어떻게 찾았나요 (사용자 말)', () {
    test('내부 기록의 함수 이름·JSON·ms·검사 코드를 지운다', () {
      final s = FoldSummary.plain('AI가 도구를 고름: search_venues {"sido":["서울"]} (조건은 앱이 검사, 1234ms) K1~K8 통과');
      expect(s, isNot(contains('search_venues')));
      expect(s, isNot(contains('{')));
      expect(s, isNot(contains('ms')));
      expect(s, isNot(contains('K1')));
    });

    final app = AppState.instance;
    setUp(() => app.saveProfile(
        UserProfile(sido: '서울', sigungu: '강남구', age: 29, guests: 120, budget: 3000, weddingDate: DateTime(2027, 5, 15))));
    tearDown(() => app.resetProfile());

    test('예식장 답: 검증 배지 · 걸러진 과정(건수) · 충족/확인 필요 · 예상 비용 줄', () async {
      await Repos.venue.loadAll();
      await Repos.booking.loadAll();
      final m = await ConsultAgent().reply('공공예식장 추천해줘');
      final fold = m.blocks.firstOf(BlockType.fold)!;
      expect(fold.badges.single.text, '공공데이터로 확인');
      final all = (await Repos.venue.loadAll()).where((v) => v.sido == '서울').length;
      expect(fold.items.first, '서울 공공예식장 $all곳');
      expect(fold.items.join(' → '), contains('강남구(내 지역)'));
      expect(fold.items.join(' → '), contains('하객 120명 수용'));
      expect(fold.met.join(), contains('강남구'));
      expect(fold.pending.join(), contains('예식일 예약 가능 여부'));
      expect(fold.calc.first, startsWith('식대 1인'));
      final bad = RegExp(r'[a-z]+_[a-z]+|\{|\d+ms|\bK\d');
      for (final line in [...fold.items, ...fold.met, ...fold.pending]) {
        expect(bad.hasMatch(line), isFalse, reason: line);
      }
      // 예상 비용 줄은 제목 바로 아래 한 번
      expect(m.blocks[1].type, BlockType.estimate);
      expect(m.blocks.where((b) => b.type == BlockType.estimate).length, 1);
      expect(m.blocks[1].text, contains('하객 120명 기준'));
      expect(m.blocks[1].badges.single.text, contains('총예산 3,000만원'));
      expect(m.blocks.copyText, contains('참고 단가표 추정'));
      // 저장했다가 다시 열어도 같다
      final again = [for (final b in m.blocks) AnswerBlock.fromJson(b.toJson())!];
      expect(again.firstOf(BlockType.fold)!.met, fold.met);
      expect(again.allCards.first.tags, m.blocks.allCards.first.tags);
    });

    test('정책 답: 자격 규칙 배지 + 미입력 조건', () async {
      final m = await ConsultAgent().reply('받을 수 있는 정책 알려줘');
      final fold = m.blocks.firstOf(BlockType.fold)!;
      expect(fold.badges.single.text, '공공데이터·자격 규칙으로 확인');
      expect(fold.items.first, startsWith('지원 정책'));
      expect(fold.met, contains('만 29세'));
    });

    testWidgets('펼치면 사용자 말 3단만 보이고 내부 기록은 안 보인다', (tester) async {
      const blocks = [
        AnswerBlock(BlockType.headline, title: '강남구 공공예식장 3곳'),
        AnswerBlock(
          BlockType.fold,
          sources: ['전국 공공예식장 현황'],
          log: ['질문 이해 · Gemini가 도구를 고름: search_venues {"sido":["서울"]} (812ms)', '앱 검사 K1~K8 통과'],
          badges: [BlockBadge('공공데이터로 확인', Tone.good)],
          items: ['서울 공공예식장 74곳', '강남구(내 지역) 3곳', '하객 120명 수용 2곳 먼저'],
          met: ['지역 서울 강남구'],
          pending: ['예식일 (미입력)'],
          calc: ['합계 1,030~1,750만원'],
        ),
      ];
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AnswerView(blocks: blocks)))));
      await tester.tap(find.text('출처 보기 · 어떻게 찾았나요'));
      await tester.pump();
      expect(find.text('공공데이터로 확인'), findsOneWidget);
      expect(find.textContaining('서울 공공예식장 74곳'), findsOneWidget);
      expect(find.text('충족한 조건'), findsOneWidget);
      expect(find.text('확인이 필요한 조건 (미입력·현장 확인)'), findsOneWidget);
      expect(find.textContaining('search_venues'), findsNothing);
      expect(find.textContaining('K1'), findsNothing);
      expect(find.textContaining('ms)'), findsNothing);
    });
  });

  group('P1-4 속성 배지·사진 자리표시', () {
    test('데이터로 분류한 속성만, 최대 3개', () async {
      final all = await Repos.venue.loadAll();
      final hall = all.firstWhere((v) => v.id == 'H080'); // 서울주택도시개발공사(대강당홀)
      expect(VenueFeatures.traits(hall), contains('실내 대강당'));
      for (final v in all) {
        final t = VenueFeatures.traits(v);
        expect(t.length, lessThanOrEqualTo(3));
        if (v.rentalFee == 0) expect(t.first, '대관료 무료');
        if (t.contains('주차 가능')) expect(VenueFeatures.parking(v).ok, Avail.yes);
        expect(VenueFeatures.traits(v, fee: false), isNot(contains('대관료 무료')));
      }
      // 채팅 카드에도 붙는다 (대관료는 카드 값 '무료 · 식대 별도'가 보여 줌)
      expect(venueFact(hall).toCard().tags, VenueFeatures.traits(hall, fee: false));
    });

    testWidgets('사진이 안 열리면 분야 아이콘 자리표시 하나로', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 200, height: 200, child: VenueImage(url: 'https://example.invalid/x.jpg', placeholderIcon: Icons.checkroom)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.checkroom), findsOneWidget);
      expect(find.text('사진 없음'), findsOneWidget);
    });
  });
}

import '../../../data/models/wedding_option.dart';
import 'answer_blocks.dart';

/// 예상 총 예식비 (Red Team P1-2, 2026-11-20): 공공예식장은 대관료가 무료여도 식대·꽃장식·음향·현장 진행비가 따로 든다.
/// 그래서 예식장 답에는 '대관료 무료'만 보여 주지 않고, 앱의 참고 단가표(assets/data/wedding_options.json, 업체_요소.xlsx)로
/// 계산한 범위를 '추정'으로 함께 보여 준다. 근거 없는 숫자는 쓰지 않는다.
///
/// 낮은 값 = 공공·실속 표준가, 높은 값 = 일반 웨딩 평균가. 평균가가 표준가보다 낮게 적힌 항목(음향·집기, 디렉팅:
/// 일반 웨딩홀은 대관료에 들어 있어 0)은 공공예식장에서는 따로 들기 때문에 표준가를 쓴다.
class VenueCostEstimate {
  const VenueCostEstimate._({
    required this.guests,
    required this.guestsGiven,
    required this.parts,
    this.budget,
    this.allFree = false,
    this.anyFree = false,
  });

  /// 하객 수를 모를 때 쓰는 기본값
  static const defaultGuests = 150;

  /// 계산에 넣는 단가표 항목 (식대는 하객 100명 기준 금액을 하객 수로 다시 계산)
  static const ids = ['meal', 'flower', 'equipment', 'directing'];
  static const _labels = {
    'meal': '식대',
    'flower': '꽃장식·공간연출',
    'equipment': '음향·조명·의자 렌탈',
    'directing': '현장 진행(디렉팅)',
  };

  final int guests;
  final bool guestsGiven; // false면 기본 150명
  final List<({String id, String label, int low, int high})> parts; // 만원
  final int? budget; // 내 총예산 (만원)
  final bool allFree; // 보여 준 예식장이 모두 대관료 무료
  final bool anyFree;

  int get low => parts.fold(0, (s, p) => s + p.low);
  int get high => parts.fold(0, (s, p) => s + p.high);

  /// 단가표에 필요한 항목이 없으면 null (숫자를 만들지 않는다)
  static VenueCostEstimate? of(
    List<WeddingOption> options, {
    int? guests,
    int? budget,
    bool allFree = false,
    bool anyFree = false,
  }) {
    final byId = {for (final o in options) o.id: o};
    if (ids.any((i) => byId[i] == null)) return null;
    final n = guests != null && guests > 0 ? guests : defaultGuests;
    int scaled(WeddingOption o, int price) => o.perGuest ? (price * n / 100).round() : price;
    return VenueCostEstimate._(
      guests: n,
      guestsGiven: guests != null && guests > 0,
      budget: budget,
      allFree: allFree,
      anyFree: anyFree,
      parts: [
        for (final id in ids)
          (
            id: id,
            label: _labels[id]!,
            low: scaled(byId[id]!, byId[id]!.publicPrice),
            high: scaled(byId[id]!, byId[id]!.averagePrice > byId[id]!.publicPrice ? byId[id]!.averagePrice : byId[id]!.publicPrice),
          ),
      ],
    );
  }

  static String fmt(int manwon) => manwon.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  /// 답 위쪽에 한 번 보여 줄 줄
  String get line => '${anyFree ? '대관료 무료여도 식대·꽃장식은 따로예요' : '대관료 말고도 식대·꽃장식이 따로 들어요'} · '
      '하객 $guests명${guestsGiven ? '' : '(미입력, 기본값)'} 기준 ${allFree ? '' : '대관료 외 '}'
      '예상 약 ${fmt(low)}~${fmt(high)}만원 (참고 단가표 추정)';

  /// 내 총예산과 비교 (추정). 총예산을 모르면 null
  BlockBadge? get budgetBadge {
    final b = budget;
    if (b == null || b <= 0) return null;
    if (high <= b) return BlockBadge('총예산 ${fmt(b)}만원 안 · 추정', Tone.good);
    if (low > b) return BlockBadge('총예산 ${fmt(b)}만원 초과 · 추정', Tone.no);
    return BlockBadge('총예산 ${fmt(b)}만원에 빠듯 · 추정', Tone.check);
  }

  /// 화면에 넣는 블록 (앱 전용)
  AnswerBlock get block => AnswerBlock(BlockType.estimate, text: line, badges: [?budgetBadge]);

  /// 접힌 줄의 계산식 (사용자가 숫자를 따라가 볼 수 있게)
  List<String> get formula {
    String range(int a, int b) => a == b ? '${fmt(a)}만원' : '${fmt(a)}~${fmt(b)}만원';
    String perHead(int total) {
      final v = total * 100 / guests / 100; // 1인당 만원
      return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    }

    final meal = parts.firstWhere((p) => p.id == 'meal');
    return [
      '식대 1인 약 ${perHead(meal.low)}~${perHead(meal.high)}만원 × $guests명 = ${range(meal.low, meal.high)}',
      for (final p in parts.where((p) => p.id != 'meal')) '${p.label} ${range(p.low, p.high)}',
      '합계 ${range(low, high)}${allFree ? '' : ' (대관료는 예식장마다 달라 따로)'}',
      '낮은 값 = 공공·실속 표준가, 높은 값 = 일반 웨딩 평균가 (참고 단가표 · 실제 견적과 다를 수 있어요)',
      if (!guestsGiven) '하객 수를 입력하지 않아 $defaultGuests명으로 계산했어요',
      if (budget != null && budget! > 0)
        '내 총예산 ${fmt(budget!)}만원의 약 ${(low * 100 / budget!).round()}~${(high * 100 / budget!).round()}% '
            '(드레스·촬영 등 다른 항목은 빠진 값)',
    ];
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/app_state.dart';
import '../../data/candidates.dart';
import '../../data/models/vendor.dart';
import '../../data/models/wedding_option.dart';
import '../../data/models/wedding_plan.dart';
import '../../data/repositories/repositories.dart';

/// 견적서 한 칸에서 고를 수 있는 것
class EstimateChoice {
  const EstimateChoice(this.key, this.label, this.price, {this.note});

  final String key; // 'avg:public' · 'avg:general' · 'mine' · 'none' · 'ref:vendor:D0001'
  final String label;
  final int? price; // 만원 (가격 문의면 null → 합계에서 빠짐)
  final String? note;
}

/// 견적서 한 줄: 예식장 + 준비 항목 11개
class EstimateRow {
  const EstimateRow(this.key, this.label, this.category);

  final String key; // 'venue' 또는 VendorCategory.name
  final String label;
  final VendorCategory? category;

  static final all = [
    const EstimateRow('venue', '예식장', null),
    for (final c in VendorCategory.planItems) EstimateRow(c.name, c.label, c),
  ];
}

/// 계산 (화면과 테스트에서 같이 쓴다)
class EstimateCalc {
  EstimateCalc(this.app, this.options);

  final AppState app;
  final List<WeddingOption> options;

  int get guests => app.plan.guests;

  WeddingOption? optionFor(EstimateRow r) => r.category == null
      ? options.where((o) => o.id == 'rental').firstOrNull
      : options.where((o) => o.category != null && VendorCategory.fromCode(o.category!) == r.category).firstOrNull;

  PlanItem? itemFor(EstimateRow r) => r.category == null
      ? app.items.where((i) => i.id == AppState.venueItemId).firstOrNull
      : app.itemFor(r.category!);

  /// 이 줄에서 고를 수 있는 것: 체크리스트에 적은 금액 → 찜한 후보 → 실속·공공 평균 → 일반 평균 → 넣지 않음
  List<EstimateChoice> choices(EstimateRow r) {
    final item = itemFor(r);
    final opt = optionFor(r);
    final mine = item?.amount != null;
    final isVenue = r.category == null;
    return [
      if (mine)
        EstimateChoice('mine', item!.vendorName ?? '체크리스트 금액', item.amount,
            note: isVenue && app.chosenVenueId != null ? '정한 예식장' : '체크리스트에 적은 금액'),
      if (item != null)
        for (final c in Candidates.forItem(item, app))
          // 체크리스트 금액과 같은 곳(정한 예식장·계약한 업체)은 한 번만
          if (!(mine && (c.name == item.vendorName || (isVenue && c.ref == 'venue:${app.chosenVenueId}'))))
            EstimateChoice('ref:${c.ref}', c.name, c.price, note: c.price == null ? '가격 문의 · 합계에서 빠져요' : '찜한 후보'),
      if (opt != null) ...[
        EstimateChoice('avg:public', '실속·공공 평균', opt.publicCost(guests), note: '공공예식장 기준 표준가'),
        EstimateChoice('avg:general', '일반 웨딩 평균', opt.generalCost(guests), note: '평균가 + 숨은 추가금'),
      ],
      const EstimateChoice('none', '넣지 않음', 0),
    ];
  }

  /// 고른 것. 고르지 않았거나 사라졌으면 A안은 체크리스트 금액(정한 예식장·적은 금액) → 실속 평균, B안은 일반 평균
  EstimateChoice chosen(String plan, EstimateRow r) {
    final list = choices(r);
    final key = app.estimates[plan]?[r.key];
    EstimateChoice? find(String k) => list.where((c) => c.key == k).firstOrNull;
    return (key == null ? null : find(key)) ??
        (plan == 'A' ? (find('mine') ?? find('avg:public')) : find('avg:general')) ??
        list.last;
  }

  int total(String plan) => EstimateRow.all.fold(0, (s, r) => s + (chosen(plan, r).price ?? 0));
  int unknown(String plan) => EstimateRow.all.where((r) => chosen(plan, r).price == null).length;

  /// 일반 웨딩 평균(숨은 추가금 포함) 합계
  int get generalTotal => EstimateRow.all.fold(0, (s, r) => s + (optionFor(r)?.generalCost(guests) ?? 0));
}

/// 내 결혼 견적서: 항목마다 후보·평균가를 골라 A안·B안을 나란히 비교한다
class EstimateScreen extends StatefulWidget {
  const EstimateScreen({super.key});

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  final _app = AppState.instance;
  late final Future<List<WeddingOption>> _future = () async {
    await Future.wait([Repos.venue.loadAll(), Repos.vendor.realVendors(), Repos.vendor.demoVendors()]);
    return Repos.vendor.options();
  }();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 결혼 견적서')),
      body: FutureBuilder<List<WeddingOption>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListenableBuilder(
            listenable: _app,
            builder: (context, _) {
              final calc = EstimateCalc(_app, snap.data!);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _summary(calc),
                  const SizedBox(height: 12),
                  Text(
                    '칸을 눌러 바꿔 보세요. 찜(하트)한 업체·예식장과 체크리스트에 적은 금액이 후보로 나와요. '
                    '하객 ${calc.guests}명 기준${_app.plan.hasGuests ? '' : '(기본값)'}.',
                    style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _headerRow(),
                  for (final r in EstimateRow.all) _row(calc, r),
                  const SizedBox(height: 16),
                  Text(
                    '시연용 참고 금액이에요. [시연] 업체 가격은 임의로 만든 값이고, 평균가는 업체_요소 단가표 기준이에요.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _summary(EstimateCalc calc) {
    final budget = _app.plan.hasBudget ? _app.plan.budget : null;
    Widget col(String plan) {
      final t = calc.total(plan);
      final unknown = calc.unknown(plan);
      final save = calc.generalTotal - t;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: plan == 'A' ? AppColors.primarySoft : AppColors.fill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$plan안', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(formatManwon(t), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            if (budget != null)
              Text(
                t <= budget ? '예산 안 · ${formatManwon(budget - t)} 남음' : '예산 ${formatManwon(t - budget)} 초과',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: t <= budget ? AppColors.success : AppColors.warning),
              ),
            Text(
              save > 0 ? '일반 웨딩보다 ${formatManwon(save)} 절약' : '일반 웨딩 평균 수준',
              style: TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
            if (unknown > 0)
              Text('가격 문의 $unknown곳 제외', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [col('A'), const SizedBox(width: 8), col('B')]),
      const SizedBox(height: 8),
      Text(
        '참고 · 일반 웨딩 평균 ${formatManwon(calc.generalTotal)}'
        '${budget == null ? ' · 체크리스트에서 총예산을 입력하면 예산과 비교해요' : ' · 총예산 ${formatManwon(budget)}'}',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    ]);
  }

  Widget _headerRow() => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 78, child: Text('항목', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text('A안', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          Expanded(child: Text('B안', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ]),
      );

  Widget _row(EstimateCalc calc, EstimateRow r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 78,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(r.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(child: _cell(calc, 'A', r)),
        const SizedBox(width: 8),
        Expanded(child: _cell(calc, 'B', r)),
      ]),
    );
  }

  Widget _cell(EstimateCalc calc, String plan, EstimateRow r) {
    final c = calc.chosen(plan, r);
    final none = c.key == 'none';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _pick(calc, plan, r),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          border: Border.all(color: c.key.startsWith('ref:') || c.key == 'mine' ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                none ? '-' : (c.price == null ? '가격 문의' : formatManwon(c.price!)),
                maxLines: 1,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ]),
          ),
          Icon(Icons.expand_more, size: 18, color: AppColors.textHint),
        ]),
      ),
    );
  }

  Future<void> _pick(EstimateCalc calc, String plan, EstimateRow r) async {
    final current = calc.chosen(plan, r).key;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('$plan안 · ${r.label}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final c in calc.choices(r))
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: Icon(c.key == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: c.key == current ? AppColors.primary : AppColors.textHint),
                    title: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: c.note == null ? null : Text(c.note!),
                    trailing: Text(c.key == 'none' ? '' : (c.price == null ? '가격 문의' : formatManwon(c.price!)),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(ctx, c.key),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (picked != null) _app.setEstimate(plan, r.key, picked);
  }
}

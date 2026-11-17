import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/inputs.dart';
import '../../data/app_state.dart';
import '../../data/models/wedding_option.dart';
import '../../data/repositories/repositories.dart';

/// 지자체 지원금(비품비 바우처 등) 평균 차감액 (만원). 업체_요소.xlsx 하단 '바우처 지원금 차감' 줄
const kVoucher = 100;

/// 고른 항목으로 계산한 결과 (만원)
class SimulationResult {
  SimulationResult(this.options, this.selected, this.guests, this.voucher);

  final List<WeddingOption> options;
  final Set<String> selected;
  final int guests;
  final bool voucher;

  List<WeddingOption> get chosen => [for (final o in options) if (selected.contains(o.id)) o];

  int get publicTotal =>
      chosen.fold(0, (s, o) => s + o.publicCost(guests)) - (voucher ? kVoucher : 0);
  int get generalTotal => chosen.fold(0, (s, o) => s + o.generalCost(guests));
  int get hiddenTotal => chosen.fold(0, (s, o) => s + (o.hiddenExtra * (o.perGuest ? guests / 100 : 1)).round());
  int get saving => generalTotal - publicTotal;

  /// 절감액이 큰 항목 순
  List<(WeddingOption, int)> get topSavings => [
        for (final o in chosen) (o, o.generalCost(guests) - o.publicCost(guests)),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
}

/// 비용 시뮬레이터: 항목을 켜고 끄면 공공·실속 vs 일반 웨딩 총액과 절감액이 바뀐다 (시연용 참고 금액)
class CostSimulatorScreen extends StatefulWidget {
  const CostSimulatorScreen({super.key});

  @override
  State<CostSimulatorScreen> createState() => _CostSimulatorScreenState();
}

class _CostSimulatorScreenState extends State<CostSimulatorScreen> {
  final _app = AppState.instance;
  late final Future<List<WeddingOption>> _future = Repos.vendor.options();
  final _open = <String>{}; // 자세히 펼친 항목

  Set<String> _selected(List<WeddingOption> all) =>
      _app.simSelected ?? {for (final o in all) if (o.defaultOn) o.id};

  void _toggle(List<WeddingOption> all, String id) {
    final s = {..._selected(all)};
    s.contains(id) ? s.remove(id) : s.add(id);
    _app.setSimulation(selected: s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('결혼 비용 시뮬레이터')),
      body: FutureBuilder<List<WeddingOption>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          return ListenableBuilder(
            listenable: _app,
            builder: (context, _) {
              final r = SimulationResult(all, _selected(all), _app.plan.guests, _app.simVoucher);
              final groups = <String, List<WeddingOption>>{};
              for (final o in all) {
                groups.putIfAbsent(o.group, () => []).add(o);
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _Summary(result: r, budget: _app.plan.budget),
                  const SizedBox(height: 16),
                  _Advice(result: r),
                  const SizedBox(height: 24),
                  FormSection(
                    title: '하객 수',
                    hint: '식대·답례품 금액에 반영돼요',
                    child: PresetPicker(
                      value: _app.plan.guests,
                      presets: const [50, 100, 150, 200, 300],
                      format: (n) => '$n명',
                      unit: '명',
                      min: 10,
                      max: 1000,
                      onChanged: (n) => _app.updatePlan(_app.plan.copyWith(guests: n)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('지자체 지원금 반영 (−100만원)'),
                    subtitle: const Text('서울 더아결 비품비 바우처 등 평균 지원액'),
                    value: _app.simVoucher,
                    onChanged: (v) => _app.setSimulation(voucher: v),
                  ),
                  for (final g in groups.entries) ...[
                    const SizedBox(height: 20),
                    Text(g.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final o in g.value)
                      _OptionRow(
                        option: o,
                        guests: r.guests,
                        on: r.selected.contains(o.id),
                        open: _open.contains(o.id),
                        onToggle: () => _toggle(all, o.id),
                        onOpen: () => setState(() => _open.contains(o.id) ? _open.remove(o.id) : _open.add(o.id)),
                      ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    '시연용 참고 금액이에요. 항목별 출처(서울시 더아결 표준가격표, 한국소비자원 참가격, 업체 정찰가 등)를 바탕으로 '
                    '정리한 평균값이라 실제 견적과 다를 수 있어요.',
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
}

/// 맨 위 요약: 공공·실속 총액 vs 일반 웨딩 실질 총액, 절감액, 내 예산 비교
class _Summary extends StatelessWidget {
  const _Summary({required this.result, required this.budget});

  final SimulationResult result;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final max = r.generalTotal == 0 ? 1 : r.generalTotal;
    final fits = budget <= 0 ? null : r.publicTotal <= budget;
    Widget bar(String label, int value, Color color) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            SizedBox(width: 74, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 10,
                    width: c.maxWidth * (value.clamp(0, max) / max),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 86,
              child: Text(formatManwon(value),
                  textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('항목 ${r.chosen.length}개 · 하객 ${r.guests}명 기준',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text.rich(TextSpan(children: [
          const TextSpan(text: '공공예식장으로 하면 약 '),
          TextSpan(
              text: formatManwon(r.saving < 0 ? 0 : r.saving),
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
          const TextSpan(text: ' 아껴요'),
        ]), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.35)),
        bar('공공·실속', r.publicTotal, AppColors.primary),
        bar('일반 웨딩', r.generalTotal, AppColors.textHint),
        if (fits != null) ...[
          const SizedBox(height: 12),
          Text(
            fits
                ? '총예산 ${formatManwon(budget)} 안이에요 (${formatManwon(budget - r.publicTotal)} 남음)'
                : '총예산 ${formatManwon(budget)}보다 ${formatManwon(r.publicTotal - budget)} 많아요',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fits ? AppColors.success : AppColors.warning),
          ),
        ],
      ]),
    );
  }
}

/// 컨설팅 한 줄 요약: 가장 많이 아끼는 항목, 숨은 추가금 주의
class _Advice extends StatelessWidget {
  const _Advice({required this.result});

  final SimulationResult result;

  @override
  Widget build(BuildContext context) {
    final top = result.topSavings.where((e) => e.$2 > 0).take(3).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final style = TextStyle(fontSize: 14, height: 1.55, color: AppColors.textBody);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('비용 컨설팅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final (o, s) in top) Text('• ${o.label}: 일반 웨딩보다 약 ${formatManwon(s)} 적어요', style: style),
      if (result.hiddenTotal > 0)
        Text('• 일반 웨딩홀에서는 숨은 추가금이 약 ${formatManwon(result.hiddenTotal)} 더 붙을 수 있어요 '
            '(원본 데이터 구매·헬퍼비·직급 지정비 등)', style: style),
      if (result.voucher)
        Text('• 지자체 지원금 ${formatManwon(kVoucher)}을 뺐어요. 대상 여부는 정책 탭에서 확인하세요', style: style),
    ]);
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.guests,
    required this.on,
    required this.open,
    required this.onToggle,
    required this.onOpen,
  });

  final WeddingOption option;
  final int guests;
  final bool on;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final pub = o.publicCost(guests);
    final gen = o.generalCost(guests);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: on ? AppColors.primary : AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(children: [
              Icon(on ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22, color: on ? AppColors.primary : AppColors.textHint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '공공·실속 ${formatManwon(pub)} · 일반 ${gen == 0 ? '대관료에 포함' : formatManwon(gen)}',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ]),
              ),
              TextButton(onPressed: onOpen, child: Text(open ? '접기' : '자세히')),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _line('구성', o.detail),
              if (o.extraDetail.isNotEmpty) _line('숨은 추가금', '${o.extraDetail} (일반 웨딩 약 ${formatManwon(o.hiddenExtra)})'),
              if (o.support.isNotEmpty) _line('지원·절약 팁', o.support),
              if (o.sourceName.isNotEmpty)
                InkWell(
                  onTap: o.sourceUrl.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse(o.sourceUrl), mode: LaunchMode.externalApplication),
                  child: _line('출처', o.sourceName, link: o.sourceUrl.isNotEmpty),
                ),
            ]),
          ),
      ]),
    );
  }

  Widget _line(String label, String text, {bool link = false}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            child: Text(text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: link ? AppColors.primary : AppColors.textBody,
                  decoration: link ? TextDecoration.underline : null,
                )),
          ),
        ]),
      );
}

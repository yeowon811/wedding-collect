import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/repositories/review_repository.dart';

/// 같은 항목의 시연용 업체 2~3곳을 표로 비교
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final list = state.compare;
    final guests = state.plan.guests;
    final budget = list.isEmpty ? null : state.budgetOf(list.first.category); // 준비 항목에 정한 금액

    // 비교 기준별 최고값 표시용
    final cheapest = list.map((v) => v.estimate(guests: guests)).reduce((a, b) => a < b ? a : b);
    final bestRating =
        list.map((v) => ReviewRepository.summaryFor(v).average).reduce((a, b) => a > b ? a : b);

    final rows = <(String, Widget Function(DemoVendor))>[
      ('가격대', (v) => Text(v.priceText)),
      (
        '총 비용(약)',
        (v) {
          final e = v.estimate(guests: guests);
          return Text('$e만원',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: e == cheapest ? AppColors.success : null,
              ));
        }
      ),
      if (budget != null)
        (
          '내 예산',
          (v) {
            final ok = v.estimate(guests: guests) <= budget;
            return Text(ok ? '예산 안' : '초과',
                style: TextStyle(color: ok ? AppColors.success : AppColors.warning));
          }
        ),
      (
        '평점',
        (v) {
          final s = ReviewRepository.summaryFor(v);
          return Text('★ ${s.average} (${s.count})',
              style: TextStyle(
                fontWeight: s.average == bestRating ? FontWeight.w700 : null,
                color: s.average == bestRating ? AppColors.success : null,
              ));
        }
      ),
      (
        '후기 키워드',
        (v) => Text(ReviewRepository.summaryFor(v).topTags.take(2).map((t) => t.$1).join('\n'))
      ),
      ('스타일', (v) => Text(v.styles.join('\n'))),
      ('포함 구성', (v) => Text(v.packageItems.map((e) => '• $e').join('\n'))),
      ('공공예식장', (v) => Text(v.publicVenueOk ? '출장 가능' : '문의 필요')),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('${list.first.category.vendorLabel} 비교')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '하객 $guests명 · ${budget == null ? '예산 미정 (체크리스트 예산 관리 목록에 금액을 정하면 예산 안인지 비교해요)' : '내 예산 $budget만원 기준'} · 시연용 데이터',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(150),
              columnWidths: const {0: FixedColumnWidth(84)},
              border: TableBorder.symmetric(
                inside: const BorderSide(color: AppColors.divider),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12)),
                  children: [
                    const SizedBox.shrink(),
                    for (final v in list)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(v.name.replaceFirst('[시연] ', ''),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                for (final (label, cell) in rows)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(label, style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      for (final v in list)
                        Padding(padding: const EdgeInsets.all(10), child: cell(v)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '초록색은 그 기준에서 가장 좋은 업체예요. 가격·평점은 시연용으로 만든 값이에요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

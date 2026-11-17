import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/info_badge.dart';
import '../../core/widgets/inputs.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/models/wedding_plan.dart';
import '../../data/repositories/review_repository.dart';
import 'consultation_sheet.dart';
import 'review_list_screen.dart';
import 'widgets/review_widgets.dart';
import 'widgets/vendor_photo.dart';
import 'write_review_sheet.dart';

/// 시연용 업체 상세: 가격·구성, 예산 비교, 상담 신청, 계약 완료 표시
class DemoVendorDetailScreen extends StatelessWidget {
  const DemoVendorDetailScreen({super.key, required this.vendor});

  final DemoVendor vendor;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final v = vendor;

    return Scaffold(
      appBar: AppBar(title: Text(v.category.label)),
      // 주요 행동: 상담 신청(주) + 계약 완료 표시(보조), 화면 아래 고정
      bottomNavigationBar: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final contracted = state.contracts[v.category]?.$1.id == v.id;
          return BottomActionBar(children: [
            ActionPair(
              secondary: OutlinedButton(
                onPressed: contracted
                    ? () => state.setStatus(v.category, ItemStatus.consulting)
                    : () {
                        state.contract(v);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${v.category.label}: 계약 완료로 표시했어요 (체크리스트 반영)'),
                        ));
                      },
                child: Text(contracted ? '계약 취소' : '계약 완료 표시'),
              ),
              primary: FilledButton(
                onPressed: () => showConsultationSheet(context, v),
                child: const Text('상담 신청'),
              ),
            ),
          ]);
        },
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final estimate = v.estimate(guests: state.plan.guests);
          final budget = state.budgetOf(v.category); // 준비 항목에 정한 금액
          final total = v.totalLabel(guests: state.plan.guests);
          final mine = state.consultations.where((c) => c.vendor.id == v.id).toList();
          final summary = ReviewRepository.summaryFor(v);
          final reviews = ReviewRepository.reviewsFor(v);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              VendorPhotoHeader(category: v.category, vendorId: v.id),
              const SizedBox(height: 16),
              Wrap(spacing: 6, runSpacing: 6, children: [
                InfoBadge(label: '시연용 가상 업체', color: AppColors.textSecondary, background: AppColors.fill),
                InfoBadge(label: v.sido, color: AppColors.textSecondary, background: AppColors.fill),
                if (v.publicVenueOk)
                  const InfoBadge(
                      label: '공공예식장 출장 가능', color: AppColors.success, background: AppColors.successSoft),
              ]),
              const SizedBox(height: 10),
              Text(v.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                StarRow(rating: summary.average),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${summary.average} · 후기 ${summary.count}개 · ${v.styles.join(' · ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('가격대 ${v.priceText}',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    if (total != null) ...[
                      const SizedBox(height: 6),
                      Text(total),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      budget == null
                          ? '체크리스트 준비 항목에 ${v.category.label} 금액을 정하면 예산 안인지 알려드려요'
                          : estimate <= budget
                              ? '내 ${v.category.label} 예산 $budget만원 안이에요'
                              : '내 ${v.category.label} 예산 $budget만원보다 ${estimate - budget}만원 많아요',
                      style: TextStyle(
                          fontSize: budget == null ? 13 : null,
                          color: budget == null
                              ? AppColors.textSecondary
                              : (estimate <= budget ? AppColors.success : AppColors.warning)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(
                  child: Text('후기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (state.canReview(v))
                  TextButton.icon(
                    onPressed: () => showWriteReviewSheet(context, v),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('후기 쓰기'),
                  ),
              ]),
              const SizedBox(height: 8),
              RatingSummaryView(summary: summary),
              const SizedBox(height: 8),
              for (final r in reviews.take(3)) ReviewTile(review: r),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReviewListScreen(vendor: v)),
                ),
                child: Text('후기 ${summary.count}개 전체 보기 ›'),
              ),
              if (!state.canReview(v))
                Text('상담을 신청하거나 계약하면 후기를 남길 수 있어요.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              const Text('포함 구성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final item in v.packageItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(Icons.check, size: 16, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Text(item),
                  ]),
                ),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('내 상담 예약',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                for (final c in mine)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.event_available, color: AppColors.primaryDark),
                    title: Text('${formatDateWithDay(c.dateTime)} '
                        '${c.dateTime.hour.toString().padLeft(2, '0')}:00'),
                    subtitle: c.memo.isEmpty ? null : Text(c.memo),
                    trailing: TextButton(
                      onPressed: () => state.cancelConsultation(c),
                      child: const Text('취소'),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text('시연용으로 만든 가상 업체·후기예요. 실제 예약은 이뤄지지 않아요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          );
        },
      ),
    );
  }
}

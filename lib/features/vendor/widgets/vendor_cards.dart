import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../data/app_state.dart';
import '../../../data/models/vendor.dart';
import '../../../data/repositories/review_repository.dart';

/// 시연용 업체 카드: 가격대, 평점, 패키지, 비교 담기
class DemoVendorCard extends StatelessWidget {
  const DemoVendorCard({super.key, required this.vendor, required this.onTap});

  final DemoVendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final v = vendor;
    final budget = state.plan.budgetFor(v.category);
    final estimate = v.estimate(guests: state.plan.guests);
    final inBudget = budget == 0 || estimate <= budget;
    final summary = ReviewRepository.summaryFor(v);
    final latest = ReviewRepository.reviewsFor(v).firstOrNull;

    return _CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(v.category.icon, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(v.category.label,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              const InfoBadge(label: '시연용', color: AppColors.unknown),
            ],
          ),
          const SizedBox(height: 8),
          Text(v.name,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF2B33D)),
              Text(' ${summary.average}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(' (후기 ${summary.count})',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(v.styles.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
          if (latest != null) ...[
            const SizedBox(height: 6),
            Text(
              '“${latest.text}”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.priceText,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark)),
                    const SizedBox(height: 2),
                    Text(
                      inBudget ? '예상 $estimate만원 · 추천 예산 안' : '예상 $estimate만원 · 추천 예산 $budget만원 초과',
                      style: TextStyle(
                        fontSize: 12,
                        color: inBudget ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: state,
                builder: (context, _) {
                  final on = state.inCompare(v);
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: on ? AppColors.primary.withValues(alpha: 0.12) : null,
                    ),
                    onPressed: () => state.toggleCompare(v),
                    icon: Icon(on ? Icons.check : Icons.add, size: 16),
                    label: Text(on ? '비교 중' : '비교 담기'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (v.publicVenueOk)
                const InfoBadge(
                    label: '공공예식장 출장 가능', icon: Icons.verified_outlined, color: AppColors.success),
              for (final item in v.packageItems.take(2))
                InfoBadge(label: item, color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

/// 실제 연계업체 카드: 가격 없이 위치·연락처·공식 연계 여부
class RealVendorCard extends StatelessWidget {
  const RealVendorCard({super.key, required this.vendor, required this.onTap, this.distanceKm});

  final RealVendor vendor;
  final VoidCallback onTap;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final v = vendor;
    return _CardShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(v.category.icon, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(v.categoryText,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              InfoBadge(
                label: v.isOfficial ? v.official : '실제 업체',
                icon: v.isOfficial ? Icons.verified : null,
                color: v.isOfficial ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(v.name,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: AppColors.primary),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  distanceKm == null ? v.address : '${distanceKm}km · ${v.address}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(v.services,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 6),
          Text('가격은 업체에 직접 문의 (공개 정보 없음)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

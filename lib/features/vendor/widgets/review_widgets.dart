import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../data/models/review.dart';

const kStarColor = Color(0xFFF2B33D);

/// 별 5개 (반 개 단위)
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: kStarColor,
          ),
      ],
    );
  }
}

/// 평균 평점 + 별점 분포 막대 + 많이 언급된 키워드
class RatingSummaryView extends StatelessWidget {
  const RatingSummaryView({super.key, required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              children: [
                Text(s.average.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                StarRow(rating: s.average, size: 18),
                const SizedBox(height: 2),
                Text('후기 ${s.count}개',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (var star = 5; star >= 1; star--)
                    _bar(star, s.distribution[star] ?? 0, s.count),
                ],
              ),
            ),
          ],
        ),
        if (s.topTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('많이 언급된 키워드',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (tag, n) in s.topTags)
                InfoBadge(label: '$tag $n', color: AppColors.primaryDark),
            ],
          ),
        ],
      ],
    );
  }

  Widget _bar(int star, int n, int total) {
    final ratio = total == 0 ? 0.0 : n / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$star점', style: const TextStyle(fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.placeholder,
                color: kStarColor,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('${(ratio * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// 후기 1건
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: r.mine ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRow(rating: r.rating.toDouble(), size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${r.author} · ${formatDate(r.date)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              if (r.mine) InfoBadge(label: '내 후기', color: AppColors.primaryDark),
            ],
          ),
          const SizedBox(height: 4),
          Text(r.context, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(r.text, style: const TextStyle(height: 1.5)),
          if (r.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final t in r.tags) InfoBadge(label: t, color: AppColors.textSecondary),
              ],
            ),
          ],
          if (!r.mine) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.thumb_up_alt_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('도움돼요 ${r.helpful}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ],
        ],
      ),
    );
  }
}

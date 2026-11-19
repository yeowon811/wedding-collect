import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../data/models/venue.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/repositories/venue_review_repository.dart';
import '../../vendor/widgets/review_widgets.dart' show StarRow;
import 'venue_image.dart';

/// 예식장 상세의 '후기' 자리: 앞으로 넣을 후기 기능을 보여 주는 AI 예시 후기.
/// 실제 후기로 오해하지 않게 맨 위에 "AI로 작성된 후기" 표시를 붙이고, 날짜·작성자·'도움돼요' 수는 만들지 않는다.
class VenueReviewSection extends StatelessWidget {
  const VenueReviewSection({super.key, required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final loaded = Repos.venueReview.cached;
    return FutureBuilder<List<VenueReview>>(
      future: loaded != null ? null : Repos.venueReview.of(venue.id),
      initialData: loaded?[venue.id],
      builder: (context, snap) {
        final list = snap.data ?? const <VenueReview>[];
        if (list.isEmpty) return const SizedBox.shrink();
        final avg = list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('후기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                StarRow(rating: avg, size: 16),
                const SizedBox(width: 4),
                Text('${avg.toStringAsFixed(1)} · 예시 ${list.length}개',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 8),
              // AI 작성 표시 (각주)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.auto_awesome, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'AI로 작성된 후기입니다. 예식장 정보(정원·대관료·주차 등)만 보고 만든 예시로, '
                      '실제 이용 후기가 아니에요. 이용자 후기 기능이 들어갈 자리를 보여 드려요.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.warning),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              for (final (i, r) in list.indexed) _tile(r, i),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(VenueReview r, int i) {
    // 사진: 예식장 공식 사진(있으면)을 후기 사진 자리에 보여 준다 (출처 표시)
    final photo = venue.images.isEmpty ? null : venue.images[(i + 1) % venue.images.length];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StarRow(rating: r.rating.toDouble(), size: 15),
          const SizedBox(width: 8),
          Text('AI 예시 후기 ${i + 1}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(r.text, style: const TextStyle(fontSize: 15, height: 1.5))),
          if (photo != null) ...[
            const SizedBox(width: 10),
            Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 72, height: 72, child: VenueImage(url: photo)),
              ),
              const SizedBox(height: 2),
              Text('사진: ${venue.collectSource ?? '기관'}',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ],
        ]),
        if (r.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final t in r.tags) InfoBadge(label: t, color: AppColors.textSecondary),
          ]),
        ],
      ]),
    );
  }
}

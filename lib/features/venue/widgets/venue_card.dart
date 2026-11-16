import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../data/app_state.dart';
import '../../../data/models/venue.dart';
import 'venue_image.dart';

/// 예식장 목록 카드 (디자인 시안 A): 큰 사진 → 지역 → 이름 → 정원·대관료·예약 방식 배지.
/// 카드 테두리·그림자 없이 흰 바탕 위에 사진과 글자만 둔다.
class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: venue.images.isEmpty ? 2.8 : 2.0,
                child: venue.images.isEmpty
                    ? const _NoPhoto()
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          VenueImage(url: venue.coverImage!),
                          if (venue.isAiImage(venue.coverImage!))
                            const Positioned(left: 10, top: 10, child: AiImageBadge()),
                          if (venue.images.length > 1)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('1 / ${venue.images.length}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(venue.region, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
                if (venue.isLimited)
                  const InfoBadge(label: '기간 제한', color: AppColors.warning, background: AppColors.warningSoft),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              venue.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _capacityBadge(venue),
                _feeBadge(venue),
                InfoBadge(label: venue.bookingType.label, color: AppColors.textBody, background: AppColors.fill),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 정원 배지: 내 하객 수를 수용하면 초록, 모자라면 주황, 모르면 회색
Widget _capacityBadge(Venue v) {
  final fits = v.fits(AppState.instance.plan.guests);
  return switch (fits) {
    true => InfoBadge(label: v.capacityLabel, color: AppColors.success, background: AppColors.successSoft),
    false => InfoBadge(label: v.capacityLabel, color: AppColors.warning, background: AppColors.warningSoft),
    null => InfoBadge(label: v.capacityLabel, color: AppColors.textSecondary, background: AppColors.fill),
  };
}

Widget _feeBadge(Venue v) => v.isFree
    ? InfoBadge(label: v.feeLabel, color: AppColors.success, background: AppColors.successSoft)
    : InfoBadge(
        label: v.feeLabel,
        color: v.rentalFee == null ? AppColors.textSecondary : AppColors.textBody,
        background: AppColors.fill,
      );

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.placeholder,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: AppColors.textHint, size: 28),
          const SizedBox(height: 4),
          Text('사진 준비 중', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

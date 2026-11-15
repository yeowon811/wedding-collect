import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../data/app_state.dart';
import '../../../data/models/venue.dart';
import 'booking_type_style.dart';
import 'venue_image.dart';

/// 예식장 목록 카드 (hotel_booking의 hotel_list_view 구조). 공유누리 사진이 있으면 위에 보여준다.
class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.25),
                  offset: const Offset(2, 4),
                  blurRadius: 12,
                ),
              ],
              color: AppColors.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (venue.images.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 2.4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          VenueImage(url: venue.images.first),
                          if (venue.images.length > 1)
                            Positioned(
                              right: 10,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('사진 ${venue.images.length}장',
                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                _RegionHeader(venue: venue, roundTop: venue.images.isEmpty),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              venue.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          InfoBadge(
                            label: venue.bookingType.label,
                            icon: venue.bookingType.icon,
                            color: venue.bookingType.color,
                          ),
                          _capacityBadge(venue),
                          InfoBadge(
                            label: venue.feeLabel,
                            icon: venue.rentalFee == null ? Icons.help_outline : Icons.payments_outlined,
                            color: venue.rentalFee == null
                                ? AppColors.unknown
                                : (venue.isFree ? AppColors.success : AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 정원 배지: 내 하객 수 기준으로 색을 바꾼다
Widget _capacityBadge(Venue v) {
  final guests = AppState.instance.plan.guests;
  final fits = v.fits(guests);
  return InfoBadge(
    label: fits == null ? '정원 확인 필요' : '정원 ${v.capacity}명',
    icon: fits == null ? Icons.help_outline : (fits ? Icons.groups : Icons.group_off_outlined),
    color: fits == null ? AppColors.unknown : (fits ? AppColors.success : AppColors.warning),
  );
}

class _RegionHeader extends StatelessWidget {
  const _RegionHeader({required this.venue, this.roundTop = true});

  final Venue venue;
  final bool roundTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: roundTop ? const BorderRadius.vertical(top: Radius.circular(16)) : null,
        gradient: LinearGradient(
          colors: [AppColors.headerStart, AppColors.headerEnd],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_outlined, color: AppColors.onHeader, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              venue.region,
              style: TextStyle(
                color: AppColors.onHeader,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              venue.isLimited ? '기간 제한' : '예약 가능',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: venue.isLimited ? AppColors.warning : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

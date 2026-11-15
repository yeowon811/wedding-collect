import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../data/models/venue.dart';
import 'booking_type_style.dart';

/// 예식장 목록 카드 (hotel_booking의 hotel_list_view 구조를 바탕으로, 사진 대신 지역 머리띠 사용)
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
                _RegionHeader(venue: venue),
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
                          InfoBadge(
                            label: venue.capacity == null
                                ? '수용 인원·대관료 확인 필요'
                                : '${venue.capacity}명 수용',
                            icon: Icons.help_outline,
                            color: AppColors.unknown,
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

class _RegionHeader extends StatelessWidget {
  const _RegionHeader({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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

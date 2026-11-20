import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/widgets/trait_chips.dart';
import '../../../data/app_state.dart';
import '../../../data/models/venue.dart';
import '../../chat/agent/venue_features.dart';
import 'venue_image.dart';

/// 예식장 격자 카드: 정사각형 사진 → 지역 → 이름(2줄) → 대관료(굵게) → 정원
class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  /// 카드에서 사진 아래 글자 영역의 높이 (격자 칸 높이 = 카드 폭 + 이 값)
  static const textHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final v = venue;
    final fits = v.fits(AppState.instance.plan.guests);
    final traits = VenueFeatures.traits(v);
    // 빈 값은 모든 화면에서 같은 말 ('… 문의 필요', 상세 화면에 연결처)
    final fee = v.rentalFee == null ? '대관료 문의 필요' : (v.isFree ? '대관료 무료' : v.feeLabel);
    final capacity = v.capacity == null
        ? '정원 문의 필요'
        : (v.capacityMin != null ? '${v.capacityMin}~${v.capacity}명' : '정원 ${v.capacity}명');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(fit: StackFit.expand, children: [
                      v.images.isEmpty ? const PhotoPlaceholder() : VenueImage(url: v.coverImage!),
                      if (v.isLimited)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('기간 제한',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ]),
              ),
              // 카드 위쪽 속성 배지 (데이터로 분류한 것만, 최대 3: 대관료 무료·실내 대강당/야외·피로연·주차, Red Team P1-4)
              if (traits.isNotEmpty)
                Positioned(left: 6, top: 6, right: 44, child: TraitChips(traits, onImage: true)),
              Positioned(right: 4, top: 4, child: FavoriteButton(ref: 'venue:${v.id}', onImage: true)),
            ]),
          ),
          const SizedBox(height: 8),
          Text(v.region,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          SizedBox(
            height: 40,
            child: Text(
              v.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: fee),
              // 대관료 무료만 따로 보이지 않게 (식대·꽃장식은 따로, Red Team P1-2)
              if (v.isFree)
                TextSpan(
                    text: ' · 식대 별도',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: v.isFree ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: capacity),
              if (fits == true)
                const TextSpan(text: ' · 하객 수용', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

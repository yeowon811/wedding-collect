import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../data/app_state.dart';
import '../../../data/models/vendor.dart';
import '../../../data/repositories/review_repository.dart';
import 'vendor_photo.dart';

/// 시연용 업체 카드: 가격대, 평점, 패키지, 비교 담기
class DemoVendorCard extends StatelessWidget {
  const DemoVendorCard({super.key, required this.vendor, required this.onTap});

  final DemoVendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _grid(context);

  /// 격자 카드: 4:3 회색 면(항목 아이콘) → 항목·지역 → 이름(2줄) → 가격대(굵게) → 평점. 비교 담기는 사진 위 버튼
  Widget _grid(BuildContext context) {
    final state = AppState.instance;
    final v = vendor;
    final summary = ReviewRepository.summaryFor(v);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3, // 업체는 사진이 없어 낮게
            child: Stack(children: [
              Positioned.fill(
                child: Container(
                  // 흰 바탕 로고 사진도 칸이 보이게 1px 테두리
                  foregroundDecoration: BoxDecoration(
                      border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: VendorPhoto(category: v.category, vendorId: v.id),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: ListenableBuilder(
                  listenable: state,
                  builder: (context, _) {
                    final on = state.inCompare(v);
                    return IconButton(
                      style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.92)),
                      tooltip: on ? '비교 중' : '비교 담기',
                      onPressed: () => state.toggleCompare(v),
                      icon: Icon(on ? Icons.check_circle : Icons.add_circle_outline,
                          color: on ? AppColors.primary : AppColors.textSecondary),
                    );
                  },
                ),
              ),
              if (v.publicVenueOk)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                    child: const Text('공공예식장 출장',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Text('${v.category.label} · ${v.sido}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          SizedBox(
            height: 40,
            child: Text(v.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 6),
          Text(v.priceText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF2B33D)),
            Text(' ${summary.average}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBody)),
            Text(' (${summary.count})', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ],
      ),
    );
  }
}

/// 실제 연계업체 격자 카드: 시연용 카드와 같은 틀, 가격 대신 "가격 문의", 공식전담이면 체크 표시
class RealVendorTile extends StatelessWidget {
  const RealVendorTile({super.key, required this.vendor, required this.onTap});

  final RealVendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = vendor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(children: [
              Positioned.fill(
                child: Container(
                  // 흰 바탕 로고 사진도 칸이 보이게 1px 테두리
                  foregroundDecoration: BoxDecoration(
                      border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: VendorPhoto(category: v.category, vendorId: v.id, url: v.image),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                right: 8,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: v.isOfficial ? OfficialMark(label: v.official) : const _PlainMark('실제 업체'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text('${v.categoryText} · ${v.sido}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          SizedBox(
            height: 40,
            child: Text(v.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 6),
          Text('가격 문의',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(v.sigungu.isEmpty ? v.sido : v.sigungu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 공식전담 업체 체크 표시: ✓ 공식전담(서울시)
class OfficialMark extends StatelessWidget {
  const OfficialMark({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 7, 3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified, size: 13, color: AppColors.primary),
        const SizedBox(width: 3),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ]),
    );
  }
}

class _PlainMark extends StatelessWidget {
  const _PlainMark(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }
}

/// 실제 연계업체 목록형 카드 (예식장 상세의 근처 업체): 가격 없이 위치·연락처·공식 연계 여부
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
              v.isOfficial
                  ? OfficialMark(label: v.official)
                  : InfoBadge(label: '실제 업체', color: AppColors.textSecondary),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

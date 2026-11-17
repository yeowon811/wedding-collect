import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vendor.dart';
import '../../../data/repositories/stock_photos.dart';
import '../../venue/widgets/venue_image.dart';

/// 업체 사진 한 장: 실제 업체 홈페이지 사진 → 없으면 항목별 무료 사진(위키미디어) → 그래도 없으면 아이콘
class VendorPhoto extends StatelessWidget {
  const VendorPhoto({super.key, required this.category, required this.vendorId, this.url});

  final VendorCategory category;
  final String vendorId;
  final String? url; // 실제 업체 홈페이지 대표 사진

  @override
  Widget build(BuildContext context) {
    if (url != null) return ColoredBox(color: AppColors.fill, child: VenueImage(url: url!));
    final stock = StockPhotos.pick(category, vendorId);
    if (stock != null) {
      return ColoredBox(color: AppColors.fill, child: VenueImage(url: stock.url));
    }
    return _icon();
  }

  Widget _icon() => ColoredBox(
        color: AppColors.fill,
        child: Center(child: Icon(category.icon, size: 36, color: AppColors.textHint)),
      );
}

/// 상세 화면 맨 위 사진과 출처: 홈페이지 사진이면 "사진: 도메인", 무료 사진이면 저작자·라이선스
/// (실제 업체에 무료 사진을 쓴 경우 "참고 이미지 · 업체 사진 아님")
class VendorPhotoHeader extends StatelessWidget {
  const VendorPhotoHeader(
      {super.key, required this.category, required this.vendorId, this.url, this.site, this.isReal = false});

  final VendorCategory category;
  final String vendorId;
  final String? url;
  final String? site;
  final bool isReal;

  @override
  Widget build(BuildContext context) {
    final stock = url == null ? StockPhotos.pick(category, vendorId) : null;
    if (url == null && stock == null) return const SizedBox.shrink();
    final caption = url != null
        ? '사진: ${Uri.tryParse(site ?? '')?.host.replaceFirst('www.', '') ?? '업체 홈페이지'}'
        : '${isReal ? '참고 이미지 · 업체 사진 아님 · ' : ''}${stock!.credit}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: VendorPhoto(category: category, vendorId: vendorId, url: url),
        ),
      ),
      const SizedBox(height: 6),
      Text(caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }
}

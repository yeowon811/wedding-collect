import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 네트워크 사진 한 장 (예식장·업체·무료 사진 공통). 불러오지 못하면 같은 모양의 아이콘 자리표시 [PhotoPlaceholder]
/// (예식장은 건물, 업체는 그 항목 아이콘)를 보여 준다 (Red Team P1-4: 실패 화면 통일).
///
/// 공유누리 서버는 웹 브라우저용 CORS 헤더를 주지 않아, 웹에서는 일반 이미지 태그로 대신 보여준다
/// ([WebHtmlElementStrategy.fallback]). 안드로이드 앱에서는 그대로 불러온다.
class VenueImage extends StatelessWidget {
  const VenueImage({super.key, required this.url, this.fit = BoxFit.cover, this.placeholderIcon = Icons.location_city});

  final String url;
  final BoxFit fit;
  final IconData placeholderIcon; // 실패했을 때 보일 분야 아이콘

  @override
  Widget build(BuildContext context) {
    // 웹 대체 모드는 사진 크기를 아직 모를 때(0×0) 크기 계산이 깨질 수 있어, 그릴 크기를 직접 정해 준다.
    // 바탕은 자리표시와 같은 회색: 웹 대체 모드(이미지 태그)가 불러오는 동안 흰 칸으로 비지 않게
    return ColoredBox(
      color: AppColors.placeholder,
      child: LayoutBuilder(
        builder: (context, c) => _image(
          c.hasBoundedWidth ? c.maxWidth : null,
          c.hasBoundedHeight ? c.maxHeight : null,
        ),
      ),
    );
  }

  Widget _image(double? width, double? height) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: AppColors.placeholder,
              alignment: Alignment.center,
              child: const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorBuilder: (context, error, stack) => PhotoPlaceholder(icon: placeholderIcon),
    );
  }
}

/// 사진이 없거나 불러오지 못했을 때의 자리표시 (앱 전체 하나): 회색 면 + 분야 아이콘 (+ 큰 칸이면 '사진 없음')
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.icon = Icons.location_city, this.label = '사진 없음'});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.placeholder,
      alignment: Alignment.center,
      // 작은 칸(후기 사진 썸네일 등)에서는 아이콘만
      child: LayoutBuilder(
        builder: (context, box) => box.maxHeight < 90
            ? Icon(icon, size: 24, color: AppColors.textHint)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 34, color: AppColors.textHint),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
      ),
    );
  }
}

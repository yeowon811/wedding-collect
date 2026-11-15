import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 공유누리 예식장 사진. 불러오지 못하면 회색 자리표시를 보여준다.
///
/// 공유누리 서버는 웹 브라우저용 CORS 헤더를 주지 않아, 웹에서는 일반 이미지 태그로 대신 보여준다
/// ([WebHtmlElementStrategy.fallback]). 안드로이드 앱에서는 그대로 불러온다.
class VenueImage extends StatelessWidget {
  const VenueImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // 웹 대체 모드는 사진 크기를 아직 모를 때(0×0) 크기 계산이 깨질 수 있어, 그릴 크기를 직접 정해 준다
    return LayoutBuilder(
      builder: (context, c) => _image(
        c.hasBoundedWidth ? c.maxWidth : null,
        c.hasBoundedHeight ? c.maxHeight : null,
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
      errorBuilder: (context, error, stack) => const VenueImagePlaceholder(),
    );
  }
}

class VenueImagePlaceholder extends StatelessWidget {
  const VenueImagePlaceholder({super.key, this.label = '사진 준비 중'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.placeholder,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 36, color: AppColors.unknown),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.unknown)),
        ],
      ),
    );
  }
}

/// AI 생성 이미지 표시 (실제 사진이 아님을 알림)
class AiImageBadge extends StatelessWidget {
  const AiImageBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xCC5B3FA8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text('AI 생성 이미지', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

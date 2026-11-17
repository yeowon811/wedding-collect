import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../theme/app_colors.dart';

/// 찜(하트) 버튼. [ref]는 'venue:H078'·'vendor:D0001'·'real:V003'·'policy:P012'.
/// 사진 위([onImage])에서는 흰 테두리 하트(사진이 밝아도 보이게 그림자), 흰 바탕 위에서는 회색 하트.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.ref, this.onImage = false, this.size = 24});

  final String ref;
  final bool onImage;
  final double size;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final on = state.isFavorite(ref);
        final color = on ? const Color(0xFFF04452) : (onImage ? Colors.white : AppColors.textHint);
        return IconButton(
          // 사진 위: 흰 바탕 로고 사진에서도 보이게 옅은 검정 원
          style: onImage ? IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.18)) : null,
          tooltip: on ? '찜 해제' : '찜하기',
          onPressed: () {
            state.toggleFavorite(ref);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(on ? '찜 목록에서 뺐어요' : '찜 목록에 담았어요'),
                duration: const Duration(seconds: 2),
              ));
          },
          icon: Icon(
            on ? Icons.favorite : Icons.favorite_border,
            size: onImage ? size - 2 : size,
            color: color,
            shadows: onImage ? const [Shadow(color: Color(0x66000000), blurRadius: 6)] : null,
          ),
        );
      },
    );
  }
}

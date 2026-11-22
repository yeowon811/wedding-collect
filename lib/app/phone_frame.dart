import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// 컴퓨터 브라우저처럼 넓은 화면에서 웹을 열면 앱을 가운데 휴대폰 크기로 보여 준다 (11-22).
/// 심사위원이 링크만 열어도 시연 영상과 같은 휴대폰 화면을 보게 하기 위함.
/// 휴대폰·좁은 창에서는 그대로 화면 전체를 쓴다. 대화상자·아래 시트도 이 틀 안에 뜬다.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  /// 이보다 넓으면 틀을 씌운다
  static const double minWideWidth = 700;

  /// 휴대폰 화면 크기 (논리 픽셀, 일반적인 안드로이드·아이폰 크기)
  static const Size phone = Size(390, 844);

  static bool enabled = kIsWeb;

  /// 틀 바깥 바탕 (로즈 테마의 아주 연한 분홍)
  static const Color frameBackdrop = Color(0xFFF7EBF0);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (!enabled || mq.size.width < minWideWidth) return child;
    const margin = 24.0;
    final height = math.min(phone.height, mq.size.height - margin * 2).clamp(480.0, phone.height);
    final size = Size(phone.width, height);
    return ColoredBox(
      color: frameBackdrop,
      child: Center(
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 32, offset: Offset(0, 12))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: MediaQuery(
              // 안쪽 화면은 휴대폰 크기라고 알려 준다 (넓은 화면용 배치가 켜지지 않게)
              data: mq.copyWith(
                size: size,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 웹에서 마우스로도 끌어서 넘기기(배너·사진첩)가 되게 하고, 폰처럼 스크롤 막대를 숨긴다
class PhoneScrollBehavior extends MaterialScrollBehavior {
  const PhoneScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

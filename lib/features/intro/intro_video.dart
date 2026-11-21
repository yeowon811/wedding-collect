import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';

/// 앱을 켜면 먼저 나오는 시작 영상 (11-21 사용자 요청, 사용자 제공 영상 3초·소리 없음).
/// 끝나면 [onDone] → 로그인 화면(로그인 상태면 앱). 화면을 누르거나 [건너뛰기]로 바로 넘어간다.
/// 영상을 못 불러오거나(브라우저 자동 재생 막힘 등) 시간이 지나도 끝나지 않으면 기다리지 않고 넘어간다.
class IntroVideo extends StatefulWidget {
  const IntroVideo({super.key, required this.onDone});

  final VoidCallback onDone;

  /// 테스트에서는 끈다 (영상 플러그인이 없음). 시연 링크(?demo 등)에서도 main에서 끈다
  static bool enabled = true;

  static const asset = 'assets/video/we_connect_intro.mp4';

  @override
  State<IntroVideo> createState() => _IntroVideoState();
}

class _IntroVideoState extends State<IntroVideo> {
  VideoPlayerController? _video;
  Timer? _guard;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // 영상이 시작조차 못 해도 6초 뒤에는 넘어간다
    _guard = Timer(const Duration(seconds: 6), _finish);
    _start();
  }

  Future<void> _start() async {
    try {
      final c = VideoPlayerController.asset(IntroVideo.asset);
      _video = c;
      await c.initialize().timeout(const Duration(seconds: 3));
      await c.setVolume(0); // 웹 자동 재생은 소리가 없어야 허용된다
      if (!mounted || _done) return;
      c.addListener(() {
        final v = c.value;
        if (v.hasError || (v.isInitialized && v.duration > Duration.zero && v.position >= v.duration)) _finish();
      });
      // 영상 길이 + 여유 0.5초 뒤에도 끝 신호가 없으면 넘어간다
      _guard?.cancel();
      _guard = Timer(c.value.duration + const Duration(milliseconds: 500), _finish);
      setState(() {});
      await c.play();
    } catch (_) {
      _finish();
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _guard?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _guard?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _video;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Stack(fit: StackFit.expand, children: [
          if (ready)
            // 세로 영상(1080×1920)을 화면에 꽉 차게 (넘치는 가장자리만 잘림)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
            )
          else
            // 불러오는 동안: 흰 바탕에 앱 로고
            Center(
              child: Image.asset('assets/images/brand/rings_rose.png',
                  height: 72, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          Positioned(
            right: 12,
            top: 0,
            child: SafeArea(
              child: TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  backgroundColor: Colors.white.withValues(alpha: 0.7),
                  shape: const StadiumBorder(),
                ),
                child: const Text('건너뛰기'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

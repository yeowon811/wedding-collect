import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 목록을 불러오는 동안 보여주는 회색 틀 (스켈레톤). 빙글빙글 아이콘보다 기다림이 짧게 느껴진다.
/// [kind]에 따라 실제 카드와 비슷한 모양을 그린다.
enum SkeletonKind { photoCard, textCard }

class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.kind = SkeletonKind.textCard, this.count = 4, this.header = true});

  final SkeletonKind kind;
  final int count;
  final bool header; // 제목·칩 자리도 함께 그릴지

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '불러오는 중',
      child: FadeTransition(
        opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          children: [
            if (widget.header) ...[
              const _Box(width: 140, height: 26),
              const SizedBox(height: 10),
              const _Box(width: 200, height: 14),
              const SizedBox(height: 20),
              Row(children: const [
                _Box(width: 64, height: 36, radius: 18),
                SizedBox(width: 8),
                _Box(width: 72, height: 36, radius: 18),
                SizedBox(width: 8),
                _Box(width: 72, height: 36, radius: 18),
              ]),
              const SizedBox(height: 24),
            ],
            for (var i = 0; i < widget.count; i++) ...[
              if (widget.kind == SkeletonKind.photoCard) ...[
                const AspectRatio(aspectRatio: 2.0, child: _Box(radius: 16)),
                const SizedBox(height: 12),
                const _Box(width: 80, height: 13),
                const SizedBox(height: 8),
                const _Box(width: 220, height: 18),
                const SizedBox(height: 10),
                Row(children: const [
                  _Box(width: 70, height: 26, radius: 6),
                  SizedBox(width: 6),
                  _Box(width: 80, height: 26, radius: 6),
                ]),
                const SizedBox(height: 28),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _Box(width: 60, height: 24, radius: 6),
                        SizedBox(width: 6),
                        _Box(width: 44, height: 24, radius: 6),
                      ]),
                      SizedBox(height: 12),
                      _Box(width: 240, height: 18),
                      SizedBox(height: 8),
                      _Box(height: 13),
                      SizedBox(height: 6),
                      _Box(width: 180, height: 13),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({this.width, this.height, this.radius = 6});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

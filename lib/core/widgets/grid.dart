import 'package:flutter/material.dart';

/// 2열(넓은 화면에서는 더 많이) 카드 격자. 좌우 여백 20, 카드 사이 12.
/// 휴대폰은 2열, 태블릿·PC 웹은 카드 폭이 [maxTileWidth]를 넘지 않게 열을 늘린다.
class GridSpec {
  const GridSpec(this.columns, this.tileWidth);

  final int columns;
  final double tileWidth;

  static const sidePadding = 20.0;
  static const gap = 12.0;

  static GridSpec of(double width, {double maxTileWidth = 220, int minColumns = 2}) {
    final inner = width - sidePadding * 2;
    var cols = ((inner + gap) / (maxTileWidth + gap)).floor();
    if (cols < minColumns) cols = minColumns;
    return GridSpec(cols, (inner - gap * (cols - 1)) / cols);
  }
}

/// 목록 안(ListView 등)에 넣는 격자. 항목 수가 적은 곳(정책·업체)에 쓴다.
class TileGrid extends StatelessWidget {
  const TileGrid(
      {super.key, required this.children, this.runSpacing = 16, this.maxTileWidth = 220, this.minColumns = 2});

  final List<Widget> children;
  final double runSpacing;
  final double maxTileWidth;
  final int minColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final spec = GridSpec.of(box.maxWidth, maxTileWidth: maxTileWidth, minColumns: minColumns);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: GridSpec.sidePadding),
        child: Wrap(
          spacing: GridSpec.gap,
          runSpacing: runSpacing,
          children: [for (final c in children) SizedBox(width: spec.tileWidth, child: c)],
        ),
      );
    });
  }
}

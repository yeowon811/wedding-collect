import 'package:flutter/material.dart';

import '../utils/region.dart';

/// 거주 지역: 시·도 → 시·군·구 두 칸 (입력하면 목록이 좁혀지는 드롭다운).
/// 시·도를 바꾸면 시·군·구는 비운다. 시·군·구는 몰라도 된다(선택).
class RegionFields extends StatelessWidget {
  const RegionFields({super.key, required this.sido, required this.sigungu, required this.onChanged});

  final String? sido;
  final String? sigungu;
  final void Function(String? sido, String? sigungu) onChanged;

  @override
  Widget build(BuildContext context) {
    final towns = sido == null ? const <String>[] : (kSigunguBySido[sido] ?? const <String>[]);
    return LayoutBuilder(
      builder: (context, box) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownMenu<String>(
          key: ValueKey('sido-$sido'),
          width: box.maxWidth,
          initialSelection: sido,
          hintText: '시·도 선택',
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 260,
          leadingIcon: const Icon(Icons.place_outlined),
          dropdownMenuEntries: [for (final s in kSidoList) DropdownMenuEntry(value: s, label: s)],
          onSelected: (s) {
            if (s != null && s != sido) onChanged(s, null);
          },
        ),
        const SizedBox(height: 8),
        DropdownMenu<String>(
          key: ValueKey('sigungu-$sido-$sigungu'),
          width: box.maxWidth,
          enabled: towns.isNotEmpty,
          initialSelection: sigungu,
          hintText: sido == null ? '시·도를 먼저 선택해 주세요.' : '시·군·구 (예: ${towns.first}, 선택)',
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 260,
          leadingIcon: const Icon(Icons.location_city_outlined),
          dropdownMenuEntries: [for (final g in towns) DropdownMenuEntry(value: g, label: g)],
          onSelected: (g) {
            if (g != null) onChanged(sido, g);
          },
        ),
      ]),
    );
  }
}

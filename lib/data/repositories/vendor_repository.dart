import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/vendor.dart';

/// 실제 업체, 시연용 업체, 예식장-업체 매칭 데이터를 읽는다.
class VendorRepository {
  List<RealVendor>? _real;
  List<DemoVendor>? _demo;
  Map<String, List<VendorMatch>>? _matches;

  Future<List<dynamic>> _json(String name) async =>
      jsonDecode(await rootBundle.loadString('assets/data/$name')) as List<dynamic>;

  Future<List<RealVendor>> realVendors() async => _real ??= (await _json('vendors.json'))
      .cast<Map<String, dynamic>>()
      .map(RealVendor.fromJson)
      .toList(growable: false);

  Future<List<DemoVendor>> demoVendors() async => _demo ??= (await _json('demo_vendors.json'))
      .cast<Map<String, dynamic>>()
      .map(DemoVendor.fromJson)
      .toList(growable: false);

  Future<Map<String, List<VendorMatch>>> _allMatches() async {
    if (_matches != null) return _matches!;
    final raw = jsonDecode(await rootBundle.loadString('assets/data/venue_vendor_matches.json'))
        as Map<String, dynamic>;
    return _matches = raw.map((k, v) => MapEntry(
          k,
          (v as List).cast<Map<String, dynamic>>().map(VendorMatch.fromJson).toList(),
        ));
  }

  /// 예식장 근처 실제 업체 (분류별 상위 [perCategory]곳)
  Future<List<(VendorMatch, RealVendor)>> nearbyFor(String venueId, {int perCategory = 2}) async {
    final matches = (await _allMatches())[venueId] ?? const [];
    final byId = {for (final v in await realVendors()) v.id: v};
    final result = <(VendorMatch, RealVendor)>[];
    for (final m in matches) {
      if (m.rank > perCategory) continue;
      final v = byId[m.vendorId];
      if (v != null) result.add((m, v));
    }
    return result;
  }
}

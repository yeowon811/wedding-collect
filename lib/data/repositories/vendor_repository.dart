import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/vendor.dart';
import 'stock_photos.dart';

/// 실제 업체, 시연용 업체, 예식장-업체 매칭 데이터를 읽는다.
class VendorRepository {
  List<RealVendor>? _real;
  List<DemoVendor>? _demo;
  Map<String, List<VendorMatch>>? _matches;

  Future<List<dynamic>> _json(String name) async =>
      jsonDecode(await rootBundle.loadString('assets/data/$name'))
          as List<dynamic>;

  Future<List<RealVendor>> realVendors() async {
    if (_real != null) return _real!;
    await StockPhotos.load();
    // 대표 이미지: tools/collect_vendor_images.py가 업체 홈페이지에서 찾은 주소
    final images = (jsonDecode(await rootBundle.loadString('assets/data/vendor_images.json'))
        as Map<String, dynamic>)['images'] as Map<String, dynamic>;
    return _real = (await _json('vendors.json'))
        .cast<Map<String, dynamic>>()
        .map((j) => RealVendor.fromJson(j).withImage((images[j['id']] as Map?)?['image'] as String?))
        .toList(growable: false);
  }

  Future<List<DemoVendor>> demoVendors() async {
    if (_demo != null) return _demo!;
    await StockPhotos.load(); // 처음 한 번만 (테스트에서 다른 영역의 Future를 다시 기다리면 멈춤)
    return _demo = (await _json('demo_vendors.json'))
          .cast<Map<String, dynamic>>()
          .map(DemoVendor.fromJson)
          .toList(growable: false);
  }

  Future<Map<String, List<VendorMatch>>> _allMatches() async {
    if (_matches != null) return _matches!;
    final raw = jsonDecode(
      await rootBundle.loadString('assets/data/venue_vendor_matches.json'),
    ) as Map<String, dynamic>;
    return _matches = raw.map(
      (k, v) => MapEntry(
        k,
        (v as List)
            .cast<Map<String, dynamic>>()
            .map(VendorMatch.fromJson)
            .toList(),
      ),
    );
  }

  /// 예식장 근처 실제 업체 (분류별 상위 [perCategory]곳)
  Future<List<(VendorMatch, RealVendor)>> nearbyFor(
    String venueId, {
    int perCategory = 2,
  }) async {
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

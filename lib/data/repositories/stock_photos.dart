import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/vendor.dart';

/// 무료 사진 (Wikimedia Commons, CC0·공공 도메인·CC BY·CC BY-SA): 항목별 3~4장을 업체끼리 돌려 쓴다.
/// - [시연] 가상 업체: 항목 사진
/// - 사진이 없는 실제 연계업체: 분류에 맞는 참고 사진 (업체 사진이 아님을 상세 화면에 표시)
/// 수집·출처 표: tools/collect_stock_images.py → assets/data/stock_images.json
class StockPhoto {
  const StockPhoto({required this.url, required this.creator, required this.license, required this.source});

  final String url; // 위키미디어 축소본 주소 (앱이 직접 불러옴)
  final String creator;
  final String license;
  final String source; // 위키미디어 파일 페이지

  /// 저작자 표시 (CC BY): "사진: 작성자 · CC BY 2.0 · Wikimedia Commons"
  String get credit => '사진: $creator · $license · Wikimedia Commons';
}

class StockPhotos {
  StockPhotos._();

  static Map<String, List<StockPhoto>> _byKey = const {};
  static Future<void>? _loading;

  static Future<void> load() => _loading ??= () async {
        final raw = jsonDecode(await rootBundle.loadString('assets/data/stock_images.json')) as Map<String, dynamic>;
        _byKey = {
          for (final e in raw.entries)
            e.key: [
              for (final p in (e.value as List).cast<Map<String, dynamic>>())
                StockPhoto(
                  url: p['url'] as String,
                  creator: p['creator'] as String,
                  license: p['license'] as String,
                  source: p['source'] as String,
                ),
            ],
        };
      }();

  /// 실제 업체 분류 → 쓸 사진 묶음
  static const _realPools = {
    VendorCategory.directing: ['dress', 'makeup', 'props'],
    VendorCategory.catering: ['meal'],
    VendorCategory.photo: ['studio', 'snap'],
    VendorCategory.host: ['host'],
  };

  /// 업체 ID로 고정해서 고른다 (다시 열어도 같은 사진)
  static StockPhoto? pick(VendorCategory category, String vendorId) {
    final keys = _realPools[category] ?? [category.name];
    final pool = [for (final k in keys) ...?_byKey[k]];
    if (pool.isEmpty) return null;
    final n = int.tryParse(vendorId.replaceAll(RegExp(r'\D'), '')) ?? vendorId.hashCode;
    return pool[n % pool.length];
  }
}

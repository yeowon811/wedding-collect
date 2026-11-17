import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/venue.dart';

/// 공공예식장 데이터를 앱에 내장된 JSON(assets/data/venues.json)에서 읽는다.
/// 나중에 서버나 로컬 DB로 바꿔도 화면 코드는 그대로 두면 된다.
class VenueRepository {
  List<Venue>? _cache;

  /// 이미 읽어 둔 목록 (아직이면 null)
  List<Venue>? get cached => _cache;

  Future<List<Venue>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/venues.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _cache = list.map(Venue.fromJson).toList(growable: false);
    return _cache!;
  }
}

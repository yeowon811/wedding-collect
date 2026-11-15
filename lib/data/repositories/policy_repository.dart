import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/policy.dart';

/// 정책 데이터를 앱에 내장된 JSON(assets/data/policies.json)에서 읽는다.
class PolicyRepository {
  List<Policy>? _cache;

  Future<List<Policy>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/policies.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _cache = list.map(Policy.fromJson).toList(growable: false);
    return _cache!;
  }
}

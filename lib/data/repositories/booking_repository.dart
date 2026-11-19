import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/booking_status.dart';

/// 예식장 날짜별 예약 현황 (assets/data/booking_status.json, 수집 시점 스냅샷)
class BookingRepository {
  Map<String, BookingStatus>? _cache;
  DateTime? _collectedAt;

  Map<String, BookingStatus>? get cached => _cache;
  DateTime? get collectedAt => _collectedAt;

  Future<Map<String, BookingStatus>> loadAll() async {
    if (_cache != null) return _cache!;
    // loadString은 큰 파일을 별도 isolate로 넘기는데, 여기선 작아서 바로 디코딩한다
    final bytes = await rootBundle.load('assets/data/booking_status.json');
    final j = jsonDecode(utf8.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)))
        as Map<String, dynamic>;
    _collectedAt = DateTime.tryParse(j['collectedAt'] as String? ?? '');
    _cache = {
      for (final e in (j['venues'] as Map<String, dynamic>).entries)
        e.key: BookingStatus.fromJson(e.key, e.value as Map<String, dynamic>),
    };
    return _cache!;
  }

  /// 예약 현황이 없는 예식장(폼·전화·기타 사이트)은 null
  Future<BookingStatus?> of(String venueId) async => (await loadAll())[venueId];
}

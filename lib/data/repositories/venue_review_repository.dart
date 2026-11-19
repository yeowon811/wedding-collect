import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 공공예식장 'AI 예시 후기' 1건.
/// 실제 이용 후기가 아니라, AI(Gemini)가 예식장 공개 정보만 보고 쓴 예시다 (tools/venue_review_gen_main.dart).
/// 화면에는 항상 "AI로 작성된 예시 후기" 표시와 함께 보여 주고, 목록 정렬·AI 상담 답변에는 쓰지 않는다.
class VenueReview {
  const VenueReview({required this.rating, required this.text, required this.tags});

  final int rating; // 1~5
  final String text;
  final List<String> tags;

  factory VenueReview.fromJson(Map<String, dynamic> j) => VenueReview(
        rating: (j['rating'] as num).toInt().clamp(1, 5),
        text: j['text'] as String,
        tags: (j['tags'] as List? ?? const []).cast<String>(),
      );
}

/// assets/data/venue_reviews.json (AI 예시 후기)
class VenueReviewRepository {
  Map<String, List<VenueReview>>? _cache;

  Map<String, List<VenueReview>>? get cached => _cache;

  Future<Map<String, List<VenueReview>>> loadAll() async {
    if (_cache != null) return _cache!;
    final bytes = await rootBundle.load('assets/data/venue_reviews.json');
    final j = jsonDecode(utf8.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)))
        as Map<String, dynamic>;
    _cache = {
      for (final e in (j['venues'] as Map<String, dynamic>).entries)
        e.key: [for (final r in (e.value as List)) VenueReview.fromJson(r as Map<String, dynamic>)],
    };
    return _cache!;
  }

  Future<List<VenueReview>> of(String venueId) async => (await loadAll())[venueId] ?? const [];
}

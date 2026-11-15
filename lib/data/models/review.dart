/// 업체 후기 1건 (시연용 가상 업체에만 존재)
class Review {
  const Review({
    required this.id,
    required this.vendorId,
    required this.author,
    required this.rating,
    required this.date,
    required this.text,
    required this.tags,
    required this.context,
    required this.helpful,
    this.mine = false,
  });

  final String id;
  final String vendorId;
  final String author; // 가려진 닉네임
  final int rating; // 1~5
  final DateTime date;
  final String text;
  final List<String> tags; // "친절해요" 같은 키워드
  final String context; // 예: 공공예식장 · 하객 80명
  final int helpful; // "도움돼요" 수
  final bool mine; // 내가 쓴 후기
}

/// 업체 평점 요약
class ReviewSummary {
  const ReviewSummary({
    required this.average,
    required this.count,
    required this.distribution,
    required this.topTags,
  });

  final double average;
  final int count;
  final Map<int, int> distribution; // 별점 → 인원
  final List<(String, int)> topTags; // 키워드, 언급 수
}

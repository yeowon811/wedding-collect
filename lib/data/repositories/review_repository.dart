import 'dart:math';

import '../app_state.dart';
import '../models/review.dart';
import '../models/vendor.dart';

/// 시연용 업체 후기를 만든다.
///
/// - 업체 ID로 고정된 난수를 써서 매번 같은 후기가 나온다 (시연·발표 때 화면이 바뀌지 않음).
/// - 별점 분포는 업체 평점([DemoVendor.rating])과 후기 수에 정확히 맞춘다.
/// - 실제 업체(103곳)에는 후기를 만들지 않는다. 실제 업체 이름으로 가짜 후기를 보여주면 안 되기 때문.
class ReviewRepository {
  ReviewRepository._();

  static const sampleSize = 30; // 화면에 보여줄 최근 후기 수

  static final _distCache = <String, Map<int, int>>{};
  static final _reviewCache = <String, List<Review>>{};

  static int _seed(String id) => id.codeUnits.fold(17, (a, b) => (a * 31 + b) & 0x7fffffff);

  /// 평균이 [DemoVendor.rating]이 되도록 별점별 인원을 나눈다.
  static Map<int, int> _distribution(DemoVendor v) => _distCache.putIfAbsent(v.id, () {
        final rnd = Random(_seed(v.id));
        final n = v.reviewCount;
        final c = {5: n, 4: 0, 3: 0, 2: 0, 1: 0};
        var drop = 5 * n - (v.rating * n).round(); // 5점에서 깎아야 할 점수 합
        while (drop > 0) {
          final x = rnd.nextDouble();
          if (x < 0.68 && c[5]! > 0) {
            c[5] = c[5]! - 1;
            c[4] = c[4]! + 1;
          } else if (x < 0.9 && c[4]! > 0) {
            c[4] = c[4]! - 1;
            c[3] = c[3]! + 1;
          } else if (x < 0.97 && c[3]! > 0) {
            c[3] = c[3]! - 1;
            c[2] = c[2]! + 1;
          } else if (c[2]! > 0) {
            c[2] = c[2]! - 1;
            c[1] = c[1]! + 1;
          } else if (c[5]! > 0) {
            c[5] = c[5]! - 1;
            c[4] = c[4]! + 1;
          } else {
            break;
          }
          drop--;
        }
        return c;
      });

  /// 최근 후기 (내가 쓴 후기가 맨 앞)
  static List<Review> reviewsFor(DemoVendor v) {
    final generated = _reviewCache.putIfAbsent(v.id, () => _generate(v));
    final mine = AppState.instance.myReviews.where((r) => r.vendorId == v.id).toList();
    return [...mine.reversed, ...generated];
  }

  static ReviewSummary summaryFor(DemoVendor v) {
    final dist = Map<int, int>.from(_distribution(v));
    final mine = AppState.instance.myReviews.where((r) => r.vendorId == v.id);
    for (final r in mine) {
      dist[r.rating] = dist[r.rating]! + 1;
    }
    final count = dist.values.fold(0, (a, b) => a + b);
    final sum = dist.entries.fold(0, (a, e) => a + e.key * e.value);

    final tagCount = <String, int>{};
    for (final r in reviewsFor(v)) {
      for (final t in r.tags) {
        tagCount[t] = (tagCount[t] ?? 0) + 1;
      }
    }
    final top = tagCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ReviewSummary(
      average: count == 0 ? 0 : (sum / count * 10).round() / 10,
      count: count,
      distribution: dist,
      topTags: [for (final e in top.take(4)) (e.key, e.value)],
    );
  }

  static List<Review> _generate(DemoVendor v) {
    final rnd = Random(_seed(v.id) ^ 0x5bd1e995);
    final dist = _distribution(v);
    final n = min(v.reviewCount, sampleSize);

    // 분포 비율대로 별점 뽑기
    final pool = <int>[
      for (final e in dist.entries) ...List.filled(e.value, e.key),
    ]..shuffle(rnd);

    final now = DateTime.now();
    final list = <Review>[];
    for (var i = 0; i < n; i++) {
      final rating = pool[i % pool.length];
      final band = rating >= 4 ? 'good' : (rating == 3 ? 'mid' : 'bad');
      final texts = <String>[
        if (band == 'good') ...[
          _pick(rnd, _categoryGood[v.category] ?? const []),
          _pick(rnd, _good),
        ] else if (band == 'mid') ...[
          _pick(rnd, _categoryGood[v.category] ?? const []),
          _pick(rnd, _mid),
        ] else ...[
          _pick(rnd, _bad),
        ],
      ].where((t) => t.isNotEmpty).toSet().toList();

      final tags = <String>{
        _pick(rnd, band == 'good' ? _goodTags : _badTags),
        if (rnd.nextBool()) _pick(rnd, band == 'bad' ? _badTags : _goodTags),
      }.toList();

      list.add(Review(
        id: '${v.id}-R$i',
        vendorId: v.id,
        author: '${_pick(rnd, _nicknames)}**${rnd.nextInt(90) + 10}',
        rating: rating,
        date: now.subtract(Duration(days: 3 + i * 9 + rnd.nextInt(9))),
        text: texts.join(' '),
        tags: tags,
        context: '${_pick(rnd, _weddingTypes)} · 하객 ${(rnd.nextInt(20) + 4) * 10}명',
        helpful: rnd.nextInt(rating >= 4 ? 40 : 15),
      ));
    }
    return list;
  }

  static String _pick(Random r, List<String> l) => l.isEmpty ? '' : l[r.nextInt(l.length)];

  static const _nicknames = [
    '봄신부', '예비신랑', '가을웨딩', '소소부부', '행복한예신', '준비중커플', '결혼준비러', '초여름신부', '작은결혼식',
  ];
  static const _weddingTypes = ['공공예식장', '야외 예식', '작은결혼식', '공원 예식', '청사 예식장'];

  static const _good = [
    '상담부터 끝까지 친절하게 안내해 주셨어요.',
    '가격 대비 만족도가 높았어요.',
    '일정 조율이 빨라서 준비가 편했어요.',
    '공공예식장이라 걱정했는데 분위기에 맞게 잘 맞춰 주셨어요.',
    '처음 안내받은 금액 그대로라 추가금 걱정이 없었어요.',
    '꼼꼼하게 챙겨 주셔서 당일에 신경 쓸 게 없었어요.',
    '주변에도 추천하고 싶어요.',
  ];
  static const _mid = [
    '전반적으로 무난했는데 연락이 조금 늦은 편이었어요.',
    '옵션을 추가하면 가격이 꽤 올라가요.',
    '기본 구성은 괜찮은데 선택지가 많지 않았어요.',
    '결과물은 좋았지만 대기 시간이 길었어요.',
  ];
  static const _bad = [
    '상담 때 안내받은 구성과 실제가 조금 달랐어요.',
    '예약 변경이 어려워서 아쉬웠어요.',
    '응대가 늦어서 여러 번 확인해야 했어요.',
    '추가 비용 안내가 늦게 와서 당황했어요.',
  ];
  static const _goodTags = [
    '친절해요', '가격이 합리적이에요', '결과물이 좋아요', '일정 조율이 쉬워요', '추가금이 없어요', '꼼꼼해요',
    '공공예식장 경험이 많아요',
  ];
  static const _badTags = ['연락이 느려요', '옵션 추가금이 있어요', '선택지가 적어요', '변경이 어려워요'];

  static const _categoryGood = <VendorCategory, List<String>>{
    VendorCategory.dress: [
      '드레스 종류가 다양해서 고르기 좋았어요.',
      '가봉 때 체형에 맞게 세심하게 수선해 주셨어요.',
      '야외 예식에 어울리는 가벼운 드레스를 추천해 주셨어요.',
    ],
    VendorCategory.meal: [
      '하객분들이 음식이 맛있다고 많이 칭찬하셨어요.',
      '인원이 바뀌어도 유연하게 맞춰 주셨어요.',
      '야외 예식장인데도 음식이 따뜻하게 나왔어요.',
    ],
    VendorCategory.studio: [
      '자연스러운 포즈를 잘 이끌어 주셨어요.',
      '보정이 과하지 않고 자연스러워요.',
      '원본을 빨리 받아서 좋았어요.',
    ],
    VendorCategory.snap: [
      '놓치기 쉬운 순간까지 다 담아 주셨어요.',
      '색감이 정말 예뻐요.',
      '하객 사진도 많이 찍어 주셔서 좋았어요.',
    ],
    VendorCategory.invitation: [
      '샘플을 받아보고 고를 수 있어서 좋았어요.',
      '종이 질감이 고급스러워요.',
      '모바일 청첩장까지 같이 받아서 편했어요.',
    ],
    VendorCategory.props: [
      '부케가 사진보다 실물이 더 예뻤어요.',
      '케이크 맛도 디자인도 만족해요.',
      '예식장 분위기에 맞춰 꽃 색을 골라 주셨어요.',
    ],
    VendorCategory.video: [
      '하이라이트 영상 보고 부모님이 우셨어요.',
      '소리까지 깨끗하게 잘 담겼어요.',
      '편집본이 생각보다 빨리 나왔어요.',
    ],
    VendorCategory.suit: [
      '핏이 정말 잘 맞아요.',
      '원단 설명을 자세히 해 주셨어요.',
      '가봉 한 번으로 딱 맞췄어요.',
    ],
    VendorCategory.hanbok: [
      '어머님들이 색이 곱다고 좋아하셨어요.',
      '착장까지 도와주셔서 편했어요.',
      '대여인데도 상태가 깨끗했어요.',
    ],
    VendorCategory.parentMakeup: [
      '어머님들 메이크업이 단아하게 잘 나왔어요.',
      '시간 맞춰 와 주셔서 여유로웠어요.',
    ],
    VendorCategory.makeup: [
      '하루 종일 메이크업이 무너지지 않았어요.',
      '원하는 분위기를 잘 이해해 주셨어요.',
      '리허설 덕분에 당일 걱정이 없었어요.',
    ],
  };
}

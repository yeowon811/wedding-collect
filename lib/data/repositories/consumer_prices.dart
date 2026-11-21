import 'dart:convert';

import 'package:flutter/services.dart';

/// 한국소비자원 참가격 '예식장 가격정보' (일반·민간 결혼식장 계약 가격 조사, 지역별 분포).
/// 만든 곳: tools/make_consumer_prices.py → assets/data/consumer_wedding_prices.json. 공공예식장 값이 아니다.
class ConsumerPrices {
  ConsumerPrices._(this.survey, this.source, this.sourceUrl, this.regions);

  final String survey; // 예: 2026-09
  final String source;
  final String sourceUrl;
  final Map<String, ConsumerRegion> regions;

  static ConsumerPrices? _cache;

  static Future<ConsumerPrices> load() async {
    if (_cache != null) return _cache!;
    final m = jsonDecode(await rootBundle.loadString('assets/data/consumer_wedding_prices.json')) as Map<String, dynamic>;
    return _cache = ConsumerPrices._(
      m['survey'] as String,
      m['source'] as String,
      m['sourceUrl'] as String,
      {
        for (final e in (m['regions'] as Map<String, dynamic>).entries)
          e.key: ConsumerRegion.fromJson(e.key, e.value as Map<String, dynamic>),
      },
    );
  }

  /// '2026-09' → '2026년 9월'
  String get surveyLabel {
    final [y, mo] = survey.split('-');
    return '$y년 ${int.parse(mo)}월';
  }

  /// 앱의 시도(·시군구) → 조사 지역. 서울은 강남구만 '서울(강남)', 그 밖은 '서울(강남외)'. 모르면 전국
  static String regionKey(String? sido, {String? sigungu}) => switch (sido) {
        '서울' => sigungu == '강남구' ? '서울(강남)' : '서울(강남외)',
        '부산' || '대구' || '인천' || '대전' || '울산' || '전북' => sido!,
        '광주' || '전남' || '광주·전남' => '전남광주',
        '경기' => '경기도',
        '강원' => '강원도',
        '충북' || '충남' || '세종' => '충청도',
        '경북' || '경남' => '경상도',
        '제주' => '제주도',
        _ => '전국',
      };

  ConsumerRegion region(String? sido, {String? sigungu}) =>
      regions[regionKey(sido, sigungu: sigungu)] ?? regions['전국']!;
}

class ConsumerRegion {
  const ConsumerRegion(this.name, this.rentalFee, this.mealPerGuest, this.minGuests, this.totalContract);

  final String name;
  final ConsumerStat rentalFee; // 만원
  final ConsumerStat mealPerGuest; // 1인당 만원
  final ConsumerStat minGuests; // 명
  final ConsumerStat totalContract; // 만원

  factory ConsumerRegion.fromJson(String name, Map<String, dynamic> m) => ConsumerRegion(
        name,
        ConsumerStat.fromJson(m['rentalFee'] as Map<String, dynamic>),
        ConsumerStat.fromJson(m['mealPerGuest'] as Map<String, dynamic>),
        ConsumerStat.fromJson(m['minGuests'] as Map<String, dynamic>),
        ConsumerStat.fromJson(m['totalContract'] as Map<String, dynamic>),
      );

  /// 화면 이름: '서울(강남외)' → '서울(강남 외)'
  String get label => name.replaceAll('강남외', '강남 외');
}

class ConsumerStat {
  const ConsumerStat(this.p25, this.median, this.p75, this.avg, this.n);

  final num p25;
  final num median;
  final num p75;
  final num avg;
  final int n; // 표본 수

  factory ConsumerStat.fromJson(Map<String, dynamic> m) =>
      ConsumerStat(m['p25'] as num, m['median'] as num, m['p75'] as num, m['avg'] as num, (m['n'] as num).toInt());
}

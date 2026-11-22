import 'dart:convert';

import 'package:flutter/services.dart';

/// 한국소비자원 참가격 '예식장 가격정보' (일반·민간 결혼식장 계약 가격 조사, 지역별 분포).
/// 만든 곳: tools/make_consumer_prices.py → assets/data/consumer_wedding_prices.json. 공공예식장 값이 아니다.
class ConsumerPrices {
  ConsumerPrices._(this.survey, this.source, this.sourceUrl, this.regions, this.addOns, this.collectedAt);

  final String survey; // 예: 2026-09
  final String source;
  final String sourceUrl;
  final Map<String, ConsumerRegion> regions;

  /// 선택품목(추가금) 권역 → 항목 → 값 (만원). 참가격은 권역 7개로만 공표
  final Map<String, Map<String, ConsumerStat>> addOns;
  final String? collectedAt; // 공식 페이지에서 읽은 날 (2026-11-22)

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
      {
        for (final g in ((m['addOns'] as Map<String, dynamic>?) ?? const {}).entries)
          g.key: {
            for (final i in (g.value as Map<String, dynamic>).entries)
              i.key: ConsumerStat.fromJson(i.value as Map<String, dynamic>),
          },
      },
      m['collectedAt'] as String?,
    );
  }

  /// '2026-09' → '2026년 9월'
  String get surveyLabel {
    final [y, mo] = survey.split('-');
    return '$y년 ${int.parse(mo)}월';
  }

  /// 참가격의 '서울(강남)' = 강남3구 (2026-11-22 벤치마크 파일 정의)
  static const gangnam3 = {'강남구', '서초구', '송파구'};

  /// 앱의 시도(·시군구) → 조사 지역. 서울은 강남3구(강남·서초·송파)면 '서울(강남)', 그 밖은 '서울(강남외)'.
  /// 지역을 말하지 않았으면 전국. 조사에 없는 지역이면 null (다른 지역 값으로 채우지 않는다, 11-22 규칙)
  static String? regionKey(String? sido, {String? sigungu}) => switch (sido) {
        null => '전국',
        '서울' => gangnam3.contains(sigungu) ? '서울(강남)' : '서울(강남외)',
        '부산' || '대구' || '인천' || '대전' || '울산' || '전북' => sido,
        '광주' || '전남' || '광주·전남' => '전남광주',
        '경기' => '경기도',
        '강원' => '강원도',
        '충북' || '충남' || '세종' => '충청도',
        '경북' || '경남' => '경상도',
        '제주' => '제주도',
        _ => null,
      };

  /// 조사 지역 값. 없으면 null (전국 값으로 대신하지 않는다)
  ConsumerRegion? region(String? sido, {String? sigungu}) => switch (regionKey(sido, sigungu: sigungu)) {
        final k? => regions[k],
        null => null,
      };

  /// 그 지역 권역의 추가금 항목 값 (예: '생화꽃장식', '본식 촬영 비용'). 없으면 null
  ConsumerStat? addOn(ConsumerRegion r, String item) => addOns[r.addOnGroup]?[item];
}

class ConsumerRegion {
  const ConsumerRegion(this.name, this.rentalFee, this.mealPerGuest, this.minGuests, this.totalContract,
      {this.basicDecorationAvg, this.addOnGroup, this.definition});

  final String name;
  final ConsumerStat rentalFee; // 만원
  final ConsumerStat mealPerGuest; // 1인당 만원
  final ConsumerStat minGuests; // 명
  final ConsumerStat totalContract; // 만원
  final num? basicDecorationAvg; // 필수 기본 장식비 평균 (만원, 중간값은 모든 지역 0원)
  final String? addOnGroup; // 추가금 공표 권역 (서울·경인·4대 광역시·통합특별시·이외 지역 …)
  final String? definition; // 포함 지역 (서울(강남) = 강남3구)

  factory ConsumerRegion.fromJson(String name, Map<String, dynamic> m) => ConsumerRegion(
        name,
        ConsumerStat.fromJson(m['rentalFee'] as Map<String, dynamic>),
        ConsumerStat.fromJson(m['mealPerGuest'] as Map<String, dynamic>),
        ConsumerStat.fromJson(m['minGuests'] as Map<String, dynamic>),
        ConsumerStat.fromJson(m['totalContract'] as Map<String, dynamic>),
        basicDecorationAvg: (m['basicDecoration'] as Map<String, dynamic>?)?['avg'] as num?,
        addOnGroup: m['addOnGroup'] as String?,
        definition: m['definition'] as String?,
      );

  /// 화면 이름: '서울(강남외)' → '서울(강남 외)'
  String get label => name.replaceAll('강남외', '강남 외');
}

class ConsumerStat {
  const ConsumerStat(this.p25, this.median, this.p75, this.avg, this.n);

  // 표본이 적어 공표되지 않은 값은 null (0으로 채우지 않는다)
  final num? p25;
  final num median;
  final num? p75;
  final num? avg;
  final int n; // 표본 수

  factory ConsumerStat.fromJson(Map<String, dynamic> m) => ConsumerStat(
      m['p25'] as num?, m['median'] as num, m['p75'] as num?, m['avg'] as num?, (m['n'] as num).toInt());
}

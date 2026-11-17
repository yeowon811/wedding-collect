/// 비용 시뮬레이터 항목 (업체_요소.xlsx → tools/convert_options.py → assets/data/wedding_options.json)
/// 금액은 만원. 시연용 참고 금액이라 정확한 시세가 아니다.
class WeddingOption {
  const WeddingOption({
    required this.id,
    required this.group,
    required this.name,
    required this.defaultOn,
    required this.kind,
    required this.publicPrice,
    required this.averagePrice,
    required this.hiddenExtra,
    required this.perGuest,
    required this.detail,
    required this.extraDetail,
    required this.support,
    required this.sourceName,
    required this.sourceUrl,
  });

  final String id;
  final String group; // 기본 스드메·의상, 사진·영상 기록 …
  final String name;
  final bool defaultOn;
  final String kind; // 공통(필수) / 선택옵션 / 공공특화(핵심) …
  final int publicPrice; // 실속·공공 표준가
  final int averagePrice; // 일반 웨딩 평균가
  final int hiddenExtra; // 일반 웨딩에서 자주 붙는 숨은 추가금
  final bool perGuest; // 하객 100명 기준 금액 (식대·답례품)
  final String detail;
  final String extraDetail;
  final String support;
  final String sourceName;
  final String sourceUrl;

  /// 화면에 보일 이름: 하객 수로 다시 계산하는 항목은 "(하객 100명 기준)" 같은 꼬리를 뗀다
  String get label => perGuest ? name.replaceAll(RegExp(r'\s*\(하객 \d+명 기준\)'), '') : name;

  double _scale(int guests) => perGuest ? guests / 100 : 1;

  /// 공공예식장·실속으로 했을 때 (만원)
  int publicCost(int guests) => (publicPrice * _scale(guests)).round();

  /// 일반 웨딩홀 실질 금액 = 평균가 + 숨은 추가금 (만원)
  int generalCost(int guests) => ((averagePrice + hiddenExtra) * _scale(guests)).round();

  factory WeddingOption.fromJson(Map<String, dynamic> j) => WeddingOption(
        id: j['id'] as String,
        group: j['group'] as String,
        name: j['name'] as String,
        defaultOn: j['defaultOn'] as bool,
        kind: j['kind'] as String,
        publicPrice: j['publicPrice'] as int,
        averagePrice: j['averagePrice'] as int,
        hiddenExtra: j['hiddenExtra'] as int,
        perGuest: j['perGuest'] as bool,
        detail: j['detail'] as String,
        extraDetail: j['extraDetail'] as String,
        support: j['support'] as String,
        sourceName: j['sourceName'] as String,
        sourceUrl: j['sourceUrl'] as String,
      );
}

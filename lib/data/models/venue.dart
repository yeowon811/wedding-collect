/// 예약 방식 4가지 유형 (원본 36가지 문구를 tools/convert_venues.py에서 분류)
enum BookingType {
  online('온라인 예약'),
  form('폼 신청'),
  phoneVisit('전화·방문'),
  center('거점센터 접수');

  const BookingType(this.label);
  final String label;

  static BookingType fromCode(String code) => switch (code) {
        'ONLINE' => BookingType.online,
        'FORM' => BookingType.form,
        'PHONE_VISIT' => BookingType.phoneVisit,
        'CENTER' => BookingType.center,
        _ => BookingType.online,
      };
}

/// 공공예식장 1곳
class Venue {
  const Venue({
    required this.id,
    required this.sido,
    required this.sidoFull,
    required this.sigungu,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.isLimited,
    required this.statusText,
    required this.bookingType,
    required this.bookingMethod,
    required this.bookingContact,
    required this.bookingUrl,
    required this.detailUrl,
    required this.bookingSteps,
    required this.source,
    this.capacity,
    this.rentalFee,
    this.eshareStatus,
    this.capacityText,
    this.feeText,
    this.feeDetail,
    this.hoursWeekday,
    this.hoursSaturday,
    this.hoursHoliday,
    this.applyPeriod,
    this.operatingPeriod,
    this.approval,
    this.prepTime,
    this.target,
    this.indoorOutdoor,
    this.parking,
    this.area,
    this.images = const [],
    this.dataNotes = const [],
  });

  final String id;
  final String sido; // 화면용 짧은 이름 (예: 서울)
  final String sidoFull; // 원본 이름 (예: 서울특별시)
  final String sigungu;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final bool isLimited; // 운영중(기간제한)
  final String statusText;
  final BookingType bookingType;
  final String bookingMethod; // 원본 예약방식 문구
  final String bookingContact;
  final String bookingUrl;
  final String detailUrl;
  final String bookingSteps;
  final String source;

  /// 수집 전이거나 등록 오류로 보이면 null → 화면에서 "기관 확인 필요"
  final int? capacity; // 명
  final int? rentalFee; // 원 (무료 = 0)

  // ── 공유누리(eshare) 수집 정보 (없으면 null) ──
  final String? eshareStatus; // 수집완료 / 수집완료(이미지URL 미확인) / 페이지 없음
  final String? capacityText; // 원본 정원 값
  final String? feeText; // 예: 기본요금 100,000원
  final String? feeDetail; // 요금 상세 설명 (기준 시간·가산금 등)
  final String? hoursWeekday;
  final String? hoursSaturday;
  final String? hoursHoliday;
  final String? applyPeriod; // 접수 기간
  final String? operatingPeriod; // 이용 기간
  final String? approval; // 심사 여부
  final String? prepTime; // 준비 시간
  final String? target; // 이용 대상
  final String? indoorOutdoor; // 실내 / 실외
  final String? parking;
  final String? area; // 규모·면적
  final List<String> images; // 공유누리 사진 주소
  final List<String> dataNotes; // 데이터 주의 사항 ("확인 필요" 안내)

  bool get isCollected => eshareStatus != null;
  bool get isFree => rentalFee == 0;

  /// 하객 [guests]명을 수용할 수 있는지. 정원을 모르면 null
  bool? fits(int guests) => capacity == null ? null : capacity! >= guests;

  String get capacityLabel => capacity != null ? '정원 $capacity명' : '정원 확인 필요';

  String get feeLabel {
    if (rentalFee == null) return '대관료 확인 필요';
    if (rentalFee == 0) return '대관료 무료';
    return '기본요금 ${_won(rentalFee!)}';
  }

  static String _won(int won) {
    if (won >= 10000 && won % 10000 == 0) return '${won ~/ 10000}만원';
    if (won >= 10000) return '${(won / 10000).toStringAsFixed(1)}만원';
    return '${won.toString()}원';
  }

  String get region => sigungu.isEmpty ? sido : '$sido $sigungu';

  factory Venue.fromJson(Map<String, dynamic> j) => Venue(
        id: j['id'] as String,
        sido: j['sido'] as String,
        sidoFull: j['sidoFull'] as String,
        sigungu: j['sigungu'] as String,
        name: j['name'] as String,
        address: j['address'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        isLimited: j['status'] == 'LIMITED',
        statusText: j['statusText'] as String,
        bookingType: BookingType.fromCode(j['bookingType'] as String),
        bookingMethod: j['bookingMethod'] as String,
        bookingContact: j['bookingContact'] as String,
        bookingUrl: j['bookingUrl'] as String,
        detailUrl: j['detailUrl'] as String,
        bookingSteps: j['bookingSteps'] as String,
        source: j['source'] as String,
        capacity: (j['capacity'] as num?)?.toInt(),
        rentalFee: (j['rentalFee'] as num?)?.toInt(),
        eshareStatus: j['eshareStatus'] as String?,
        capacityText: j['capacityText'] as String?,
        feeText: j['feeText'] as String?,
        feeDetail: j['feeDetail'] as String?,
        hoursWeekday: j['hoursWeekday'] as String?,
        hoursSaturday: j['hoursSaturday'] as String?,
        hoursHoliday: j['hoursHoliday'] as String?,
        applyPeriod: j['applyPeriod'] as String?,
        operatingPeriod: j['operatingPeriod'] as String?,
        approval: j['approval'] as String?,
        prepTime: j['prepTime'] as String?,
        target: j['target'] as String?,
        indoorOutdoor: j['indoorOutdoor'] as String?,
        parking: j['parking'] as String?,
        area: j['area'] as String?,
        images: ((j['images'] as List?) ?? const []).cast<String>(),
        dataNotes: ((j['dataNotes'] as List?) ?? const []).cast<String>(),
      );
}

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
    this.collectSource,
    this.collectStatus,
    this.capacityMin,
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
    this.reception,
    this.availableDates2026,
    this.unavailableDates2026,
    this.availableDates2027,
    this.partnerVendors = const [],
    this.extraInfo,
    this.hoursText,
    this.reservationInfo,
    this.selection,
    this.inquiry,
    this.programInfo,
    this.images = const [],
    this.aiImages = const {},
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
  final int? capacity; // 명 (범위로 적힌 경우 최대값)
  final int? capacityMin; // 범위로 적힌 경우 최소값 (예: 100명~200명 → 100)
  final int? rentalFee; // 원 (무료 = 0)

  // ── 추가 수집 정보 (공유누리 / 서울마이웨딩(더아결) / 기관 안내 페이지). 없으면 null ──
  final String? collectSource; // 공유누리 / 서울마이웨딩(더아결) / 기관 안내 페이지(도메인)
  final String? collectStatus; // 수집완료 / 수집완료(별도운영) / 페이지 없음 …
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
  final String? reception; // 피로연 (케이터링·도시락·불가 등)
  final String? availableDates2026; // 예식 가능일
  final String? unavailableDates2026; // 예식 불가일
  final String? availableDates2027;
  final List<String> partnerVendors; // 협력 전문 웨딩업체 이름
  final String? extraInfo; // 기타 안내
  final String? hoursText; // 이용시간·예식 가능일 (기관 페이지 원문 한 줄)
  final String? reservationInfo; // 예약 방법 상세
  final String? selection; // 선별 방법 (선착순·심사)
  final String? inquiry; // 시설 문의처
  final String? programInfo; // 지자체·기관 공통 지원 사업 안내 (예: 국립공원 숲 결혼식)
  final List<String> images; // 사진 주소
  final Set<String> aiImages; // images 중 AI 생성 이미지
  final List<String> dataNotes; // 데이터 주의 사항 ("확인 필요" 안내)

  bool get isCollected => collectStatus != null;
  bool get isFree => rentalFee == 0;
  bool isAiImage(String url) => aiImages.contains(url);

  /// 목록 카드 대표 사진 (실제 사진이 있으면 AI 생성 이미지는 데이터 변환 때 이미 뺌)
  String? get coverImage =>
      images.where((u) => !aiImages.contains(u)).firstOrNull ??
      images.firstOrNull;

  /// 하객 [guests]명을 수용할 수 있는지. 정원을 모르면 null
  bool? fits(int guests) => capacity == null ? null : capacity! >= guests;

  // ── 빈 값 안내 (2026-11-20): 모든 화면에서 같은 말 + 연결처 ──

  /// 정원이 비어 있을 때 안내. "1명" 같은 등록 오류 값은 보여 주지 않는다
  String get capacityGap => (capacityText ?? '').contains('시간')
      ? '시간대마다 달라요 · 문의로 확인해 주세요'
      : '정보 없음 · 문의로 확인해 주세요';

  /// 대관료가 비어 있을 때 안내. 원문(시간당·오전/오후 등)이 있으면 원문은 따로 보여 준다
  String get feeGap {
    final t = feeText ?? '';
    if (t.isEmpty) return '정보 없음 · 문의로 확인해 주세요';
    if (t.contains('협의')) return '협의 후 결정 · 문의로 확인해 주세요';
    return '정확한 금액은 문의로 확인해 주세요';
  }

  /// 연결처: 전화번호 (문의처 글에서 첫 번호). 없으면 null → 예약 페이지로 안내
  String? get phone {
    final m = RegExp(r'0\d{1,2}-\d{3,4}(?:-\d{4})?|1\d{3}-\d{4}').firstMatch('$bookingContact ${inquiry ?? ''}');
    return m?.group(0);
  }

  /// 연결처 한 줄 (예: "☎ 02-2133-6546" / "예약 페이지에서 문의")
  String get contactLine => phone != null ? '☎ ${phone!}' : '예약 페이지에서 문의';

  String get capacityLabel {
    if (capacity == null) return '정원 문의 필요';
    if (capacityMin != null) return '$capacityMin~$capacity명';
    return '정원 $capacity명';
  }

  String get feeLabel {
    if (rentalFee == null) return '대관료 문의 필요';
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
    collectSource: j['collectSource'] as String?,
    collectStatus: j['collectStatus'] as String?,
    capacityMin: (j['capacityMin'] as num?)?.toInt(),
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
    reception: j['reception'] as String?,
    availableDates2026: j['availableDates2026'] as String?,
    unavailableDates2026: j['unavailableDates2026'] as String?,
    availableDates2027: j['availableDates2027'] as String?,
    partnerVendors: ((j['partnerVendors'] as List?) ?? const []).cast<String>(),
    extraInfo: j['extraInfo'] as String?,
    hoursText: j['hoursText'] as String?,
    reservationInfo: j['reservationInfo'] as String?,
    selection: j['selection'] as String?,
    inquiry: j['inquiry'] as String?,
    programInfo: j['programInfo'] as String?,
    images: ((j['images'] as List?) ?? const []).cast<String>(),
    aiImages: ((j['aiImages'] as List?) ?? const []).cast<String>().toSet(),
    dataNotes: ((j['dataNotes'] as List?) ?? const []).cast<String>(),
  );
}

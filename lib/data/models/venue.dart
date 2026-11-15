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

  /// 아직 수집 전이면 null → 화면에서 "기관 확인 필요"
  final int? capacity;
  final int? rentalFee;

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
      );
}

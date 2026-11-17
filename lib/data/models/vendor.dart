import 'package:flutter/material.dart';

/// 업체 항목. 앞의 11개는 준비 항목(시연용 업체), 뒤의 4개는 실제 연계업체 분류다.
enum VendorCategory {
  dress('드레스', Icons.checkroom, 12),
  meal('식대', Icons.restaurant, 35),
  studio('웨딩촬영', Icons.photo_camera_outlined, 10),
  snap('스냅사진', Icons.camera_alt_outlined, 5),
  invitation('청첩장', Icons.mail_outline, 2),
  props('부케·케이크', Icons.local_florist_outlined, 5),
  video('본식 영상', Icons.videocam_outlined, 5),
  suit('신랑 정장', Icons.dry_cleaning_outlined, 6),
  hanbok('어머니 한복', Icons.woman_outlined, 6),
  parentMakeup('혼주 메이크업', Icons.face_retouching_natural, 3),
  makeup('메이크업', Icons.brush_outlined, 6),
  // 실제 연계업체 분류
  directing('스드메·디렉팅', Icons.auto_awesome_outlined, 0),
  catering('식사·케이터링', Icons.restaurant_menu, 0),
  photo('사진·스냅', Icons.photo_library_outlined, 0),
  host('사회·진행', Icons.mic_none, 0);

  const VendorCategory(this.label, this.icon, this.budgetShare);
  final String label;
  final IconData icon;

  /// 총예산 중 추천 배분 비율(%). 11개 항목 합 95%, 나머지 5%는 대관·기타.
  final int budgetShare;

  static const planItems = [
    dress,
    makeup,
    studio,
    snap,
    video,
    meal,
    invitation,
    props,
    suit,
    hanbok,
    parentMakeup,
  ];
  static const realGroups = [directing, catering, photo, host];

  /// 업체 탭 항목 칩: 준비 항목 11개 + 실제 업체만 있는 사회·진행
  static const vendorChips = [...planItems, host];

  /// 이 칩을 골랐을 때 함께 보여줄 실제 연계업체 분류
  bool coversReal(VendorCategory real) => switch (real) {
        directing => this == dress || this == makeup || this == studio,
        photo => this == studio || this == snap || this == video,
        catering => this == meal,
        host => this == host,
        _ => false,
      };

  static VendorCategory fromCode(String code) => switch (code) {
    'DRESS' => dress,
    'MEAL' => meal,
    'STUDIO' => studio,
    'SNAP' => snap,
    'INVITATION' => invitation,
    'PROPS' => props,
    'VIDEO' => video,
    'SUIT' => suit,
    'HANBOK' => hanbok,
    'PARENT_MAKEUP' => parentMakeup,
    'MAKEUP' => makeup,
    'CATERING' => catering,
    'PHOTO' => photo,
    'HOST' => host,
    _ => directing,
  };
}

/// 실제 연계업체 (가격 정보 없음)
class RealVendor {
  const RealVendor({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryText,
    required this.official,
    required this.sido,
    required this.sigungu,
    required this.address,
    required this.phone,
    required this.url,
    required this.services,
    this.image,
  });

  final String id;
  final String name;
  final VendorCategory category;
  final String categoryText;
  final String? image; // 업체 홈페이지 대표 이미지 주소 (파일은 복사하지 않음, 출처 = url)
  final String official; // 예: 공식전담(서울시), 외부연계업체
  final String sido;
  final String sigungu;
  final String address;
  final String phone;
  final String url;
  final String services;

  bool get isOfficial => official.startsWith('공식');

  RealVendor withImage(String? image) => RealVendor(
        id: id,
        name: name,
        category: category,
        categoryText: categoryText,
        official: official,
        sido: sido,
        sigungu: sigungu,
        address: address,
        phone: phone,
        url: url,
        services: services,
        image: image,
      );

  factory RealVendor.fromJson(Map<String, dynamic> j) => RealVendor(
    id: j['id'] as String,
    name: j['name'] as String,
    category: VendorCategory.fromCode(j['category'] as String),
    categoryText: j['categoryText'] as String,
    official: j['official'] as String,
    sido: j['sido'] as String,
    sigungu: j['sigungu'] as String,
    address: j['address'] as String,
    phone: j['phone'] as String,
    url: j['url'] as String,
    services: j['services'] as String,
  );
}

/// 시연용 가상 업체 (가격·패키지·상담 예약 흐름 시연에만 사용)
class DemoVendor {
  const DemoVendor({
    required this.id,
    required this.name,
    required this.category,
    required this.sido,
    required this.priceMin,
    required this.priceMax,
    required this.priceUnit,
    required this.packageItems,
    required this.styles,
    required this.rating,
    required this.reviewCount,
    required this.publicVenueOk,
  });

  final String id;
  final String name;
  final VendorCategory category;
  final String sido;
  final int priceMin; // 만원
  final int priceMax;
  final String priceUnit; // '', '1인', '100장'
  final List<String> packageItems;
  final List<String> styles;
  final double rating;
  final int reviewCount;
  final bool publicVenueOk;

  String get priceText {
    final unit = priceUnit.isEmpty ? '' : '/$priceUnit';
    return '$priceMin~$priceMax만원$unit';
  }

  /// 하객 수를 곱해야 하는 가격(식대 1인, 청첩장 100장)이면 총액 안내, 아니면 null
  String? totalLabel({required int guests}) => switch (priceUnit) {
        '1인' => '하객 $guests명 기준 약 ${estimate(guests: guests)}만원',
        '100장' => '하객 $guests명 기준 약 ${estimate(guests: guests)}만원',
        _ => null,
      };

  /// 예산 비교용 비용(만원): 가격대 중간값. 식대는 하객 수, 청첩장은 100장 단위로 곱한다.
  int estimate({required int guests}) {
    final mid = (priceMin + priceMax) ~/ 2;
    return switch (priceUnit) {
      '1인' => mid * guests,
      '100장' => mid * ((guests * 0.6 / 100).ceil().clamp(1, 10)),
      _ => mid,
    };
  }

  factory DemoVendor.fromJson(Map<String, dynamic> j) => DemoVendor(
    id: j['id'] as String,
    name: j['name'] as String,
    category: VendorCategory.fromCode(j['category'] as String),
    sido: j['sido'] as String,
    priceMin: (j['priceMin'] as num).toInt(),
    priceMax: (j['priceMax'] as num).toInt(),
    priceUnit: j['priceUnit'] as String,
    packageItems: (j['packageItems'] as List).cast<String>(),
    styles: (j['styles'] as List).cast<String>(),
    rating: (j['rating'] as num).toDouble(),
    reviewCount: (j['reviewCount'] as num).toInt(),
    publicVenueOk: j['publicVenueOk'] as bool,
  );
}

/// 예식장 근처 실제 업체 매칭
class VendorMatch {
  const VendorMatch({
    required this.vendorId,
    required this.category,
    required this.rank,
    required this.distanceKm,
    required this.linkType,
  });

  final String vendorId;
  final VendorCategory category;
  final int rank;
  final double distanceKm;
  final String linkType; // 공식전담 / 공식협력 / 거리기반

  factory VendorMatch.fromJson(Map<String, dynamic> j) => VendorMatch(
    vendorId: j['vendorId'] as String,
    category: VendorCategory.fromCode(j['category'] as String),
    rank: (j['rank'] as num).toInt(),
    distanceKm: (j['distanceKm'] as num).toDouble(),
    linkType: j['linkType'] as String,
  );
}

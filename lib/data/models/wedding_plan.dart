import 'vendor.dart';

/// 사용자가 입력하는 결혼 기본 정보 (가상 데이터, 기기 안에서만 사용)
class WeddingPlan {
  const WeddingPlan({
    required this.weddingDate,
    this.sido = '서울',
    this.budget = 3000,
    this.guests = 120,
  });

  final DateTime weddingDate;
  final String sido;
  final int budget; // 총예산, 만원
  final int guests; // 예상 하객 수

  int get dDay {
    final today = DateTime.now();
    return DateTime(
      weddingDate.year,
      weddingDate.month,
      weddingDate.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  WeddingPlan copyWith({
    DateTime? weddingDate,
    String? sido,
    int? budget,
    int? guests,
  }) => WeddingPlan(
    weddingDate: weddingDate ?? this.weddingDate,
    sido: sido ?? this.sido,
    budget: budget ?? this.budget,
    guests: guests ?? this.guests,
  );
}

/// 준비 항목의 진행 상태
enum ItemStatus {
  todo('미정'),
  consulting('상담 중'),
  contracted('계약 완료'),
  paid('결제 완료');

  const ItemStatus(this.label);
  final String label;

  /// 계약 이후 단계면 "완료"로 센다
  bool get isDone => this == contracted || this == paid;
}

/// 준비 항목 하나 (기본 11개 + 사용자가 추가한 항목). 이름·상태·금액·업체를 직접 고칠 수 있다.
class PlanItem {
  PlanItem({
    required this.id,
    required this.name,
    this.category,
    this.status = ItemStatus.todo,
    this.amount,
    this.vendorName,
  });

  final String id;
  String name;
  final VendorCategory? category; // 기본 항목이면 업체 분류와 연결 (직접 추가한 항목은 null)
  ItemStatus status;
  int? amount; // 계약·지출 금액 (만원). 모르면 null
  String? vendorName; // 계약한 업체 이름 (선택)
}

/// 시연용 업체 상담 예약
class Consultation {
  const Consultation({
    required this.vendor,
    required this.dateTime,
    required this.memo,
  });

  final DemoVendor vendor;
  final DateTime dateTime;
  final String memo;
}

/// 예식일 기준 할 일 템플릿
class ChecklistTask {
  const ChecklistTask(
    this.id,
    this.dMinus,
    this.title, {
    this.category,
    this.tab,
  });

  final String id;
  final int dMinus; // 예식 며칠 전까지
  final String title;
  final VendorCategory? category; // 연결된 준비 항목
  final String? tab; // 관련 탭 안내 (예식장/정책/업체)
}

const kChecklistTasks = [
  ChecklistTask('t01', 365, '예식 날짜·지역·총예산 정하기'),
  ChecklistTask('t02', 330, '공공예식장 둘러보고 신청 기간 확인하기', tab: '예식장'),
  ChecklistTask('t03', 300, '받을 수 있는 지원 정책 확인하기', tab: '정책'),
  ChecklistTask('t04', 270, '공공예식장 신청·대관 확정', tab: '예식장'),
  ChecklistTask('t05', 240, '식대(케이터링) 업체 정하기', category: VendorCategory.meal),
  ChecklistTask('t06', 210, '드레스 상담·예약', category: VendorCategory.dress),
  ChecklistTask('t07', 210, '메이크업 예약', category: VendorCategory.makeup),
  ChecklistTask('t08', 180, '웨딩촬영 스튜디오 예약', category: VendorCategory.studio),
  ChecklistTask('t09', 180, '본식 스냅 예약', category: VendorCategory.snap),
  ChecklistTask('t10', 150, '본식 영상 예약', category: VendorCategory.video),
  ChecklistTask('t11', 120, '신랑 정장 맞춤·대여', category: VendorCategory.suit),
  ChecklistTask('t12', 120, '어머니 한복 준비', category: VendorCategory.hanbok),
  ChecklistTask('t13', 90, '청첩장 디자인·주문', category: VendorCategory.invitation),
  ChecklistTask('t14', 60, '청첩장 발송·하객 명단 정리'),
  ChecklistTask('t15', 45, '부케·케이크 주문', category: VendorCategory.props),
  ChecklistTask('t16', 30, '혼주 메이크업 예약', category: VendorCategory.parentMakeup),
  ChecklistTask('t17', 30, '드레스 가봉·예식 진행 순서 정하기'),
  ChecklistTask('t18', 14, '최종 하객 수를 식대 업체에 전달'),
  ChecklistTask('t19', 7, '준비물·업체 도착 시간 최종 점검'),
  ChecklistTask('t20', 1, '당일 일정표 가족·업체와 공유'),
];

import 'package:flutter/foundation.dart';

import 'models/review.dart';
import 'models/user_profile.dart';
import 'models/vendor.dart';
import 'models/wedding_plan.dart';

/// 탭끼리 같이 쓰는 사용자 상태 (결혼 정보, 상담 예약, 진행 상태, 비교 목록).
/// 지금은 메모리에만 저장한다 (앱을 끄면 초기화). 시연용 가상 데이터만 담는다.
class AppState extends ChangeNotifier {
  AppState._();

  static final instance = AppState._();

  WeddingPlan plan = WeddingPlan(
    weddingDate: DateTime.now().add(const Duration(days: 240)),
  );

  /// 상담 전에 입력한 내 정보. [profileDone]이 false면 AI 상담 탭에서 먼저 입력 화면을 보여준다.
  UserProfile profile = const UserProfile();
  bool profileDone = false; // 내 정보 입력을 마쳤는지
  bool profileSkipped = false; // 입력을 건너뛰고 바로 질문하기로 했는지

  /// 내 정보를 저장하고, 다른 탭(체크리스트·업체 예산)에서 쓰는 결혼 정보에도 반영한다.
  void saveProfile(UserProfile p, {bool done = true}) {
    profile = p;
    profileDone = done;
    profileSkipped = false;
    plan = plan.copyWith(
      sido: p.sido,
      guests: p.guests,
      budget: p.budget,
      weddingDate: p.weddingDate,
    );
    notifyListeners();
  }

  void skipProfile() {
    profileSkipped = true;
    notifyListeners();
  }

  /// 테스트·시연 초기화용
  void resetProfile() {
    profile = const UserProfile();
    profileDone = false;
    profileSkipped = false;
    notifyListeners();
  }

  final List<Consultation> consultations = [];
  final Map<VendorCategory, ItemStatus> itemStatus = {};
  final Map<VendorCategory, (DemoVendor, int)> contracts = {}; // 업체, 계약 금액(만원)
  final Set<String> doneTasks = {};
  final List<DemoVendor> compare = [];
  final List<Review> myReviews = [];

  /// 후기는 상담을 신청했거나 계약한 업체에만 쓸 수 있다
  bool canReview(DemoVendor v) =>
      consultations.any((c) => c.vendor.id == v.id) || contracts[v.category]?.$1.id == v.id;

  void addReview(Review r) {
    myReviews.add(r);
    notifyListeners();
  }

  void updatePlan(WeddingPlan p) {
    plan = p;
    notifyListeners();
  }

  ItemStatus statusOf(VendorCategory c) => itemStatus[c] ?? ItemStatus.todo;

  void setStatus(VendorCategory c, ItemStatus s) {
    itemStatus[c] = s;
    if (s != ItemStatus.contracted) contracts.remove(c);
    notifyListeners();
  }

  void addConsultation(Consultation c) {
    consultations
      ..add(c)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (statusOf(c.vendor.category) == ItemStatus.todo) {
      itemStatus[c.vendor.category] = ItemStatus.consulting;
    }
    notifyListeners();
  }

  void cancelConsultation(Consultation c) {
    consultations.remove(c);
    notifyListeners();
  }

  void contract(DemoVendor v) {
    itemStatus[v.category] = ItemStatus.contracted;
    contracts[v.category] = (v, v.estimate(guests: plan.guests));
    notifyListeners();
  }

  int get contractedTotal => contracts.values.fold(0, (sum, e) => sum + e.$2);

  void toggleTask(String id) {
    doneTasks.contains(id) ? doneTasks.remove(id) : doneTasks.add(id);
    notifyListeners();
  }

  bool inCompare(DemoVendor v) => compare.any((e) => e.id == v.id);

  /// 비교는 같은 항목끼리 최대 3곳. 다른 항목을 담으면 목록을 새로 시작한다.
  void toggleCompare(DemoVendor v) {
    if (inCompare(v)) {
      compare.removeWhere((e) => e.id == v.id);
    } else {
      if (compare.isNotEmpty && compare.first.category != v.category) compare.clear();
      if (compare.length >= 3) compare.removeAt(0);
      compare.add(v);
    }
    notifyListeners();
  }

  void clearCompare() {
    compare.clear();
    notifyListeners();
  }
}

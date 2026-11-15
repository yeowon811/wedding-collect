import 'package:flutter/foundation.dart';

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

  final List<Consultation> consultations = [];
  final Map<VendorCategory, ItemStatus> itemStatus = {};
  final Map<VendorCategory, (DemoVendor, int)> contracts = {}; // 업체, 계약 금액(만원)
  final Set<String> doneTasks = {};
  final List<DemoVendor> compare = [];

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

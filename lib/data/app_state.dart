import 'package:flutter/foundation.dart';

import '../features/chat/chat_agent.dart';
import 'models/review.dart';
import 'candidates.dart';
import 'models/user_profile.dart';
import 'models/venue.dart';
import 'models/vendor.dart';
import 'models/wedding_plan.dart';

/// 탭끼리 같이 쓰는 사용자 상태 (결혼 정보, 준비 항목, 할 일, 상담 예약, 비교 목록).
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

  /// 저장된 내 정보를 한 번에 적용 (로그인 후 불러오기). null인 항목은 기본값 유지.
  void replaceAll({
    required UserProfile profile,
    required bool profileDone,
    required WeddingPlan plan,
    List<PlanItem>? items,
    List<ChecklistTask>? tasks,
    Set<String> doneTasks = const {},
    List<Consultation> consultations = const [],
    Map<VendorCategory, (DemoVendor, int)> contracts = const {},
    List<Review> myReviews = const [],
    List<ChatMessage> chat = const [],
    DateTime? chatUpdatedAt,
    Set<String> favorites = const {},
    Set<String>? simSelected,
    bool simVoucher = false,
    String? chosenVenueId,
    Map<String, Map<String, String>> estimates = const {},
  }) {
    this.profile = profile;
    this.profileDone = profileDone;
    profileSkipped = false;
    this.plan = plan;
    if (items != null) {
      this.items
        ..clear()
        ..addAll(items);
    }
    if (tasks != null) {
      this.tasks
        ..clear()
        ..addAll(tasks)
        ..sort((a, b) => b.dMinus.compareTo(a.dMinus));
    }
    this.doneTasks
      ..clear()
      ..addAll(doneTasks);
    this.consultations
      ..clear()
      ..addAll(consultations);
    this.contracts
      ..clear()
      ..addAll(contracts);
    this.myReviews
      ..clear()
      ..addAll(myReviews);
    compare.clear();
    this.chat
      ..clear()
      ..addAll(chat);
    this.chatUpdatedAt = chatUpdatedAt;
    chatFromSaved = chat.isNotEmpty; // 저장된 대화가 있으면 이어갈지 먼저 묻는다
    chatEpoch++;
    this.favorites
      ..clear()
      ..addAll(favorites);
    this.simSelected = simSelected == null ? null : {...simSelected};
    this.simVoucher = simVoucher;
    this.chosenVenueId = chosenVenueId;
    this.estimates
      ..clear()
      ..addAll({for (final e in estimates.entries) e.key: {...e.value}});
    notifyListeners();
  }

  // ───────────────────────── 찜 (하트) ─────────────────────────

  /// 찜한 것: 'venue:H078', 'vendor:D0001'(시연 업체), 'real:V003'(실제 업체), 'policy:P012'
  final Set<String> favorites = {};

  bool isFavorite(String ref) => favorites.contains(ref);

  void toggleFavorite(String ref) {
    final adding = !favorites.contains(ref);
    adding ? favorites.add(ref) : favorites.remove(ref);
    if (adding && ref.startsWith('venue:')) ensureVenueItem(); // 예식장을 찜하면 체크리스트에 '예식장' 항목
    syncCandidateStatus();
    notifyListeners();
  }

  /// 찜 = 후보: 후보가 생기면 '미정' → '후보', 모두 빼면 '후보' → '미정'
  void syncCandidateStatus() {
    for (final item in items) {
      final has = Candidates.forItem(item, this).isNotEmpty;
      if (has && item.status == ItemStatus.todo) item.status = ItemStatus.candidate;
      if (!has && item.status == ItemStatus.candidate) item.status = ItemStatus.todo;
    }
  }

  // ───────────────────────── 예식장 (준비 항목) ─────────────────────────

  static const venueItemId = 'venue';

  /// [이 곳으로 정하기]로 고른 예식장
  String? chosenVenueId;

  /// 체크리스트 맨 위 '예식장' 항목 (없으면 만든다)
  PlanItem ensureVenueItem() {
    var item = items.where((i) => i.id == venueItemId).firstOrNull;
    if (item == null) {
      item = PlanItem(id: venueItemId, name: '예식장');
      items.insert(0, item);
    }
    return item;
  }

  /// 예식장 상세의 [이 곳으로 정하기]: 예식장 항목에 이름·대관료를 넣고, 지역을 입력 안 했으면 채운다
  void chooseVenue(Venue v) {
    chosenVenueId = v.id;
    favorites.add('venue:${v.id}');
    final item = ensureVenueItem()
      ..vendorName = v.name
      ..amount = v.rentalFee == null ? null : (v.rentalFee! / 10000).round();
    if (item.status == ItemStatus.todo || item.status == ItemStatus.candidate) item.status = ItemStatus.consulting;
    if (!plan.hasSido) updatePlan(plan.copyWith(sido: v.sido));
    // '공공예식장 둘러보고 신청 기간 확인하기'는 끝낸 것으로
    if (tasks.any((t) => t.id == 't02')) doneTasks.add('t02');
    notifyListeners();
  }

  void clearVenue() {
    chosenVenueId = null;
    final item = items.where((i) => i.id == venueItemId).firstOrNull;
    if (item != null) {
      item
        ..vendorName = null
        ..amount = null
        ..status = ItemStatus.todo;
    }
    syncCandidateStatus();
    notifyListeners();
  }

  // ───────────────────────── 내 결혼 견적서 (A안·B안) ─────────────────────────

  /// 'A'/'B' → 항목 키('venue', 'dress' …) → 고른 것 ('avg:public', 'avg:general', 'mine', 'none', 'ref:vendor:D0001')
  final Map<String, Map<String, String>> estimates = {};

  void setEstimate(String plan, String key, String choice) {
    estimates.putIfAbsent(plan, () => {})[key] = choice;
    notifyListeners();
  }

  // ───────────────────────── 비용 시뮬레이터 ─────────────────────────

  /// 고른 항목 id (null이면 아직 손대지 않음 → 기본 채택 항목)
  Set<String>? simSelected;

  /// 지자체 지원금(바우처) 반영 여부
  bool simVoucher = false;

  void setSimulation({Set<String>? selected, bool? voucher}) {
    if (selected != null) simSelected = {...selected};
    if (voucher != null) simVoucher = voucher;
    notifyListeners();
  }

  // ───────────────────────── AI 상담 대화 ─────────────────────────

  static const chatLimit = 60; // 계정에 남기는 최근 메시지 수

  /// 상담 대화 (계정에 저장, 최근 [chatLimit]개)
  final List<ChatMessage> chat = [];
  DateTime? chatUpdatedAt;

  /// 저장된 대화를 불러왔고, 이어서 할지·새로 시작할지 아직 고르지 않음
  bool chatFromSaved = false;

  /// 대화를 새로 시작할 때마다 증가 → 상담 에이전트도 새로 만든다
  int chatEpoch = 0;

  void addChat(ChatMessage m) {
    chat.add(m);
    if (chat.length > chatLimit) chat.removeRange(0, chat.length - chatLimit);
    chatUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void resumeChat() {
    chatFromSaved = false;
    notifyListeners();
  }

  void clearChat() {
    chat.clear();
    chatUpdatedAt = null;
    chatFromSaved = false;
    chatEpoch++;
    notifyListeners();
  }

  /// 처음 상태로 (로그아웃할 때)
  void resetAll() {
    replaceAll(
      profile: const UserProfile(),
      profileDone: false,
      plan: WeddingPlan(
        weddingDate: DateTime.now().add(const Duration(days: 240)),
      ),
      items: [
        for (final c in VendorCategory.planItems)
          PlanItem(id: c.name, name: c.label, category: c),
      ],
      tasks: const [],
    );
  }

  final List<Consultation> consultations = [];
  final Map<VendorCategory, (DemoVendor, int)> contracts =
      {}; // 시연용 업체 계약: 업체, 금액(만원)
  final List<DemoVendor> compare = [];
  final List<Review> myReviews = [];

  /// 체크리스트에서 결혼 정보를 바꾸면 AI 상담 내 정보에도 같은 값이 들어간다
  void updatePlan(WeddingPlan p) {
    plan = p;
    profile = profile.copyWith(
      sido: p.hasSido ? p.sido : null,
      guests: p.hasGuests ? p.guests : null,
      budget: p.hasBudget ? p.budget : null,
      weddingDate: p.hasDate ? p.weddingDate : null,
      weddingUndecided: p.hasDate ? false : null,
    );
    notifyListeners();
  }

  /// AI 상담 내 정보 입력 중에 바꾼 값을 바로 체크리스트에도 반영 (입력을 마치기 전이라도)
  void updateProfileDraft(UserProfile p) {
    profile = p;
    plan = plan.copyWith(sido: p.sido, guests: p.guests, budget: p.budget, weddingDate: p.weddingDate);
    notifyListeners();
  }

  // ───────────────────────── 준비 항목 ─────────────────────────

  /// 준비 항목: 기본 11개로 시작하고 사용자가 추가·수정·삭제한다
  final List<PlanItem> items = [
    for (final c in VendorCategory.planItems)
      PlanItem(id: c.name, name: c.label, category: c),
  ];
  int _seq = 0;

  /// 준비 항목에 정한 금액(만원) = 그 항목 예산. 정하지 않았으면 null
  int? budgetOf(VendorCategory c) {
    final a = itemFor(c)?.amount;
    return a == null || a <= 0 ? null : a;
  }

  PlanItem? itemFor(VendorCategory c) =>
      items.where((i) => i.category == c).firstOrNull;

  ItemStatus statusOf(VendorCategory c) =>
      itemFor(c)?.status ?? ItemStatus.todo;

  void setStatus(VendorCategory c, ItemStatus s) {
    final item = itemFor(c);
    if (item != null) updateItem(item, status: s);
  }

  PlanItem addItem(
    String name, {
    ItemStatus status = ItemStatus.todo,
    int? amount,
    String? vendorName,
  }) {
    final item = PlanItem(
      id: 'custom${DateTime.now().microsecondsSinceEpoch}${_seq++}',
      name: name,
      status: status,
      amount: amount,
      vendorName: vendorName,
    );
    items.add(item);
    notifyListeners();
    return item;
  }

  void updateItem(
    PlanItem item, {
    String? name,
    ItemStatus? status,
    int? amount,
    bool clearAmount = false,
    String? vendorName,
    bool clearVendor = false,
  }) {
    if (name != null && name.trim().isNotEmpty) item.name = name.trim();
    if (status != null) item.status = status;
    if (amount != null) item.amount = amount;
    if (clearAmount) item.amount = null;
    if (vendorName != null && vendorName.trim().isNotEmpty)
      item.vendorName = vendorName.trim();
    if (clearVendor) item.vendorName = null;
    // 계약 전 단계로 되돌리면 시연용 업체 계약 표시도 푼다
    if (status != null && !status.isDone && item.category != null)
      contracts.remove(item.category);
    notifyListeners();
  }

  /// 삭제한 위치를 돌려준다 (되돌리기용)
  int removeItem(PlanItem item) {
    final index = items.indexOf(item);
    items.remove(item);
    if (item.category != null) contracts.remove(item.category);
    if (item.id == venueItemId) chosenVenueId = null;
    notifyListeners();
    return index;
  }

  void restoreItem(PlanItem item, int index) {
    items.insert(index.clamp(0, items.length), item);
    notifyListeners();
  }

  /// 계약·결제 완료 항목의 금액 합계 (만원)
  int get confirmedTotal => items
      .where((i) => i.status.isDone)
      .fold(0, (sum, i) => sum + (i.amount ?? 0));

  /// 아직 계약 전이지만 금액을 적어 둔 항목의 합계 (예상, 만원)
  int get plannedTotal => items
      .where((i) => !i.status.isDone)
      .fold(0, (sum, i) => sum + (i.amount ?? 0));

  // ───────────────────────── 상담·계약 (시연용 업체) ─────────────────────────

  /// 후기는 상담을 신청했거나 계약한 업체에만 쓸 수 있다
  bool canReview(DemoVendor v) =>
      consultations.any((c) => c.vendor.id == v.id) ||
      contracts[v.category]?.$1.id == v.id;

  void addReview(Review r) {
    myReviews.add(r);
    notifyListeners();
  }

  void addConsultation(Consultation c) {
    consultations
      ..add(c)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final item = itemFor(c.vendor.category);
    if (item != null && item.status == ItemStatus.todo)
      item.status = ItemStatus.consulting;
    notifyListeners();
  }

  void cancelConsultation(Consultation c) {
    consultations.remove(c);
    notifyListeners();
  }

  /// 시연용 업체와 계약: 해당 준비 항목을 계약 완료로, 금액·업체 이름을 채운다 (항목을 지웠으면 다시 만든다)
  void contract(DemoVendor v) {
    final price = v.estimate(guests: plan.guests);
    final name = v.name.replaceFirst('[시연] ', '');
    var item = itemFor(v.category);
    if (item == null) {
      item = PlanItem(
        id: v.category.name,
        name: v.category.label,
        category: v.category,
      );
      items.add(item);
    }
    item
      ..status = ItemStatus.contracted
      ..amount = price
      ..vendorName = name;
    contracts[v.category] = (v, price);
    notifyListeners();
  }

  // ───────────────────────── 예식일 기준 할 일 ─────────────────────────

  /// 할 일: 기본 20개로 시작하고 사용자가 추가·삭제한다. 예식일에 가까운 순서(D-값 큰 순).
  /// 예식일 기준 할 일. 비어서 시작하고, 사용자가 추가하거나 추천 목록을 불러온다
  final List<ChecklistTask> tasks = [];

  /// 추천 할 일 20개 불러오기 (이미 있는 것은 건너뜀)
  void loadRecommendedTasks() {
    final have = {for (final t in tasks) t.id};
    tasks
      ..addAll(kChecklistTasks.where((t) => !have.contains(t.id)))
      ..sort((a, b) => b.dMinus.compareTo(a.dMinus));
    notifyListeners();
  }
  final Set<String> doneTasks = {};

  /// 직접 체크했거나, 연결된 준비 항목이 계약·결제 완료면 끝난 일
  bool isTaskDone(ChecklistTask t) =>
      doneTasks.contains(t.id) ||
      (t.category != null && statusOf(t.category!).isDone);

  void toggleTask(String id) {
    doneTasks.contains(id) ? doneTasks.remove(id) : doneTasks.add(id);
    notifyListeners();
  }

  ChecklistTask addTask(String title, int dMinus) {
    final t = ChecklistTask(
      'u${DateTime.now().microsecondsSinceEpoch}${_seq++}',
      dMinus,
      title.trim(),
    );
    tasks
      ..add(t)
      ..sort((a, b) => b.dMinus.compareTo(a.dMinus));
    notifyListeners();
    return t;
  }

  void removeTask(ChecklistTask t) {
    tasks.remove(t);
    doneTasks.remove(t.id);
    notifyListeners();
  }

  void restoreTask(ChecklistTask t) {
    tasks
      ..add(t)
      ..sort((a, b) => b.dMinus.compareTo(a.dMinus));
    notifyListeners();
  }

  // ───────────────────────── 업체 비교 ─────────────────────────

  bool inCompare(DemoVendor v) => compare.any((e) => e.id == v.id);

  /// 비교는 같은 항목끼리 최대 3곳. 다른 항목을 담으면 목록을 새로 시작한다.
  void toggleCompare(DemoVendor v) {
    if (inCompare(v)) {
      compare.removeWhere((e) => e.id == v.id);
    } else {
      if (compare.isNotEmpty && compare.first.category != v.category)
        compare.clear();
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

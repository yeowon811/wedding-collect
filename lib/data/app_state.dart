import 'package:flutter/foundation.dart';

import '../features/chat/chat_agent.dart';
import 'models/review.dart';
import 'candidates.dart';
import 'models/user_profile.dart';
import 'models/venue.dart';
import 'models/vendor.dart';
import 'models/wedding_plan.dart';
import 'repositories/repositories.dart';

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
    String? chosenVenueId, // 예전 저장본 (예식장 '정하기') → 담은 곳 '상담 중'으로 옮김
    Map<String, ItemStatus> placeStatus = const {},
    Map<String, int> placeAmount = const {},
    Map<String, DateTime> placeDate = const {},
    List<ManualPlace> manualPlaces = const [],
    Set<String>? checklistRefs, // null = 예전 저장본 (찜 = 체크리스트였음)
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
    this.placeStatus
      ..clear()
      ..addAll(placeStatus);
    this.placeAmount
      ..clear()
      ..addAll(placeAmount);
    this.placeDate
      ..clear()
      ..addAll(placeDate);
    this.manualPlaces
      ..clear()
      ..addAll(manualPlaces);
    this.checklistRefs
      ..clear()
      ..addAll(checklistRefs ?? {for (final f in favorites) if (!f.startsWith('policy:')) f});
    if (chosenVenueId != null) {
      this.checklistRefs.add('venue:$chosenVenueId');
      this.placeStatus.putIfAbsent('venue:$chosenVenueId', () => ItemStatus.consulting);
    }
    notifyListeners();
  }

  // ───────────────────────── 찜 (하트) ─────────────────────────

  /// 찜한 것: 'venue:H078', 'vendor:D0001'(시연 업체), 'real:V003'(실제 업체), 'policy:P012'
  final Set<String> favorites = {};

  bool isFavorite(String ref) => favorites.contains(ref);

  /// 찜(하트)은 찜 목록에만 모은다. 체크리스트 준비 항목과는 따로 ([toggleChecklist])
  void toggleFavorite(String ref) {
    favorites.contains(ref) ? favorites.remove(ref) : favorites.add(ref);
    notifyListeners();
  }

  // ───────────────────────── 체크리스트에 담은 곳 ─────────────────────────

  /// 업체·예식장 상세의 [체크리스트에 추가]·상담 신청·계약으로 담은 곳 ('venue:'·'vendor:'·'real:')
  final Set<String> checklistRefs = {};

  bool inChecklist(String ref) => checklistRefs.contains(ref);

  /// 체크리스트에 담기/빼기. 빼면 그 곳의 상태·금액도 지운다
  void toggleChecklist(String ref) {
    if (checklistRefs.add(ref)) {
      if (ref.startsWith('venue:')) ensureVenueItem(); // 예식장을 담으면 체크리스트에 '예식장' 항목
    } else {
      final affected = _itemsHolding(ref);
      checklistRefs.remove(ref);
      _forgetPlace(ref);
      for (final (item, name) in affected) {
        _afterPlaceRemoved(item, name);
      }
    }
    syncCandidateStatus();
    notifyListeners();
  }

  /// 담은 곳 빼기 (직접 추가한 곳은 지운다)
  void removePlace(PlanItem item, String ref) =>
      ref.startsWith('manual:') ? removeManualPlace(item, ref) : toggleChecklist(ref);

  /// 이 곳을 담고 있는 항목과 그 곳의 이름
  List<(PlanItem, String)> _itemsHolding(String ref) => [
        for (final item in items)
          for (final c in Candidates.forItem(item, this))
            if (c.ref == ref) (item, c.name),
      ];

  /// 담은 곳을 뺀 뒤: 남은 곳이 없으면 '미정'으로, 그 곳에서 들어온 이름·금액은 지운다
  void _afterPlaceRemoved(PlanItem item, String name) {
    if (item.vendorName == name) {
      item
        ..vendorName = null
        ..amount = null;
    }
    if (Candidates.forItem(item, this).isEmpty) item.status = ItemStatus.todo;
  }

  void _forgetPlace(String ref) {
    placeStatus.remove(ref);
    placeAmount.remove(ref);
    placeDate.remove(ref);
  }

  /// 모든 준비 항목의 상태를 담은 곳 기준으로 다시 맞춘다
  void syncCandidateStatus() {
    for (final item in items) {
      recomputeItem(item);
    }
  }

  // ───────────────────────── 담은 곳 (항목별 업체·예식장) ─────────────────────────

  /// 담은 곳마다의 진행 상태 (없으면 '후보'), 계약 금액(직접 고친 것), 계약일
  final Map<String, ItemStatus> placeStatus = {};
  final Map<String, int> placeAmount = {};
  final Map<String, DateTime> placeDate = {};

  /// 직접 추가한 곳 (앱에 없는 업체·예식장)
  final List<ManualPlace> manualPlaces = [];

  ItemStatus statusOfPlace(String ref) => placeStatus[ref] ?? ItemStatus.candidate;

  /// 담은 곳의 상태 바꾸기. 계약은 항목마다 한 곳: 다른 곳이 계약이었으면 '상담 중'으로
  void setPlaceStatus(PlanItem item, String ref, ItemStatus status) {
    if (status.isDone) {
      for (final c in Candidates.forItem(item, this)) {
        if (c.ref != ref && statusOfPlace(c.ref).isDone) {
          placeStatus[c.ref] = ItemStatus.consulting;
          placeDate.remove(c.ref);
        }
      }
      placeDate[ref] ??= DateTime.now();
    } else {
      placeDate.remove(ref);
    }
    placeStatus[ref] = status;
    recomputeItem(item);
    notifyListeners();
  }

  /// 계약한 곳의 금액 고치기 (만원)
  void setPlaceAmount(PlanItem item, String ref, int? amount) {
    amount == null ? placeAmount.remove(ref) : placeAmount[ref] = amount;
    recomputeItem(item);
    notifyListeners();
  }

  /// 앱에 없는 곳을 직접 추가
  ManualPlace addManualPlace(PlanItem item, String name, int? amount) {
    final m = ManualPlace(
        id: 'm${DateTime.now().microsecondsSinceEpoch}${_seq++}', itemId: item.id, name: name.trim(), amount: amount);
    manualPlaces.add(m);
    recomputeItem(item);
    notifyListeners();
    return m;
  }

  void removeManualPlace(PlanItem item, String ref) {
    final affected = _itemsHolding(ref);
    manualPlaces.removeWhere((m) => 'manual:${m.id}' == ref);
    _forgetPlace(ref);
    for (final (i, name) in affected) {
      _afterPlaceRemoved(i, name);
    }
    recomputeItem(item);
    notifyListeners();
  }

  /// 항목 상태 = 담은 곳 중 가장 앞선 단계. 계약(결제)한 곳이 있으면 그 이름·금액이 항목에 들어간다.
  /// 담은 곳이 없으면 직접 입력한 상태·금액을 그대로 둔다.
  void recomputeItem(PlanItem item) {
    final places = Candidates.forItem(item, this);
    if (places.isEmpty) {
      if (item.status == ItemStatus.candidate) item.status = ItemStatus.todo;
      return;
    }
    var best = ItemStatus.candidate;
    for (final c in places) {
      final st = statusOfPlace(c.ref);
      if (st.index > best.index) best = st;
    }
    item.status = best;
    final done = places.where((c) => statusOfPlace(c.ref).isDone).firstOrNull;
    if (done != null) {
      item
        ..vendorName = done.name
        ..amount = placeAmount[done.ref] ?? done.price;
    } else if (places.any((c) => c.name == item.vendorName)) {
      item
        ..vendorName = null
        ..amount = null;
    }
    // 시연 업체 계약 표시(후기 쓰기·계약 취소 버튼)도 맞춘다
    final cat = item.category;
    if (cat != null) {
      final demo = done != null && done.ref.startsWith('vendor:')
          ? Repos.vendor.demoCached?.where((v) => 'vendor:${v.id}' == done.ref).firstOrNull
          : null;
      demo == null ? contracts.remove(cat) : contracts[cat] = (demo, item.amount ?? 0);
    }
  }

  /// 계약(결제)한 곳 (없으면 null)
  CandidateInfo? contractedPlace(PlanItem item) =>
      Candidates.forItem(item, this).where((c) => statusOfPlace(c.ref).isDone).firstOrNull;

  // ───────────────────────── 예식장 (준비 항목) ─────────────────────────

  static const venueItemId = 'venue';

  /// 계약(결제)한 예식장 (없으면 null)
  String? get chosenVenueId {
    for (final ref in checklistRefs) {
      if (ref.startsWith('venue:') && statusOfPlace(ref).isDone) return ref.substring(6);
    }
    return null;
  }

  /// 체크리스트 맨 위 '예식장' 항목 (없으면 만든다)
  PlanItem ensureVenueItem() {
    var item = items.where((i) => i.id == venueItemId).firstOrNull;
    if (item == null) {
      item = PlanItem(id: venueItemId, name: '예식장');
      items.insert(0, item);
    }
    return item;
  }

  /// 예식장 상세의 [체크리스트에 추가]: 예식장 항목에 담고(후보), 지역을 입력 안 했으면 채운다
  void chooseVenue(Venue v) {
    checklistRefs.add('venue:${v.id}');
    ensureVenueItem();
    if (!plan.hasSido) updatePlan(plan.copyWith(sido: v.sido));
    // '공공예식장 둘러보고 신청 기간 확인하기'는 끝낸 것으로
    if (tasks.any((t) => t.id == 't02')) doneTasks.add('t02');
    syncCandidateStatus();
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

  /// AI 상담 위쪽 조건 칩의 ✕: 그 항목만 내 정보에서 지운다 (체크리스트 결혼 정보도 '입력 안 함'으로)
  /// key: region · age · date · guests · budget · homeless
  void clearProfileField(String key) {
    profile = switch (key) {
      'region' => profile.copyWith(clearSido: true),
      'age' => profile.copyWith(clearAge: true),
      'date' => profile.copyWith(clearWeddingDate: true),
      'guests' => profile.copyWith(clearGuests: true),
      'budget' => profile.copyWith(clearBudget: true),
      'homeless' => profile.copyWith(clearHomeless: true),
      _ => profile,
    };
    final planKey = key == 'region' ? 'sido' : key;
    if (const {'sido', 'date', 'guests', 'budget'}.contains(planKey)) plan = plan.forget(planKey);
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
    if (item == null) return;
    final done = contractedPlace(item);
    // 계약한 곳이 있으면 그 곳의 상태를 바꾼다 (예: 업체 상세의 [계약 취소])
    done != null ? setPlaceStatus(item, done.ref, s) : updateItem(item, status: s);
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
    // 상담 신청한 업체는 담은 곳에 들어가고 '상담 중'
    final ref = 'vendor:${c.vendor.id}';
    checklistRefs.add(ref);
    if (statusOfPlace(ref).index < ItemStatus.consulting.index) placeStatus[ref] = ItemStatus.consulting;
    final item = itemFor(c.vendor.category);
    if (item != null) recomputeItem(item);
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
    checklistRefs.add('vendor:${v.id}');
    setPlaceStatus(item, 'vendor:${v.id}', ItemStatus.contracted); // 이름·금액·계약 표시는 recomputeItem
    if (item.vendorName == null) item.vendorName = name;
    item.amount ??= price;
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

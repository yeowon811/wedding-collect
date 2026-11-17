import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/data/models/wedding_plan.dart';

/// 체크리스트 편집: 준비 항목 추가·수정·삭제, 금액 합계, 할 일 추가·삭제
void main() {
  final s = AppState.instance;

  test('처음에는 결혼 정보·할 일이 비어 있고, 입력해야 채워진다', () {
    s.resetAll();
    expect(s.plan.entered, isEmpty);
    expect(s.tasks, isEmpty);
    expect(s.items.length, 11); // 준비 항목 목록은 그대로
    s.updatePlan(s.plan.copyWith(budget: 2500));
    expect(s.plan.hasBudget, isTrue);
    expect(s.plan.hasDate, isFalse);
    s.loadRecommendedTasks();
    expect(s.tasks.length, kChecklistTasks.length);
    s.loadRecommendedTasks(); // 두 번 불러와도 겹치지 않는다
    expect(s.tasks.length, kChecklistTasks.length);
  });

  test('준비 항목을 추가·수정·삭제하고 되돌릴 수 있다', () {
    expect(s.items.length, 11);
    final trip = s.addItem('신혼여행', amount: 400);
    expect(s.items.length, 12);
    expect(s.plannedTotal, 400); // 계약 전이면 "예정"

    s.updateItem(trip, status: ItemStatus.paid, vendorName: '○○ 여행사');
    expect(s.confirmedTotal, 400); // 결제 완료면 "확정"
    expect(s.plannedTotal, 0);
    expect(trip.vendorName, '○○ 여행사');

    s.updateItem(trip, clearAmount: true);
    expect(trip.amount, isNull);

    final hanbok = s.itemFor(VendorCategory.hanbok)!;
    final index = s.removeItem(hanbok);
    expect(s.itemFor(VendorCategory.hanbok), isNull);
    s.restoreItem(hanbok, index);
    expect(s.items[index], hanbok);
  });

  test('기본 항목은 상태를 바꿀 수 있고, 계약 전으로 돌리면 시연 업체 계약도 풀린다', () {
    final dress = s.itemFor(VendorCategory.dress)!;
    s.updateItem(dress, status: ItemStatus.contracted, amount: 250);
    expect(s.statusOf(VendorCategory.dress), ItemStatus.contracted);
    // 드레스 할 일은 계약 완료로 자동 체크
    final task = s.tasks.firstWhere((t) => t.category == VendorCategory.dress);
    expect(s.isTaskDone(task), isTrue);
    s.setStatus(VendorCategory.dress, ItemStatus.consulting);
    expect(s.isTaskDone(task), isFalse);
  });

  test('할 일을 추가하면 예식일 순서에 맞게 들어가고, 지울 수 있다', () {
    final before = s.tasks.length;
    final t = s.addTask('신혼여행 항공권 예약', 100);
    expect(s.tasks.length, before + 1);
    final i = s.tasks.indexOf(t);
    expect(s.tasks[i - 1].dMinus, greaterThanOrEqualTo(100));
    expect(s.tasks[i + 1].dMinus, lessThanOrEqualTo(100));
    s.toggleTask(t.id);
    expect(s.isTaskDone(t), isTrue);
    s.removeTask(t);
    expect(s.tasks.contains(t), isFalse);
    expect(s.doneTasks.contains(t.id), isFalse);
  });
}

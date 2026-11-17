import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../simulator/cost_simulator_screen.dart';
import 'task_calendar_screen.dart';
import '../auth/login_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/inputs.dart';
import '../../core/utils/region.dart';
import '../../core/widgets/info_badge.dart';
import '../../data/app_state.dart';
import '../../data/models/wedding_plan.dart';

/// 준비 체크리스트: 결혼 정보 → 예산 → 항목별 진행 → 상담 일정 → 예식일 기준 할 일
class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('준비 체크리스트'), actions: const [AccountButton()]),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _PlanCard(state: state),
            _BudgetCard(state: state),
            _ItemStatusCard(state: state),
            if (state.consultations.isNotEmpty) _ConsultationCard(state: state),
            _TimelineCard(state: state),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = state.plan;
    final dDay = p.dDay;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dDay > 0 ? 'D-$dDay' : (dDay == 0 ? 'D-DAY' : 'D+${-dDay}'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: p.weddingDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 3),
                        ),
                      );
                      if (picked != null)
                        state.updatePlan(p.copyWith(weddingDate: picked));
                    },
                    child: Text(
                      '예식일 ${formatDate(p.weddingDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _cell(
                context,
                '지역',
                p.sido,
                () => _pick(
                  context,
                  '지역',
                  (done) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in kSidoList)
                        ChoiceChip(
                          label: Text(s),
                          selected: p.sido == s,
                          onSelected: (_) {
                            state.updatePlan(p.copyWith(sido: s));
                            done();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _cell(
                context,
                '총예산',
                formatManwonShort(p.budget),
                () => _pick(
                  context,
                  '총예산',
                  (done) => PresetPicker(
                    value: p.budget,
                    presets: const [1000, 2000, 3000, 5000, 7000],
                    format: formatManwon,
                    unit: '만원',
                    min: 100,
                    max: 100000,
                    label: '총예산 (만원)',
                    onChanged: (v) {
                      state.updatePlan(p.copyWith(budget: v));
                      done();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _cell(
                context,
                '하객',
                '${p.guests}명',
                () => _pick(
                  context,
                  '하객 수',
                  (done) => PresetPicker(
                    value: p.guests,
                    presets: const [50, 100, 150, 200, 300],
                    format: (v) => '$v명',
                    unit: '명',
                    min: 10,
                    max: 2000,
                    label: '하객 수',
                    onChanged: (v) {
                      state.updatePlan(p.copyWith(guests: v));
                      done();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '업체 비교와 AI 상담에도 쓰여요.',
            style: TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }

  /// 결혼 정보 한 칸 (누르면 바꾸기)
  Widget _cell(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// 아래에서 올라오는 입력 창. [build]는 고르면 창을 닫는 done()을 받는다.
  Future<void> _pick(
    BuildContext context,
    String title,
    Widget Function(VoidCallback done) build,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            build(() => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }
}

/// 예산: 총예산(바로 수정) / 계약·결제 금액 / 예정 금액 / 남은 예산
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = state.plan;
    final confirmed = state.confirmedTotal;
    final planned = state.plannedTotal;
    final left = p.budget - confirmed - planned;
    double part(int v) => p.budget <= 0 ? 0 : (v / p.budget).clamp(0.0, 1.0);

    return _Section(
      title: '예산',
      trailing: TextButton(
        onPressed: () => _editBudget(context),
        child: const Text('총예산 수정'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(
              text: left >= 0 ? '남은 예산 ${formatManwon(left)}' : '${formatManwon(-left)} 초과',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: left >= 0 ? AppColors.textPrimary : AppColors.warning,
              ),
            ),
            TextSpan(
              text: '  / 총 ${formatManwon(p.budget)}',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ])),
          const SizedBox(height: 12),
          // 계약·결제(진한 파랑) + 예정(연한 파랑) 막대
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder: (context, box) => Stack(children: [
                  Container(color: AppColors.fill),
                  Container(
                    width: box.maxWidth * (part(confirmed) + part(planned)).clamp(0.0, 1.0),
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                  Container(width: box.maxWidth * part(confirmed), color: AppColors.primary),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _line(AppColors.primary, '계약·결제 완료', confirmed),
          const SizedBox(height: 6),
          _line(AppColors.primary.withValues(alpha: 0.35), '예정 (금액만 적어 둔 항목)', planned),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CostSimulatorScreen())),
              child: const Text('결혼 비용 시뮬레이션'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(Color color, String label, int value) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textBody))),
        Text(formatManwon(value),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]);

  Future<void> _editBudget(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총예산',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              PresetPicker(
                value: state.plan.budget,
                presets: const [1000, 2000, 3000, 5000, 7000],
                format: formatManwon,
                unit: '만원',
                min: 100,
                max: 100000,
                label: '총예산 (만원)',
                onChanged: (v) {
                  state.updatePlan(state.plan.copyWith(budget: v));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      );
}

/// 준비 항목: 누르면 이름·상태·금액·업체를 고치거나 지울 수 있고, 새 항목을 추가할 수 있다
class _ItemStatusCard extends StatelessWidget {
  const _ItemStatusCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    final done = items.where((i) => i.status.isDone).length;
    return _Section(
      title: '준비 항목 ${items.length}개',
      trailing: Text('$done/${items.length} 완료', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      child: Column(
        children: [
          for (final item in items) _row(context, item),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => showItemEditor(context, state),
              child: const Text('항목 추가'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, PlanItem item) {
    final sub = [
      if (item.vendorName != null) item.vendorName!,
      item.amount != null ? formatManwon(item.amount!) : '금액 미입력',
    ].join(' · ');
    return InkWell(
      onTap: () => showItemEditor(context, state, item: item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: item.amount == null ? AppColors.textHint : AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusPill(status: item.status),
          ],
        ),
      ),
    );
  }
}

/// 상태 표시: 미정(회색) / 상담 중(주황) / 계약 완료·결제 완료(초록)
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      ItemStatus.todo => (AppColors.textSecondary, AppColors.fill),
      ItemStatus.consulting => (AppColors.warning, AppColors.warningSoft),
      ItemStatus.contracted || ItemStatus.paid => (AppColors.success, AppColors.successSoft),
    };
    return InfoBadge(label: status.label, color: fg, background: bg);
  }
}

/// 준비 항목 추가·수정 창. [item]이 없으면 새로 추가한다.
Future<void> showItemEditor(BuildContext context, AppState state, {PlanItem? item}) {
  final name = TextEditingController(text: item?.name ?? '');
  final amount = TextEditingController(text: item?.amount?.toString() ?? '');
  final vendor = TextEditingController(text: item?.vendorName ?? '');
  var status = item?.status ?? ItemStatus.todo;
  final messenger = ScaffoldMessenger.of(context);

  void save(BuildContext ctx) {
    final n = name.text.trim();
    if (n.isEmpty) return;
    final a = int.tryParse(amount.text.replaceAll(',', ''));
    final v = vendor.text.trim();
    if (item == null) {
      state.addItem(n, status: status, amount: a, vendorName: v.isEmpty ? null : v);
    } else {
      state.updateItem(item,
          name: n,
          status: status,
          amount: a,
          clearAmount: a == null,
          vendorName: v.isEmpty ? null : v,
          clearVendor: v.isEmpty);
    }
    Navigator.pop(ctx);
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  Text(item == null ? '항목 추가' : '항목 수정',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 20),
                  FormSection(
                    title: '이름',
                    child: TextField(
                      controller: name,
                      autofocus: item == null,
                      decoration: const InputDecoration(hintText: '예: 신혼여행, 예물, 폐백'),
                    ),
                  ),
                  FormSection(
                    title: '진행 상태',
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in ItemStatus.values)
                        ChoiceChip(
                          label: Text(s.label),
                          selected: status == s,
                          onSelected: (_) => setSheet(() => status = s),
                        ),
                    ]),
                  ),
                  FormSection(
                    title: '금액',
                    hint: '계약했거나 낼 예정인 금액이에요. 예산 계산에 들어가요.',
                    child: TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: '예: 250', suffixText: '만원'),
                    ),
                  ),
                  FormSection(
                    title: '업체 (선택)',
                    child: TextField(
                      controller: vendor,
                      decoration: const InputDecoration(hintText: '예: ○○ 스튜디오'),
                    ),
                  ),
                ],
              ),
            ),
            BottomActionBar(children: [
              if (item == null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () => save(ctx), child: const Text('추가')),
                )
              else
                ActionPair(
                  secondary: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                    onPressed: () {
                      Navigator.pop(ctx);
                      final index = state.removeItem(item);
                      messenger.showSnackBar(SnackBar(
                        content: Text("'${item.name}' 항목을 지웠어요"),
                        action: SnackBarAction(label: '되돌리기', onPressed: () => state.restoreItem(item, index)),
                      ));
                    },
                    child: const Text('삭제'),
                  ),
                  primary: FilledButton(onPressed: () => save(ctx), child: const Text('저장')),
                ),
            ]),
          ],
        ),
      ),
    ),
  );
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '내 상담 일정',
      trailing: Text('${state.consultations.length}건', style: TextStyle(color: AppColors.textSecondary)),
      child: Column(
        children: [
          for (final c in state.consultations)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(c.vendor.name.replaceFirst('[시연] ', '')),
              subtitle: Text(
                '${formatDateWithDay(c.dateTime)} '
                '${c.dateTime.hour.toString().padLeft(2, '0')}:00 · ${c.vendor.category.label}',
              ),
              trailing: TextButton(onPressed: () => state.cancelConsultation(c), child: const Text('취소')),
            ),
        ],
      ),
    );
  }
}

/// 예식일 기준 할 일: 눌러서 완료 체크, 직접 추가·삭제
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final wedding = state.plan.weddingDate;
    final today = DateTime.now();
    final tasks = state.tasks;
    final done = tasks.where(state.isTaskDone).length;
    final nextTodo = tasks.where((t) => !state.isTaskDone(t)).firstOrNull;

    return _Section(
      title: '예식일 기준 할 일',
      trailing: TextButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskCalendarScreen())),
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text('캘린더 · $done/${tasks.length}'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nextTodo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Text('지금 할 일 · ${nextTodo.title}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          for (final t in tasks) _taskRow(context, t, wedding, today),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: () => _addTask(context), child: const Text('할 일 추가')),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(BuildContext context, ChecklistTask t, DateTime wedding, DateTime today) {
    final due = wedding.subtract(Duration(days: t.dMinus));
    final isDone = state.isTaskDone(t);
    final overdue = !isDone && due.isBefore(today);
    final auto = t.category != null && state.statusOf(t.category!).isDone;

    return InkWell(
      onTap: auto ? null : () => state.toggleTask(t.id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22, color: isDone ? AppColors.success : AppColors.border),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: TextStyle(
                      fontSize: 15,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    auto
                        ? 'D-${t.dMinus} · 계약 완료로 자동 체크'
                        : 'D-${t.dMinus} · ${formatDateWithDay(due)}${overdue ? ' · 시기 지남' : ''}',
                    style: TextStyle(fontSize: 13, color: overdue ? AppColors.warning : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '할 일 삭제',
              icon: Icon(Icons.close, size: 18, color: AppColors.textHint),
              onPressed: () {
                state.removeTask(t);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("'${t.title}' 할 일을 지웠어요"),
                  action: SnackBarAction(label: '되돌리기', onPressed: () => state.restoreTask(t)),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTask(BuildContext context) {
    final title = TextEditingController();
    int? dMinus = 30;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('할 일 추가',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 20),
                  FormSection(
                    title: '할 일',
                    child: TextField(
                      controller: title,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '예: 신혼여행 항공권 예약'),
                    ),
                  ),
                  FormSection(
                    title: '언제까지',
                    hint: '예식일 며칠 전까지 할지 골라 주세요.',
                    child: PresetPicker(
                      value: dMinus,
                      presets: const [7, 30, 60, 90, 180, 365],
                      format: (v) => 'D-$v',
                      unit: '일 전',
                      min: 0,
                      max: 1000,
                      label: '예식 며칠 전',
                      onChanged: (v) => setSheet(() => dMinus = v),
                    ),
                  ),
                ]),
              ),
              BottomActionBar(children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (title.text.trim().isEmpty || dMinus == null) return;
                      state.addTask(title.text, dMinus!);
                      Navigator.pop(ctx);
                    },
                    child: const Text('추가'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

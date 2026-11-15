import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/format.dart';
import '../../core/utils/region.dart';
import '../../core/widgets/info_badge.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/models/wedding_plan.dart';

/// 준비 체크리스트: 결혼 정보 → 예산 → 항목별 진행 → 상담 일정 → 예식일 기준 할 일
class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('준비 체크리스트'),
        actions: const [PaletteButton()],
      ),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
            if (trailing != null) trailing!,
          ]),
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [AppColors.headerStart, AppColors.headerEnd]),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: AppColors.onHeader),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(dDay > 0 ? 'D-$dDay' : (dDay == 0 ? 'D-DAY' : 'D+${-dDay}'),
                    style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.onHeader)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('예식일 ${formatDate(p.weddingDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.onHeader)),
                ),
                IconButton(
                  tooltip: '예식일 바꾸기',
                  icon: Icon(Icons.edit_calendar, color: AppColors.onHeader),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: p.weddingDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) state.updatePlan(p.copyWith(weddingDate: picked));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('지역', style: TextStyle(color: AppColors.onHeader)),
              const SizedBox(width: 12),
              Theme(
                data: Theme.of(context).copyWith(canvasColor: AppColors.surface),
                child: DropdownButton<String>(
                  value: p.sido,
                  underline: const SizedBox.shrink(),
                  iconEnabledColor: AppColors.onHeader,
                  selectedItemBuilder: (_) => [
                    for (final s in kSidoList)
                      Center(
                          child: Text(s,
                              style: TextStyle(
                                  color: AppColors.onHeader, fontWeight: FontWeight.w700))),
                  ],
                  items: [for (final s in kSidoList) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => state.updatePlan(p.copyWith(sido: v)),
                ),
              ),
            ]),
            _slider(
              label: '총예산',
              value: p.budget.toDouble(),
              min: 500,
              max: 8000,
              divisions: 75,
              text: formatManwon(p.budget),
              onChanged: (v) => state.updatePlan(p.copyWith(budget: (v / 100).round() * 100)),
            ),
            _slider(
              label: '하객 수',
              value: p.guests.toDouble(),
              min: 20,
              max: 300,
              divisions: 28,
              text: '${p.guests}명',
              onChanged: (v) => state.updatePlan(p.copyWith(guests: v.round())),
            ),
            Text('이 정보는 업체 탭의 예산 비교와 AI 상담에도 쓰여요 (기기 안에서만 사용).',
                style: TextStyle(fontSize: 12, color: AppColors.onHeader.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String text,
    required ValueChanged<double> onChanged,
  }) {
    return Row(children: [
      SizedBox(width: 52, child: Text(label, style: TextStyle(color: AppColors.onHeader))),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.onHeader,
            thumbColor: AppColors.onHeader,
            inactiveTrackColor: AppColors.onHeader.withValues(alpha: 0.3),
          ),
          child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ),
      ),
      SizedBox(
        width: 84,
        child: Text(text,
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.onHeader, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = state.plan;
    final used = state.contractedTotal;
    final ratio = p.budget == 0 ? 0.0 : (used / p.budget).clamp(0.0, 1.0);
    return _Section(
      title: '예산',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(
                text: '계약 ${formatManwon(used)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 18)),
            TextSpan(
                text: ' / 총 ${formatManwon(p.budget)}',
                style: TextStyle(color: AppColors.textSecondary)),
          ])),
          const SizedBox(height: 2),
          Text(
              used > p.budget
                  ? '예산 ${formatManwon(used - p.budget)} 초과'
                  : '남은 예산 ${formatManwon(p.budget - used)}',
              style: TextStyle(
                  color: used > p.budget ? AppColors.warning : AppColors.success,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: AppColors.placeholder,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text('추천 배분: 식대 35% · 드레스 12% · 촬영 10% … (대관·기타 5%)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ItemStatusCard extends StatelessWidget {
  const _ItemStatusCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final done = VendorCategory.planItems
        .where((c) => state.statusOf(c) == ItemStatus.contracted)
        .length;
    return _Section(
      title: '준비 항목 11개',
      trailing: Text('$done/11 완료', style: TextStyle(color: AppColors.textSecondary)),
      child: Column(
        children: [
          for (final c in VendorCategory.planItems) _itemRow(context, c),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, VendorCategory c) {
    final status = state.statusOf(c);
    final contract = state.contracts[c];
    final color = switch (status) {
      ItemStatus.todo => AppColors.unknown,
      ItemStatus.consulting => AppColors.warning,
      ItemStatus.contracted => AppColors.success,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(c.icon, size: 20, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  contract != null
                      ? '${contract.$1.name.replaceFirst('[시연] ', '')} · ${contract.$2}만원'
                      : '추천 예산 ${state.plan.budgetFor(c)}만원',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          PopupMenuButton<ItemStatus>(
            tooltip: '상태 바꾸기',
            onSelected: (s) => state.setStatus(c, s),
            itemBuilder: (_) => [
              for (final s in ItemStatus.values)
                if (s != ItemStatus.contracted || contract != null)
                  PopupMenuItem(value: s, child: Text(s.label)),
            ],
            child: InfoBadge(label: '${status.label} ▾', color: color),
          ),
        ],
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '내 상담 일정',
      trailing: Text('${state.consultations.length}건',
          style: TextStyle(color: AppColors.textSecondary)),
      child: Column(
        children: [
          for (final c in state.consultations)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(c.vendor.category.icon, color: AppColors.primaryDark),
              title: Text(c.vendor.name.replaceFirst('[시연] ', '')),
              subtitle: Text('${formatDateWithDay(c.dateTime)} '
                  '${c.dateTime.hour.toString().padLeft(2, '0')}:00 · ${c.vendor.category.label}'),
              trailing: IconButton(
                tooltip: '취소',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => state.cancelConsultation(c),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.state});

  final AppState state;

  bool _isDone(ChecklistTask t) =>
      state.doneTasks.contains(t.id) ||
      (t.category != null && state.statusOf(t.category!) == ItemStatus.contracted);

  @override
  Widget build(BuildContext context) {
    final wedding = state.plan.weddingDate;
    final today = DateTime.now();
    final done = kChecklistTasks.where(_isDone).length;
    final nextTodo = kChecklistTasks.where((t) => !_isDone(t)).firstOrNull;

    return _Section(
      title: '예식일 기준 할 일',
      trailing: Text('$done/${kChecklistTasks.length}', style: TextStyle(color: AppColors.textSecondary)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nextTodo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('지금 할 일: ${nextTodo.title}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            ),
          for (final t in kChecklistTasks) _taskRow(t, wedding, today),
        ],
      ),
    );
  }

  Widget _taskRow(ChecklistTask t, DateTime wedding, DateTime today) {
    final due = wedding.subtract(Duration(days: t.dMinus));
    final isDone = _isDone(t);
    final overdue = !isDone && due.isBefore(today);
    final auto = t.category != null && state.statusOf(t.category!) == ItemStatus.contracted;

    return InkWell(
      onTap: auto ? null : () => state.toggleTask(t.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? AppColors.success : AppColors.divider,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 56,
              child: Text('D-${t.dMinus}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: overdue ? AppColors.warning : AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(
                t.title,
                style: TextStyle(
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
            ),
            if (auto)
              const InfoBadge(label: '계약 완료', color: AppColors.success)
            else if (t.tab != null)
              InfoBadge(label: '${t.tab} 탭', color: AppColors.primaryDark)
            else if (overdue)
              const InfoBadge(label: '지남', color: AppColors.warning)
            else
              Text(formatDateWithDay(due),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

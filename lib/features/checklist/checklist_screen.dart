import '../../data/candidates.dart';
import '../../data/repositories/repositories.dart';
import '../chat/chat_card_link.dart';
import '../estimate/estimate_screen.dart';
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

  /// 후보(찜한 업체·예식장) 계산에 쓰는 데이터를 한 번 읽어 둔다
  static final Future<void> _preload =
      Future.wait([Repos.venue.loadAll(), Repos.vendor.realVendors(), Repos.vendor.demoVendors()]);

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('준비 체크리스트'), actions: const [AccountButton()]),
      body: FutureBuilder(
        future: _preload,
        builder: (context, _) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _PlanCard(state: state),
            _TimelineCard(state: state), // 할 일을 예산보다 위에
            _BudgetCard(state: state),
            _ItemStatusCard(state: state),
            if (state.consultations.isNotEmpty) _ConsultationCard(state: state),
          ],
        ),
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
                !p.hasDate ? 'D-?' : (dDay > 0 ? 'D-$dDay' : (dDay == 0 ? 'D-DAY' : 'D+${-dDay}')),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: p.hasDate ? AppColors.ink : AppColors.textHint,
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
                        initialDate: p.hasDate ? p.weddingDate : DateTime.now().add(const Duration(days: 240)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 3),
                        ),
                      );
                      if (picked != null)
                        state.updatePlan(p.copyWith(weddingDate: picked));
                    },
                    child: Text(
                      p.hasDate ? '예식일 ${formatDate(p.weddingDate)}' : '예식일 입력하기',
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
                p.hasSido ? p.sido : null,
                () => _pick(
                  context,
                  '지역',
                  (done) => LayoutBuilder(
                    builder: (context, box) => DropdownMenu<String>(
                      width: box.maxWidth,
                      initialSelection: p.hasSido ? p.sido : null,
                      hintText: '지역을 입력하거나 고르세요 (예: 서울)',
                      enableFilter: true,
                      requestFocusOnTap: true,
                      menuHeight: 260,
                      leadingIcon: const Icon(Icons.place_outlined),
                      dropdownMenuEntries: [for (final s in kSidoList) DropdownMenuEntry(value: s, label: s)],
                      onSelected: (s) {
                        if (s == null) return;
                        state.updatePlan(p.copyWith(sido: s));
                        done();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _cell(
                context,
                '총예산',
                p.hasBudget ? formatManwonShort(p.budget) : null,
                () => _pick(
                  context,
                  '총예산',
                  (done) => NumberConfirmField(
                    value: p.hasBudget ? p.budget : null,
                    unit: '만원',
                    min: 100,
                    max: 100000,
                    hint: '예: 3000',
                    preview: (v) => '총예산 ${formatManwon(v)}',
                    onConfirmed: (v) {
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
                p.hasGuests ? '${p.guests}명' : null,
                () => _pick(
                  context,
                  '하객 수',
                  (done) => NumberConfirmField(
                    value: p.hasGuests ? p.guests : null,
                    unit: '명',
                    min: 10,
                    max: 2000,
                    hint: '예: 150',
                    preview: (v) => '하객 $v명',
                    onConfirmed: (v) {
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
            p.entered.length < 4 ? '눌러서 입력해 주세요. 업체 비교와 AI 상담에도 쓰여요.' : '업체 비교와 AI 상담에도 쓰여요.',
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
    String? value, // null이면 아직 입력 안 함
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
                value ?? '입력하기',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: value == null ? FontWeight.w600 : FontWeight.w700,
                  color: value == null ? AppColors.primary : AppColors.textPrimary,
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
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + MediaQuery.of(ctx).viewInsets.bottom),
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
    double part(int v) => !p.hasBudget || p.budget <= 0 ? 0 : (v / p.budget).clamp(0.0, 1.0);

    return _Section(
      title: '예산',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!p.hasBudget)
            Text('위 결혼 정보에서 총예산을 입력하면 남은 예산을 계산해 드려요',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary))
          else
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
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CostSimulatorScreen())),
                child: const Text('비용 시뮬레이션'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EstimateScreen())),
                child: const Text('내 견적서 A·B안'),
              ),
            ),
          ]),
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
    final cands = Candidates.forItem(item, state);
    final venue = item.id == AppState.venueItemId && state.chosenVenueId != null
        ? Repos.venue.cached?.where((v) => v.id == state.chosenVenueId).firstOrNull
        : null;
    final fits = venue == null || !state.plan.hasGuests ? null : venue.fits(state.plan.guests);
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
                  if (venue != null)
                    Text(
                      '${venue.capacityLabel}${fits == null ? '' : (fits ? ' · 하객 ${state.plan.guests}명 수용 가능' : ' · 하객 ${state.plan.guests}명은 정원 초과')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: fits == false ? AppColors.warning : AppColors.success),
                    ),
                  if (cands.isNotEmpty)
                    InkWell(
                      onTap: () => _showCandidates(context, item, cands),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('${Candidates.summary(cands)} ›',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                    ),
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

/// 찜한 후보 목록 (눌러서 상세로)
void _showCandidates(BuildContext context, PlanItem item, List<CandidateInfo> list) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('${item.name} 후보 ${list.length}곳',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('찜(하트)한 곳이 후보로 모여요. 눌러서 자세히 보고 상담·계약을 진행하세요.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final c in list)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(c.sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(c.priceText, style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatCardLink(ref: c.ref)));
                  },
                ),
            ]),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    ),
  );
}

/// 상태 표시: 미정(회색) / 후보(파랑) / 상담 중(주황) / 계약 완료·결제 완료(초록)
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      ItemStatus.todo => (AppColors.textSecondary, AppColors.fill),
      ItemStatus.candidate => (AppColors.primary, AppColors.primarySoft),
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

  void _openCalendar(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskCalendarScreen()));

  @override
  Widget build(BuildContext context) {
    final wedding = state.plan.weddingDate;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tasks = state.tasks;
    final done = tasks.where(state.isTaskDone).length;
    DateTime due(ChecklistTask t) {
      final d = wedding.subtract(Duration(days: t.dMinus));
      return DateTime(d.year, d.month, d.day);
    }

    final open = tasks.where((t) => !state.isTaskDone(t)).toList();
    final overdue = open.where((t) => due(t).isBefore(today)).length;
    // 가장 가깝게 남은 할 일 (마감일이 오늘 이후 중 가장 빠른 것)
    final upcoming = open.where((t) => !due(t).isBefore(today)).toList()
      ..sort((a, b) => due(a).compareTo(due(b)));
    final next = upcoming.firstOrNull;

    if (tasks.isEmpty || !state.plan.hasDate) {
      return _Section(
        title: '예식일 기준 할 일',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            !state.plan.hasDate
                ? '예식일을 입력하면 할 일마다 언제까지 해야 하는지 계산해 드려요.'
                : '아직 할 일이 없어요. [할 일 추가]로 직접 넣어 주세요.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _addTask(context), child: const Text('할 일 추가'))),
            if (tasks.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openCalendar(context),
                  child: Text('할 일 ${tasks.length}개 보기'),
                ),
              ),
            ],
          ]),
        ]),
      );
    }

    return _Section(
      title: '예식일 기준 할 일',
      trailing: Text('완료 $done/${tasks.length}', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 카드를 누르면 캘린더
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openCalendar(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: next == null
                ? Text(open.isEmpty ? '모든 할 일을 마쳤어요' : '남은 할 일은 모두 시기가 지났어요',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
                : Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        due(next) == today ? 'D-DAY' : 'D-${due(next).difference(today).inDays}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('다음 할 일 · ${next.title}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${formatDateWithDay(due(next))}까지 · 예식 D-${next.dMinus}',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textHint),
                  ]),
          ),
        ),
        if (overdue > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('시기가 지난 할 일 $overdue개가 있어요 · 캘린더에서 확인하세요',
                style: TextStyle(fontSize: 13, color: AppColors.warning)),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _addTask(context), child: const Text('할 일 추가'))),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _openCalendar(context),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('캘린더'),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _addTask(BuildContext context) {
    final title = TextEditingController();
    final dMinusField = TextEditingController();
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
                    hint: '예식일 며칠 전까지 할지 숫자로 입력해 주세요.',
                    child: TextField(
                      controller: dMinusField,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: '예: 30', prefixText: '예식 ', suffixText: '일 전'),
                    ),
                  ),
                ]),
              ),
              BottomActionBar(children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final dMinus = int.tryParse(dMinusField.text);
                      if (title.text.trim().isEmpty || dMinus == null || dMinus > 1000) return;
                      state.addTask(title.text, dMinus);
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
